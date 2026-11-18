-- =====================================================================
-- TP3 - Squelette à compléter
-- Base de départ : employees à l'état de fin de TP2
-- Ce fichier s'exécute sans erreur tel quel. Complétez-le, puis renommez-le tp3.sql.
-- Il doit pouvoir être rejoué en entier sur une base à l'état de fin de TP2.
-- =====================================================================

-- PARTIE A - Inventaire des données personnelles documenté dans la base (COMMENT ON COLUMN)
--            + requête qui affiche l'inventaire depuis le catalogue

-- PARTIE C - Requêtes de mesure du risque de réidentification

-- PARTIE D - Pseudonymisation et minimisation
--   D1. Mécanisme de pseudonymisation (la clé ou la table de correspondance n'est pas accessible à l'analyste)
--   D2. Vue v_salaires_pseudo   (une ligne par salarié en poste)
--   D3. Vue v_stats_egalite     (agrégats par département, titre et genre)
--   D4. Retrait de v_salaires_analyse, droits de l'analyste sur les nouvelles vues

-- PARTIE E - Limitation de la conservation

-- Anonymise l'identité des salariés partis depuis plus de p_delai à la date p_date_ref.
-- Renvoie le nombre de salariés anonymisés par cet appel. Un second appel identique renvoie 0.
CREATE OR REPLACE FUNCTION f_anonymiser_partis(p_date_ref date DEFAULT current_date,
                                               p_delai interval DEFAULT interval '5 years')
RETURNS integer
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'À implémenter';
END $$;

-- Supprime les traces d'audit plus anciennes que p_delai à la date p_date_ref ; renvoie le nombre supprimé.
CREATE OR REPLACE FUNCTION f_purger_audit(p_date_ref timestamptz DEFAULT now(),
                                          p_delai interval DEFAULT interval '1 year')
RETURNS integer
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'À implémenter';
END $$;

-- PARTIE F - Droit d'accès : toutes les données d'un salarié, en un document JSON
CREATE OR REPLACE FUNCTION f_export_donnees_salarie(p_emp_no integer)
RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'À implémenter';
END $$;

-- PARTIE G - Effacement : votre décision sur les clés étrangères ON DELETE CASCADE
