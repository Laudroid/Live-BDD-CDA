-- =====================================================================
-- TP2 - Squelette à compléter
-- Base de départ : employees à l'état de fin de TP1
-- Ce fichier s'exécute sans erreur tel quel : chaque corps lève « À implémenter ».
-- Complétez-le, puis renommez-le tp2.sql. Il doit pouvoir être rejoué en entier
-- sur une base à l'état de fin de TP1 (psql -v ON_ERROR_STOP=1 -f tp2.sql).
-- =====================================================================

-- ---------------------------------------------------------------------
-- PARTIE A - Contraintes déclaratives
-- ---------------------------------------------------------------------
-- A1. titles.to_date : alignement sur les autres tables
-- A2. Cohérence des périodes (from_date avant to_date) sur salaries, titles, dept_emp, dept_manager
--     + salaire strictement positif
-- A3. Aucun chevauchement de périodes pour un même salarié dans salaries et dans titles
-- A4. Un seul manager en poste par département
-- A5. Numérotation des nouveaux salariés sûre en cas d'embauches simultanées


-- ---------------------------------------------------------------------
-- PARTIE C - Procédures stockées
-- ---------------------------------------------------------------------

-- Augmente le salaire en cours de p_emp_no à partir de p_date.
CREATE OR REPLACE PROCEDURE p_augmenter(p_emp_no integer, p_nouveau_salaire integer,
                                        p_date date DEFAULT current_date)
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'À implémenter';
END $$;

-- Change le titre en cours et le salaire en cours, en une seule opération atomique.
CREATE OR REPLACE PROCEDURE p_promouvoir(p_emp_no integer, p_nouveau_titre varchar,
                                         p_nouveau_salaire integer, p_date date DEFAULT current_date)
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'À implémenter';
END $$;

-- Change l'affectation en cours du salarié.
CREATE OR REPLACE PROCEDURE p_muter(p_emp_no integer, p_dept_no char(4),
                                    p_date date DEFAULT current_date)
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'À implémenter';
END $$;

-- Crée le salarié, son affectation, son titre et son salaire ; renvoie le matricule attribué.
CREATE OR REPLACE FUNCTION f_embaucher(p_prenom varchar, p_nom varchar, p_naissance date,
                                       p_genre gender, p_dept_no char(4), p_titre varchar,
                                       p_salaire integer, p_date date DEFAULT current_date)
RETURNS integer
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'À implémenter';
END $$;


-- ---------------------------------------------------------------------
-- PARTIE D - Triggers
-- ---------------------------------------------------------------------
-- D1. Règles RG5 et RG6 sur toute nouvelle ligne de salaries
-- D2. Règle RG7 : historique immuable
-- D3. Table audit_salaires et trigger d'audit (RG8)


-- ---------------------------------------------------------------------
-- PARTIE E - Rôles et droits
-- ---------------------------------------------------------------------
-- Rôles de groupe : rh_lecteur, rh_gestionnaire, app_paie, analyste
-- Comptes de test : alice (rh_gestionnaire), bruno (rh_lecteur), paie (app_paie), carla (analyste)
-- Vue de l'analyste : v_salaires_analyse
