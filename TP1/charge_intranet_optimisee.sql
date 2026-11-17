-- Corrigé TP1 - Requêtes réécrites (mêmes résultats que charge_intranet.sql)

-- R01 - inchangée : l'index sur expression lower(last_name) suffit
SELECT emp_no, first_name, last_name, hire_date
FROM employees
WHERE lower(last_name) LIKE 'facel%'
ORDER BY last_name, first_name;

-- R02 - inchangée : déjà servie par la clé primaire (témoin)
SELECT salary, from_date, to_date
FROM salaries
WHERE emp_no = 10001
ORDER BY from_date;

-- R03 - inchangée : servie par les index partiels I2 et I4
SELECT e.emp_no, e.last_name, s.salary
FROM dept_emp de
JOIN employees e ON e.emp_no = de.emp_no
JOIN salaries s  ON s.emp_no = de.emp_no
WHERE de.dept_no = 'd005'
  AND de.to_date = '9999-01-01'
  AND s.to_date  = '9999-01-01';

-- R04 - inchangée : parcours d'index seuls sur I2 et I4
SELECT d.dept_name, count(*) AS effectif, sum(s.salary) AS masse_salariale
FROM departments d
JOIN dept_emp de ON de.dept_no = d.dept_no AND de.to_date = '9999-01-01'
JOIN salaries s  ON s.emp_no = de.emp_no  AND s.to_date  = '9999-01-01'
GROUP BY d.dept_name
ORDER BY masse_salariale DESC;

-- R05 - inchangée : l'index I3 fournit directement les 10 premières lignes triées
SELECT emp_no, salary
FROM salaries
WHERE to_date = '9999-01-01'
ORDER BY salary DESC
LIMIT 10;

-- R06 - réécrite : condition « sargable » sur la colonne nue (intervalle semi-ouvert)
SELECT emp_no, first_name, last_name, hire_date
FROM employees
WHERE hire_date >= '1999-01-01' AND hire_date < '2000-01-01';

-- R07 - réécrite : LATERAL va chercher, pour chaque salarié, la ligne la plus récente
--       en descendant la clé primaire (emp_no, from_date) ; une seule lecture d'index par salarié
SELECT de.emp_no, ls.salary
FROM dept_emp de
CROSS JOIN LATERAL (SELECT s.salary
                    FROM salaries s
                    WHERE s.emp_no = de.emp_no
                    ORDER BY s.from_date DESC
                    LIMIT 1) ls
WHERE de.dept_no = 'd007';

-- R08 - réécrite : pagination par clé (keyset). Le curseur est la dernière ligne de la page précédente.
SELECT emp_no, last_name, first_name
FROM employees
WHERE (last_name, first_name, emp_no) > ('Peres', 'Kwangsub', 491088)
ORDER BY last_name, first_name, emp_no
LIMIT 50;

-- R09 - réécrite : moyenne par département calculée une seule fois (fonction de fenêtrage)
SELECT dept_no, emp_no, salary
FROM (SELECT de.dept_no, s.emp_no, s.salary,
             avg(s.salary) OVER (PARTITION BY de.dept_no) AS moy_dept
      FROM salaries s
      JOIN dept_emp de ON de.emp_no = s.emp_no AND de.to_date = '9999-01-01'
      WHERE s.to_date = '9999-01-01') x
WHERE salary > moy_dept;

-- R10 - inchangée : servie par les index partiels I4 et I7
SELECT e.emp_no, e.last_name, t.title
FROM employees e
JOIN dept_emp de ON de.emp_no = e.emp_no
JOIN titles t    ON t.emp_no = e.emp_no
WHERE de.dept_no = 'd008'
  AND de.to_date = '9999-01-01'
  AND t.to_date  = '9999-01-01';
