-- =====================================================================
-- Charge applicative de l'intranet RH -- 10 requêtes relevées en production
-- Base : employees (PostgreSQL). Les paramètres sont fixés pour l'audit.
-- =====================================================================

-- R01 - Annuaire : recherche d'un salarié par début de nom, sans tenir compte de la casse
SELECT emp_no, first_name, last_name, hire_date
FROM employees
WHERE lower(last_name) LIKE 'facel%'
ORDER BY last_name, first_name;

-- R02 - Fiche salarié : historique des salaires d'un salarié
SELECT salary, from_date, to_date
FROM salaries
WHERE emp_no = 10001
ORDER BY from_date;

-- R03 - Tableau de bord manager : salaire actuel des salariés en poste du département Development
SELECT e.emp_no, e.last_name, s.salary
FROM dept_emp de
JOIN employees e ON e.emp_no = de.emp_no
JOIN salaries s  ON s.emp_no = de.emp_no
WHERE de.dept_no = 'd005'
  AND de.to_date = '9999-01-01'
  AND s.to_date  = '9999-01-01';

-- R04 - Pilotage : masse salariale actuelle par département
SELECT d.dept_name, count(*) AS effectif, sum(s.salary) AS masse_salariale
FROM departments d
JOIN dept_emp de ON de.dept_no = d.dept_no AND de.to_date = '9999-01-01'
JOIN salaries s  ON s.emp_no = de.emp_no  AND s.to_date  = '9999-01-01'
GROUP BY d.dept_name
ORDER BY masse_salariale DESC;

-- R05 - Pilotage : les 10 salaires actuels les plus élevés
SELECT emp_no, salary
FROM salaries
WHERE to_date = '9999-01-01'
ORDER BY salary DESC
LIMIT 10;

-- R06 - Rapport annuel : salariés embauchés en 1999
SELECT emp_no, first_name, last_name, hire_date
FROM employees
WHERE extract(year FROM hire_date) = 1999;

-- R07 - Export paie : dernier salaire connu de chaque salarié du département Sales
SELECT s.emp_no, s.salary
FROM salaries s
JOIN dept_emp de ON de.emp_no = s.emp_no AND de.dept_no = 'd007'
WHERE s.from_date = (SELECT max(s2.from_date)
                     FROM salaries s2
                     WHERE s2.emp_no = s.emp_no);

-- R08 - Annuaire paginé : page 4001 (50 salariés par page, tri par nom)
SELECT emp_no, last_name, first_name
FROM employees
ORDER BY last_name, first_name, emp_no
LIMIT 50 OFFSET 200000;

-- R09 - Revue salariale : salariés en poste mieux payés que la moyenne actuelle de leur département
SELECT de.dept_no, s.emp_no, s.salary
FROM salaries s
JOIN dept_emp de ON de.emp_no = s.emp_no AND de.to_date = '9999-01-01'
WHERE s.to_date = '9999-01-01'
  AND s.salary > (SELECT avg(s2.salary)
                  FROM salaries s2
                  JOIN dept_emp de2 ON de2.emp_no = s2.emp_no AND de2.to_date = '9999-01-01'
                  WHERE s2.to_date = '9999-01-01'
                    AND de2.dept_no = de.dept_no);

-- R10 - Historique : titre occupé par chaque salarié en poste du département Research
SELECT e.emp_no, e.last_name, t.title
FROM employees e
JOIN dept_emp de ON de.emp_no = e.emp_no
JOIN titles t    ON t.emp_no = e.emp_no
WHERE de.dept_no = 'd008'
  AND de.to_date = '9999-01-01'
  AND t.to_date  = '9999-01-01';
