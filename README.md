# Budget Variance & Cost-Benefit SQL Analysis

> Pure ANSI SQL analysis that compares budgeted vs. actual expenditure, flags high-variance cost centers and ranks improvement initiatives by cost-benefit.

## Business problem
Overspending is often discovered only after a period closes. Management needs an early-warning view: which cost centers are drifting from budget, is the drift a trend or noise, and which initiatives deserve funding?

## What's inside
| File | Purpose |
|---|---|
| `budget_variance_analysis.sql` | Schema, sample data, variance query, summary and cost-benefit analysis |

## Data model
```
cost_centers (1) ──< monthly_expenditure   (budget_amount, actual_amount by month)
cost_centers (1) ──< cost_initiatives      (implementation_cost, annual_benefit)
```

## SQL techniques demonstrated
- `CREATE TABLE` with primary/foreign keys, `CHECK` and `UNIQUE` constraints
- CTEs (`WITH`) to layer the logic
- Window functions: `SUM() OVER (PARTITION BY … ORDER BY … ROWS BETWEEN …)` for YTD totals, `LAG()` for month-over-month change, `RANK()` for prioritisation
- `CASE WHEN` for RAG flags and recommendations
- Safe division and percent-variance calculation

## How to run
```bash
# PostgreSQL
psql -d your_db -f budget_variance_analysis.sql

# or SQLite (3.25+ supports window functions); replace DATE '…' with '…' strings
# or paste into DB Fiddle / an online SQL playground
```

## Variance convention
`variance = actual − budget`. For expense lines, **positive = overspend (unfavourable)**.

| Flag | Rule |
|---|---|
| RED | Overspend > 10% |
| AMBER | Overspend 5-10% |
| BLUE | Underspend > 10% (check under-delivery) |
| GREEN | Within tolerance |

## Insights (sample data)
- **Logistics:** overspend grows every month after January and ends the half-year 17.7% over budget (KES 53,000), flagged INVESTIGATE. That pattern points to a structural cost driver (fuel, routes, rates) rather than one-off noise.
- **Marketing:** alternating over- and under-spend with a small net overspend (about 3%), flagged REVIEW; a phasing and control issue rather than a budget-level problem.
- **IT:** tight control, stays within ~3% of budget.
- **Admin:** consistently under budget, which may be genuine savings or deferred spend.
- **Initiatives:** cloud rightsizing ranks first (BCR 4.5, payback 0.67 years); the marketing automation platform is rejected (BCR 0.9) because it does not pay back within three years on current assumptions.

## Extensions
- Connect to Power BI for a variance waterfall by cost center.
- Add forecast: project year-end variance from the YTD run-rate.
- Discount benefits for an NPV-based cost-benefit analysis.

## Author
Abdimanar Edin Guyo: Accountant, Financial Analyst & Data Analyst
