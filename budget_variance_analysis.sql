-- =====================================================================
-- Project 2: Budget Variance & Cost-Benefit SQL Analysis
-- Dialect : ANSI SQL (tested style: PostgreSQL; works on MySQL 8+ / SQL Server
--           with minor changes noted in comments)
-- Sections: 1) Schema  2) Sample data  3) Variance query  4) Flagged summary
--           5) Cost-benefit analysis
-- Convention: variance = actual - budget.
--             Positive variance on an expense = OVERSPEND (unfavourable).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. SCHEMA
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS cost_initiatives;
DROP TABLE IF EXISTS monthly_expenditure;
DROP TABLE IF EXISTS cost_centers;

CREATE TABLE cost_centers (
    cost_center_id   INTEGER       PRIMARY KEY,
    cost_center_name VARCHAR(60)   NOT NULL,
    department       VARCHAR(60)   NOT NULL
);

CREATE TABLE monthly_expenditure (
    expenditure_id   INTEGER        PRIMARY KEY,
    cost_center_id   INTEGER        NOT NULL REFERENCES cost_centers (cost_center_id),
    period_month     DATE           NOT NULL,           -- first day of the month
    budget_amount    DECIMAL(12, 2) NOT NULL CHECK (budget_amount >= 0),
    actual_amount    DECIMAL(12, 2) NOT NULL CHECK (actual_amount >= 0),
    CONSTRAINT uq_cc_month UNIQUE (cost_center_id, period_month)
);

CREATE TABLE cost_initiatives (
    initiative_id       INTEGER        PRIMARY KEY,
    cost_center_id      INTEGER        NOT NULL REFERENCES cost_centers (cost_center_id),
    initiative_name     VARCHAR(100)   NOT NULL,
    implementation_cost DECIMAL(12, 2) NOT NULL,        -- one-off cost
    annual_benefit      DECIMAL(12, 2) NOT NULL,        -- yearly savings / revenue gain
    horizon_years       INTEGER        NOT NULL
);


-- ---------------------------------------------------------------------
-- 2. SAMPLE DATA (KES, illustrative) - Jan to Jun 2026
-- ---------------------------------------------------------------------
INSERT INTO cost_centers (cost_center_id, cost_center_name, department) VALUES (1, 'Logistics',  'Operations');
INSERT INTO cost_centers (cost_center_id, cost_center_name, department) VALUES (2, 'IT Services', 'Technology');
INSERT INTO cost_centers (cost_center_id, cost_center_name, department) VALUES (3, 'Marketing',  'Commercial');
INSERT INTO cost_centers (cost_center_id, cost_center_name, department) VALUES (4, 'Admin',      'Corporate');

-- Logistics: budget 50,000/month, steadily escalating overspend
INSERT INTO monthly_expenditure VALUES (1,  1, DATE '2026-01-01', 50000, 48000);
INSERT INTO monthly_expenditure VALUES (2,  1, DATE '2026-02-01', 50000, 52000);
INSERT INTO monthly_expenditure VALUES (3,  1, DATE '2026-03-01', 50000, 56000);
INSERT INTO monthly_expenditure VALUES (4,  1, DATE '2026-04-01', 50000, 61000);
INSERT INTO monthly_expenditure VALUES (5,  1, DATE '2026-05-01', 50000, 66000);
INSERT INTO monthly_expenditure VALUES (6,  1, DATE '2026-06-01', 50000, 70000);

-- IT Services: budget 30,000/month, well controlled
INSERT INTO monthly_expenditure VALUES (7,  2, DATE '2026-01-01', 30000, 29000);
INSERT INTO monthly_expenditure VALUES (8,  2, DATE '2026-02-01', 30000, 30500);
INSERT INTO monthly_expenditure VALUES (9,  2, DATE '2026-03-01', 30000, 29800);
INSERT INTO monthly_expenditure VALUES (10, 2, DATE '2026-04-01', 30000, 31000);
INSERT INTO monthly_expenditure VALUES (11, 2, DATE '2026-05-01', 30000, 30200);
INSERT INTO monthly_expenditure VALUES (12, 2, DATE '2026-06-01', 30000, 30900);

-- Marketing: budget 40,000/month, volatile (campaign-driven)
INSERT INTO monthly_expenditure VALUES (13, 3, DATE '2026-01-01', 40000, 42000);
INSERT INTO monthly_expenditure VALUES (14, 3, DATE '2026-02-01', 40000, 38000);
INSERT INTO monthly_expenditure VALUES (15, 3, DATE '2026-03-01', 40000, 45000);
INSERT INTO monthly_expenditure VALUES (16, 3, DATE '2026-04-01', 40000, 36000);
INSERT INTO monthly_expenditure VALUES (17, 3, DATE '2026-05-01', 40000, 47000);
INSERT INTO monthly_expenditure VALUES (18, 3, DATE '2026-06-01', 40000, 39000);

-- Admin: budget 20,000/month, consistently under budget
INSERT INTO monthly_expenditure VALUES (19, 4, DATE '2026-01-01', 20000, 19500);
INSERT INTO monthly_expenditure VALUES (20, 4, DATE '2026-02-01', 20000, 19800);
INSERT INTO monthly_expenditure VALUES (21, 4, DATE '2026-03-01', 20000, 19000);
INSERT INTO monthly_expenditure VALUES (22, 4, DATE '2026-04-01', 20000, 18800);
INSERT INTO monthly_expenditure VALUES (23, 4, DATE '2026-05-01', 20000, 19200);
INSERT INTO monthly_expenditure VALUES (24, 4, DATE '2026-06-01', 20000, 18900);

INSERT INTO cost_initiatives VALUES (1, 1, 'Route optimisation software',   180000, 120000, 3);
INSERT INTO cost_initiatives VALUES (2, 2, 'Cloud cost rightsizing',         40000,  60000, 3);
INSERT INTO cost_initiatives VALUES (3, 3, 'Marketing automation platform', 150000,  45000, 3);
INSERT INTO cost_initiatives VALUES (4, 4, 'Paperless invoicing',            25000,  18000, 3);


-- ---------------------------------------------------------------------
-- 3. MONTHLY VARIANCE ANALYSIS (window functions + CASE WHEN)
-- ---------------------------------------------------------------------
-- For each cost center and month:
--   * monthly variance (amount and %)
--   * cumulative (year-to-date) budget, actual and variance via SUM() OVER
--   * month-over-month change in actual spend via LAG()
--   * RAG flag using CASE WHEN
WITH monthly AS (
    SELECT
        cc.cost_center_name,
        me.cost_center_id,
        me.period_month,
        me.budget_amount,
        me.actual_amount,
        me.actual_amount - me.budget_amount AS variance_amount,
        CASE
            WHEN me.budget_amount = 0 THEN NULL
            ELSE ROUND((me.actual_amount - me.budget_amount) * 100.0 / me.budget_amount, 2)
        END AS variance_pct
    FROM monthly_expenditure me
    JOIN cost_centers cc ON cc.cost_center_id = me.cost_center_id
),
windowed AS (
    SELECT
        m.*,
        SUM(budget_amount)   OVER (PARTITION BY cost_center_id ORDER BY period_month
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ytd_budget,
        SUM(actual_amount)   OVER (PARTITION BY cost_center_id ORDER BY period_month
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ytd_actual,
        SUM(variance_amount) OVER (PARTITION BY cost_center_id ORDER BY period_month
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ytd_variance,
        LAG(actual_amount)   OVER (PARTITION BY cost_center_id ORDER BY period_month) AS prev_month_actual
    FROM monthly m
)
SELECT
    cost_center_name,
    period_month,
    budget_amount,
    actual_amount,
    variance_amount,
    variance_pct,
    ytd_budget,
    ytd_actual,
    ytd_variance,
    -- Month-over-month change in actual spend
    actual_amount - prev_month_actual AS mom_change_amount,
    CASE
        WHEN prev_month_actual IS NULL OR prev_month_actual = 0 THEN NULL
        ELSE ROUND((actual_amount - prev_month_actual) * 100.0 / prev_month_actual, 2)
    END AS mom_change_pct,
    -- RAG status on monthly variance %
    CASE
        WHEN variance_pct >  10 THEN 'RED - Overspend >10%'
        WHEN variance_pct >   5 THEN 'AMBER - Overspend 5-10%'
        WHEN variance_pct < -10 THEN 'BLUE - Underspend >10% (check under-delivery)'
        ELSE 'GREEN - Within tolerance'
    END AS variance_flag
FROM windowed
ORDER BY cost_center_name, period_month;


-- ---------------------------------------------------------------------
-- 4. COST CENTER SUMMARY: who needs attention?
-- ---------------------------------------------------------------------
-- Classifies each center as "trending overspend" (months over budget) vs
-- "volatile" (large swings) using counts and average absolute variance.
SELECT
    cc.cost_center_name,
    SUM(me.budget_amount)                                             AS total_budget,
    SUM(me.actual_amount)                                             AS total_actual,
    SUM(me.actual_amount - me.budget_amount)                          AS total_variance,
    ROUND(SUM(me.actual_amount - me.budget_amount) * 100.0
          / SUM(me.budget_amount), 2)                                 AS total_variance_pct,
    SUM(CASE WHEN me.actual_amount > me.budget_amount THEN 1 ELSE 0 END) AS months_over_budget,
    ROUND(AVG(ABS(me.actual_amount - me.budget_amount)), 0)           AS avg_abs_variance,
    CASE
        WHEN SUM(me.actual_amount - me.budget_amount) * 100.0 / SUM(me.budget_amount) > 5
             THEN 'INVESTIGATE: sustained overspend'
        WHEN AVG(ABS(me.actual_amount - me.budget_amount)) * 100.0 / AVG(me.budget_amount) > 7
             THEN 'REVIEW: volatile spending'
        ELSE 'OK'
    END AS recommended_action
FROM monthly_expenditure me
JOIN cost_centers cc ON cc.cost_center_id = me.cost_center_id
GROUP BY cc.cost_center_name
ORDER BY total_variance DESC;


-- ---------------------------------------------------------------------
-- 5. COST-BENEFIT ANALYSIS of improvement initiatives
-- ---------------------------------------------------------------------
-- Benefit-Cost Ratio (undiscounted) = (annual_benefit * horizon) / cost
-- ROI % = (total benefit - cost) / cost * 100
-- Payback (years) = cost / annual_benefit
SELECT
    ci.initiative_name,
    cc.cost_center_name,
    ci.implementation_cost,
    ci.annual_benefit * ci.horizon_years                              AS total_benefit,
    ROUND(ci.annual_benefit * ci.horizon_years * 1.0
          / ci.implementation_cost, 2)                                AS benefit_cost_ratio,
    ROUND((ci.annual_benefit * ci.horizon_years - ci.implementation_cost) * 100.0
          / ci.implementation_cost, 1)                                AS roi_pct,
    ROUND(ci.implementation_cost * 1.0 / ci.annual_benefit, 2)        AS payback_years,
    RANK() OVER (ORDER BY (ci.annual_benefit * ci.horizon_years * 1.0
                           / ci.implementation_cost) DESC)            AS priority_rank,
    CASE
        WHEN ci.annual_benefit * ci.horizon_years > ci.implementation_cost * 1.5 THEN 'APPROVE'
        WHEN ci.annual_benefit * ci.horizon_years > ci.implementation_cost       THEN 'MARGINAL - review assumptions'
        ELSE 'REJECT'
    END AS recommendation
FROM cost_initiatives ci
JOIN cost_centers cc ON cc.cost_center_id = ci.cost_center_id
ORDER BY priority_rank;

-- Dialect notes:
--   MySQL 8+: remove "DROP TABLE IF EXISTS" ordering issues by dropping child tables first (already done).
--   SQL Server: replace DATE 'YYYY-MM-DD' literals with 'YYYY-MM-DD' and ROUND(...) works as shown.
