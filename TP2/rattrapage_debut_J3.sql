-- =====================================================================
-- RATTRAPAGE - état de la base au début du jour 3 (fin du TP2)
-- À exécuter sur une base employees fraîchement restaurée :
--   psql -U postgres -d employees -v ON_ERROR_STOP=1 -f rattrapage_debut_J3.sql
-- Durée : environ 2 minutes (création des contraintes d'exclusion).
-- Distribué au début du jour 3, après la correction du TP2.
-- =====================================================================

-- Index du TP1
-- I1 (R01) recherche par début de nom insensible à la casse : index sur expression,
--     text_pattern_ops pour que LIKE 'xxx%' utilise l'index quelle que soit la collation
CREATE INDEX idx_emp_lower_last_name ON employees (lower(last_name) text_pattern_ops);
-- I2 (R03, R04, R09) salaire actuel : index partiel couvrant sur les seules lignes en cours
CREATE INDEX idx_sal_courant ON salaries (emp_no) INCLUDE (salary) WHERE to_date = '9999-01-01';
-- I3 (R05) classement des salaires actuels
CREATE INDEX idx_sal_courant_montant ON salaries (salary DESC) INCLUDE (emp_no) WHERE to_date = '9999-01-01';
-- I4 (R03, R04, R09, R10) affectation actuelle par département
CREATE INDEX idx_de_courant ON dept_emp (dept_no) INCLUDE (emp_no) WHERE to_date = '9999-01-01';
-- I5 (R06) recherche par date d'embauche (après réécriture de la requête en intervalle)
CREATE INDEX idx_emp_hire_date ON employees (hire_date);
-- I6 (R08) annuaire trié par nom : sert la pagination par clé
CREATE INDEX idx_emp_nom_prenom ON employees (last_name, first_name, emp_no);
-- I7 (R10) titre actuel
CREATE INDEX idx_titles_courant ON titles (emp_no) INCLUDE (title) WHERE to_date = '9999-01-01';
ANALYZE;

-- =====================================================================
-- Objets du TP2
-- =====================================================================

-- ---------------------------------------------------------------------
-- PARTIE A - Contraintes déclaratives (ce que la base garantit seule)
-- ---------------------------------------------------------------------

-- A1. titles.to_date est nullable alors qu'aucune ligne n'est NULL : on aligne sur les autres tables
ALTER TABLE titles ALTER COLUMN to_date SET NOT NULL;

-- A2. Cohérence des périodes. Les données contiennent des périodes de durée nulle
--     (178 salaires, 31 titres, 51 affectations où from_date = to_date).
--     NOT VALID : la règle s'applique aux nouvelles lignes sans bloquer sur l'existant,
--     qui reste à arbitrer avec le métier (VALIDATE CONSTRAINT une fois nettoyé).
ALTER TABLE salaries     ADD CONSTRAINT ck_salaries_periode     CHECK (from_date < to_date) NOT VALID;
ALTER TABLE titles       ADD CONSTRAINT ck_titles_periode       CHECK (from_date < to_date) NOT VALID;
ALTER TABLE dept_emp     ADD CONSTRAINT ck_dept_emp_periode     CHECK (from_date < to_date) NOT VALID;
ALTER TABLE dept_manager ADD CONSTRAINT ck_dept_manager_periode CHECK (from_date < to_date);
ALTER TABLE salaries     ADD CONSTRAINT ck_salaries_positif     CHECK (salary > 0);

-- A3. Pas de chevauchement de périodes pour un même salarié (contrainte d'exclusion)
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE salaries ADD CONSTRAINT ex_salaries_chevauchement
    EXCLUDE USING gist (emp_no WITH =, daterange(from_date, to_date) WITH &&);
ALTER TABLE titles ADD CONSTRAINT ex_titles_chevauchement
    EXCLUDE USING gist (emp_no WITH =, daterange(from_date, to_date) WITH &&);

-- A4. Un seul manager en poste par département (index unique partiel)
CREATE UNIQUE INDEX ux_manager_courant ON dept_manager (dept_no) WHERE to_date = '9999-01-01';

-- A5. Numérotation des salariés par séquence (au lieu de max(emp_no) + 1, faux en concurrence)
CREATE SEQUENCE employees_emp_no_seq OWNED BY employees.emp_no;
SELECT setval('employees_emp_no_seq', (SELECT max(emp_no) FROM employees));
ALTER TABLE employees ALTER COLUMN emp_no SET DEFAULT nextval('employees_emp_no_seq');

-- ---------------------------------------------------------------------
-- PARTIE B - Triggers : règles métier et audit
-- ---------------------------------------------------------------------

-- B1. Règles de gestion de la DRH (entreprise fictive) sur les nouvelles lignes de salaire :
--     pas de baisse, pas d'augmentation de plus de 20 % en une fois.
CREATE OR REPLACE FUNCTION f_controle_salaire() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_precedent integer;
BEGIN
    SELECT salary INTO v_precedent
    FROM salaries
    WHERE emp_no = NEW.emp_no AND from_date < NEW.from_date
    ORDER BY from_date DESC
    LIMIT 1;

    IF v_precedent IS NOT NULL THEN
        IF NEW.salary < v_precedent THEN
            RAISE EXCEPTION 'Baisse de salaire refusée pour le salarié % (% -> %)',
                NEW.emp_no, v_precedent, NEW.salary
                USING ERRCODE = 'check_violation';
        ELSIF NEW.salary > v_precedent * 1.20 THEN
            RAISE EXCEPTION 'Augmentation supérieure à 20 %% refusée pour le salarié % (% -> %)',
                NEW.emp_no, v_precedent, NEW.salary
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_controle_salaire
    BEFORE INSERT ON salaries
    FOR EACH ROW EXECUTE FUNCTION f_controle_salaire();

-- B2. Historique immuable : sur une ligne existante, seule la date de fin peut changer.
CREATE OR REPLACE FUNCTION f_historique_immuable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.emp_no <> OLD.emp_no OR NEW.salary <> OLD.salary OR NEW.from_date <> OLD.from_date THEN
        RAISE EXCEPTION 'Historique des salaires immuable : seule to_date est modifiable'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_historique_immuable
    BEFORE UPDATE ON salaries
    FOR EACH ROW EXECUTE FUNCTION f_historique_immuable();

-- B3. Journal d'audit des salaires : qui, quoi, quand.
--     session_user et non current_user : dans une procédure SECURITY DEFINER,
--     current_user vaut le propriétaire de la procédure, pas la personne connectée.
--     Pas de clé étrangère vers employees : la trace doit survivre à la suppression.
CREATE TABLE audit_salaires (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operation       char(1)     NOT NULL CHECK (operation IN ('I', 'U', 'D')),
    emp_no          integer     NOT NULL,
    ancien_salaire  integer,
    nouveau_salaire integer,
    ancienne_fin    date,
    nouvelle_fin    date,
    utilisateur     text        NOT NULL DEFAULT session_user,
    horodatage      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_salaires_emp ON audit_salaires (emp_no);

CREATE OR REPLACE FUNCTION f_audit_salaires() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_salaires (operation, emp_no, nouveau_salaire, nouvelle_fin)
        VALUES ('I', NEW.emp_no, NEW.salary, NEW.to_date);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_salaires (operation, emp_no, ancien_salaire, nouveau_salaire, ancienne_fin, nouvelle_fin)
        VALUES ('U', NEW.emp_no, OLD.salary, NEW.salary, OLD.to_date, NEW.to_date);
    ELSE
        INSERT INTO audit_salaires (operation, emp_no, ancien_salaire, ancienne_fin)
        VALUES ('D', OLD.emp_no, OLD.salary, OLD.to_date);
    END IF;
    RETURN NULL;   -- trigger AFTER : la valeur de retour est ignorée
END $$;

CREATE TRIGGER trg_audit_salaires
    AFTER INSERT OR UPDATE OR DELETE ON salaries
    FOR EACH ROW EXECUTE FUNCTION f_audit_salaires();

-- ---------------------------------------------------------------------
-- PARTIE C - Procédures stockées (opérations RH atomiques)
-- ---------------------------------------------------------------------
-- Chaque procédure verrouille d'abord la ligne du salarié (SELECT ... FOR UPDATE) :
-- deux opérations concurrentes sur le même salarié s'exécutent l'une après l'autre,
-- et la seconde relit l'état laissé par la première.
-- SECURITY DEFINER + search_path fixé : les gestionnaires n'ont aucun droit direct
-- d'écriture sur les tables, ils passent obligatoirement par ces procédures.

CREATE OR REPLACE PROCEDURE p_augmenter(p_emp_no integer, p_nouveau_salaire integer,
                                        p_date date DEFAULT current_date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_debut date;
BEGIN
    PERFORM 1 FROM employees WHERE emp_no = p_emp_no FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Salarié % inconnu', p_emp_no USING ERRCODE = 'no_data_found';
    END IF;

    SELECT from_date INTO v_debut
    FROM salaries WHERE emp_no = p_emp_no AND to_date = '9999-01-01';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Salarié % sans salaire en cours (parti ?)', p_emp_no USING ERRCODE = 'no_data_found';
    END IF;
    IF p_date <= v_debut THEN
        RAISE EXCEPTION 'Date d''effet % antérieure ou égale au salaire en cours (%)', p_date, v_debut
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    UPDATE salaries SET to_date = p_date
    WHERE emp_no = p_emp_no AND from_date = v_debut;
    INSERT INTO salaries (emp_no, salary, from_date, to_date)
    VALUES (p_emp_no, p_nouveau_salaire, p_date, '9999-01-01');
END $$;

CREATE OR REPLACE PROCEDURE p_promouvoir(p_emp_no integer, p_nouveau_titre varchar,
                                         p_nouveau_salaire integer, p_date date DEFAULT current_date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_titre varchar;
BEGIN
    PERFORM 1 FROM employees WHERE emp_no = p_emp_no FOR UPDATE;
    SELECT title INTO v_titre FROM titles WHERE emp_no = p_emp_no AND to_date = '9999-01-01';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Salarié % sans titre en cours', p_emp_no USING ERRCODE = 'no_data_found';
    END IF;
    IF v_titre = p_nouveau_titre THEN
        RAISE EXCEPTION 'Le salarié % porte déjà le titre %', p_emp_no, v_titre
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    UPDATE titles SET to_date = p_date WHERE emp_no = p_emp_no AND to_date = '9999-01-01';
    INSERT INTO titles (emp_no, title, from_date, to_date)
    VALUES (p_emp_no, p_nouveau_titre, p_date, '9999-01-01');
    -- même transaction : si l'augmentation échoue, le changement de titre est annulé aussi
    CALL p_augmenter(p_emp_no, p_nouveau_salaire, p_date);
END $$;

CREATE OR REPLACE PROCEDURE p_muter(p_emp_no integer, p_dept_no char(4),
                                    p_date date DEFAULT current_date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_dept char(4);
BEGIN
    PERFORM 1 FROM employees WHERE emp_no = p_emp_no FOR UPDATE;
    SELECT dept_no INTO v_dept FROM dept_emp WHERE emp_no = p_emp_no AND to_date = '9999-01-01';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Salarié % sans affectation en cours', p_emp_no USING ERRCODE = 'no_data_found';
    END IF;
    IF v_dept = p_dept_no THEN
        RAISE EXCEPTION 'Le salarié % est déjà affecté à %', p_emp_no, p_dept_no
            USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF EXISTS (SELECT 1 FROM dept_emp WHERE emp_no = p_emp_no AND dept_no = p_dept_no) THEN
        -- la clé primaire (emp_no, dept_no) interdit un second passage dans le même département :
        -- limite du modèle d'origine, à signaler dans le rapport
        RAISE EXCEPTION 'Retour du salarié % dans % impossible : limite de la clé primaire de dept_emp',
            p_emp_no, p_dept_no USING ERRCODE = 'unique_violation';
    END IF;

    UPDATE dept_emp SET to_date = p_date WHERE emp_no = p_emp_no AND to_date = '9999-01-01';
    INSERT INTO dept_emp (emp_no, dept_no, from_date, to_date)
    VALUES (p_emp_no, p_dept_no, p_date, '9999-01-01');
END $$;

CREATE OR REPLACE FUNCTION f_embaucher(p_prenom varchar, p_nom varchar, p_naissance date,
                                       p_genre gender, p_dept_no char(4), p_titre varchar,
                                       p_salaire integer, p_date date DEFAULT current_date)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_emp_no integer;
BEGIN
    INSERT INTO employees (birth_date, first_name, last_name, gender, hire_date)
    VALUES (p_naissance, p_prenom, p_nom, p_genre, p_date)
    RETURNING emp_no INTO v_emp_no;          -- numéro fourni par la séquence
    INSERT INTO dept_emp VALUES (v_emp_no, p_dept_no, p_date, '9999-01-01');
    INSERT INTO titles   VALUES (v_emp_no, p_titre, p_date, '9999-01-01');
    INSERT INTO salaries VALUES (v_emp_no, p_salaire, p_date, '9999-01-01');
    RETURN v_emp_no;
END $$;

-- ---------------------------------------------------------------------
-- PARTIE D - Rôles et droits (moindre privilège)
-- ---------------------------------------------------------------------
-- Piège : les fonctions et procédures sont exécutables par PUBLIC par défaut.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;

-- Rôles de groupe (NOLOGIN) : on donne les droits aux fonctions, jamais aux personnes
DO $$ BEGIN CREATE ROLE rh_lecteur NOLOGIN; EXCEPTION WHEN duplicate_object THEN RAISE NOTICE 'rôle rh_lecteur déjà présent'; END $$;
DO $$ BEGIN CREATE ROLE rh_gestionnaire NOLOGIN; EXCEPTION WHEN duplicate_object THEN RAISE NOTICE 'rôle rh_gestionnaire déjà présent'; END $$;
DO $$ BEGIN CREATE ROLE app_paie NOLOGIN; EXCEPTION WHEN duplicate_object THEN RAISE NOTICE 'rôle app_paie déjà présent'; END $$;
DO $$ BEGIN CREATE ROLE analyste NOLOGIN; EXCEPTION WHEN duplicate_object THEN RAISE NOTICE 'rôle analyste déjà présent'; END $$;
GRANT USAGE ON SCHEMA public TO rh_lecteur, rh_gestionnaire, app_paie, analyste;

-- Lecteur RH : dossiers administratifs, sans les salaires
GRANT SELECT ON employees, departments, dept_emp, dept_manager, titles TO rh_lecteur;

-- Gestionnaire RH : hérite du lecteur, lit les salaires, écrit uniquement via les procédures
GRANT rh_lecteur TO rh_gestionnaire;
GRANT SELECT ON salaries TO rh_gestionnaire;
GRANT EXECUTE ON PROCEDURE p_augmenter(integer, integer, date),
                           p_promouvoir(integer, varchar, integer, date),
                           p_muter(integer, char, date) TO rh_gestionnaire;
GRANT EXECUTE ON FUNCTION f_embaucher(varchar, varchar, date, gender, char, varchar, integer, date)
    TO rh_gestionnaire;

-- Application de paie : identité minimale (droits par colonne) et salaires
GRANT SELECT (emp_no, first_name, last_name) ON employees TO app_paie;
GRANT SELECT ON salaries TO app_paie;

-- Analyste : une vue agrégeable sans nom ni date de naissance
CREATE VIEW v_salaires_analyse AS
SELECT de.dept_no, t.title, e.gender,
       extract(year FROM e.hire_date)::int AS annee_embauche,
       s.salary
FROM salaries s
JOIN dept_emp  de ON de.emp_no = s.emp_no AND de.to_date = '9999-01-01'
JOIN titles    t  ON t.emp_no  = s.emp_no AND t.to_date  = '9999-01-01'
JOIN employees e  ON e.emp_no  = s.emp_no
WHERE s.to_date = '9999-01-01';
GRANT SELECT ON v_salaires_analyse TO analyste;

-- Comptes nominatifs de test (mots de passe de démonstration uniquement)
DO $$ BEGIN CREATE ROLE alice LOGIN PASSWORD 'alice-demo' IN ROLE rh_gestionnaire; EXCEPTION WHEN duplicate_object THEN RAISE NOTICE 'rôle alice déjà présent'; END $$;
DO $$ BEGIN CREATE ROLE bruno LOGIN PASSWORD 'bruno-demo' IN ROLE rh_lecteur; EXCEPTION WHEN duplicate_object THEN RAISE NOTICE 'rôle bruno déjà présent'; END $$;
DO $$ BEGIN CREATE ROLE paie LOGIN PASSWORD 'paie-demo'  IN ROLE app_paie; EXCEPTION WHEN duplicate_object THEN RAISE NOTICE 'rôle paie déjà présent'; END $$;
DO $$ BEGIN CREATE ROLE carla LOGIN PASSWORD 'carla-demo' IN ROLE analyste; EXCEPTION WHEN duplicate_object THEN RAISE NOTICE 'rôle carla déjà présent'; END $$;
