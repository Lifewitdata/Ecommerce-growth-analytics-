<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=timeGradient&height=220&section=header&text=Ecommerce%20Growth%20Analytics&fontSize=38&fontColor=ffffff&animation=fadeIn&fontAlignY=38&desc=Raw%20CSVs%20%E2%86%92%20MySQL%20%E2%86%92%20Python%20%E2%86%92%20Business%20Insights&descAlignY=55&descSize=17" />

<a href="https://github.com/Lifewitdata">
  <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=20&pause=1000&color=1D9E75&center=true&vCenter=true&width=700&lines=A+full+eCommerce+analytics+pipeline+%E2%80%94+not+just+a+notebook;100%2C000+orders+%C2%B7+10%2C000+customers+%C2%B7+500+SKUs+%C2%B7+40+campaigns;Caught+a+real+pricing+bug+before+it+reached+a+dashboard" alt="Typing SVG" />
</a>

<br/>

![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-150458?style=for-the-badge&logo=pandas&logoColor=white)
![Jupyter](https://img.shields.io/badge/Jupyter-F37626?style=for-the-badge&logo=jupyter&logoColor=white)
![SQLAlchemy](https://img.shields.io/badge/SQLAlchemy-D71F00?style=for-the-badge&logo=sqlalchemy&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

<img src="https://skillicons.dev/icons?i=mysql,python,git,github,vscode&theme=dark" />

</div>

<br/>

## Table of contents

- [Why this project is different](#why-this-project-is-different)
- [Architecture](#architecture)
- [Repository structure](#repository-structure)
- [Data model](#data-model)
- [Bugs I caught before they shipped](#bugs-i-caught-before-they-shipped)
- [Key findings](#key-findings)
- [Dashboards](#dashboards)
- [How to reproduce](#how-to-reproduce)
- [What I'd build next](#what-id-build-next)

<br/>

## Why this project is different

Most portfolio projects stop at *"load a CSV into pandas, make a chart."* This one is built the way an analyst actually works: load into a real relational database with enforced keys and constraints, run SQL-level data quality checks **before** touching Python, catch and document a real inconsistency in the source data, and only then move to Python for what SQL isn't the right tool for — feature engineering, RFM segmentation, and visualization.

> [!IMPORTANT]
> While building the category profitability numbers, every category came back with **negative profit**. That was wrong, and I didn't just round it away — I traced it to a real bug in the source data's `final_price` column (it's a per-unit price, not a line total). See [Bugs I caught before they shipped](#bugs-i-caught-before-they-shipped) below.

<br/>

## Architecture

```mermaid
flowchart TD
    A[Raw CSV files<br/>8 source files] --> B[MySQL raw layer<br/>PK / FK / indexes enforced]
    B --> C[SQL data quality audit<br/>duplicates, nulls, reconciliation]
    C --> D[Python / Pandas<br/>cleaning + feature engineering]
    D --> E[Cleaned datasets<br/>+ RFM segments + margins]
    E --> F[Business analysis<br/>+ visualizations]
    F --> G[Findings & recommendations]

    style A fill:#F1EFE8,stroke:#5F5E5A
    style B fill:#E6F1FB,stroke:#185FA5
    style C fill:#FAEEDA,stroke:#854F0B
    style D fill:#E1F5EE,stroke:#0F6E56
    style E fill:#E1F5EE,stroke:#0F6E56
    style F fill:#EEEDFE,stroke:#534AB7
    style G fill:#E1F5EE,stroke:#0F6E56
```

<br/>

## Repository structure

```
Ecommerce-Growth-Analytics/
├── data/
│   ├── raw/              # original, untouched CSV exports
│   └── cleaned/          # cleaned + feature-engineered CSVs (notebook output)
├── sql/
│   ├── 01_create_raw_tables.sql   # DDL — 8 tables, PKs, FKs, indexes, rationale comments
│   ├── 02_load_raw_data.sql       # LOAD DATA INFILE, FK-safe load order
│   └── 03_business_queries.sql    # 25 business questions answered in SQL
├── notebooks/
│   └── 01_cleaning_and_analysis.ipynb   # MySQL → pandas → cleaning → features → charts
├── dashboards/            # exported chart images
├── docs/
│   ├── ER_and_star_schema.md
│   ├── business_analysis.md
│   └── resume_and_linkedin.md
├── requirements.txt
└── README.md
```

<br/>

## Data model

<details>
<summary><b>Raw source ERD</b> (click to expand)</summary>

```mermaid
erDiagram
    CUSTOMERS ||--o{ ORDERS : places
    CAMPAIGNS ||--o{ ORDERS : drives
    ORDERS ||--|{ ORDER_ITEMS : contains
    PRODUCTS ||--o{ ORDER_ITEMS : appears_in
    ORDERS ||--|| PAYMENTS : paid_via
    ORDERS ||--o| RETURNS : may_have

    CUSTOMERS {
        int customer_id PK
        date signup_date
        int age
        string gender
        string country
        string city
        string acquisition_source
    }
    CAMPAIGNS {
        int campaign_id PK
        string campaign_name
        string channel
        float budget
    }
    ORDERS {
        int order_id PK
        int customer_id FK
        date order_date
        int campaign_id FK
        float order_value
        string status
    }
    ORDER_ITEMS {
        int order_id FK
        int product_id FK
        int quantity
        float unit_price
        float discount_pct
        float final_price
    }
    PRODUCTS {
        int product_id PK
        string sku
        string category
        float cost
        float price
    }
    PAYMENTS {
        int order_id PK
        string payment_method
        float amount
    }
    RETURNS {
        int order_id FK
        string return_reason
    }
```

</details>

<details>
<summary><b>Target star / galaxy schema</b> (click to expand)</summary>

```mermaid
erDiagram
    FACT_ORDERS }o--|| DIM_CUSTOMER : belongs_to
    FACT_ORDERS }o--|| DIM_CAMPAIGN : attributed_to
    FACT_ORDERS }o--|| DIM_DATE : occurred_on
    FACT_ORDER_ITEMS }o--|| FACT_ORDERS : line_of
    FACT_ORDER_ITEMS }o--|| DIM_PRODUCT : references
    FACT_RETURNS }o--|| FACT_ORDERS : reverses

    DIM_CUSTOMER {
        int customer_id PK
        date signup_date
        string country
        string acquisition_source
    }
    DIM_CAMPAIGN {
        int campaign_id PK
        string channel
        float budget
    }
    DIM_PRODUCT {
        int product_id PK
        string category
        float cost
        float price
    }
    DIM_DATE {
        int date_key PK
        date full_date
        int quarter
    }
    FACT_ORDERS {
        int order_id PK
        int customer_id FK
        int campaign_id FK
        float order_value
    }
    FACT_ORDER_ITEMS {
        int order_item_id PK
        int order_id FK
        int product_id FK
        float final_price
    }
    FACT_RETURNS {
        int order_id FK
        string return_reason
    }
```

</details>

Full rationale (why a galaxy schema, why `daily_kpi_snapshot` sits outside the model) is in [`docs/ER_and_star_schema.md`](docs/ER_and_star_schema.md).

<br/>

## Bugs I caught before they shipped

| # | What I found | How I caught it | Fix |
|---|---|---|---|
| 1 | 156 exact duplicate rows in `order_items` | SQL `GROUP BY ... HAVING COUNT(*) > 1` audit | `drop_duplicates()` in the cleaning notebook, before/after row count logged |
| 2 | `final_price` is a **per-unit** price, not a line total — using it directly made every category show negative profit | Sanity-checked `avg(final_price)` against `avg(unit_price) × (1 − avg(discount_pct))` — matched exactly, and was independent of quantity | Every revenue/profit calc now multiplies `final_price × quantity` |
| 3 | `daily_kpi_snapshot.csv` doesn't reconcile with revenue computed from `orders.csv` — off by roughly an order of magnitude, no consistent offset | Row-by-row diff between reported and computed daily revenue (`sql/03_business_queries.sql`, Q25) | Snapshot table treated as a lower-trust reference, not ground truth — all KPIs computed from transactional tables |

> [!WARNING]
> If you're reviewing this repo and want to test your own eye for data issues: try computing category profit using `final_price` alone (no quantity multiplier) before reading the notebook. It's a very natural mistake to make, and the dataset doesn't warn you.

<br/>

## Key findings

<div align="center">

| Metric | Value |
|---|---|
| Net revenue (completed orders) | **$126.1M** |
| Average order value | **$1,679.90** |
| Return rate | **24.95%** |
| Category gross margin | **40–43%** |
| Marketing ROAS (all channels) | **below 1.0** ⚠️ flagged, see below |

</div>

- **Returns** are split almost evenly across *Damaged* (34%), *Changed Mind* (33%), and *Wrong Size* (33%) — and flat across all 5 countries (24–25%). No single fix moves this number; it needs three parallel workstreams (packaging QA, product photography/description clarity, and a sizing tool).
- **Beauty leads on revenue, Electronics leads on margin** — a gap a revenue-only dashboard would hide.
- **Every channel's ROAS comes out under 1.0**, including "Organic," which unusually carries a non-zero budget in this dataset. Read as a data reconciliation issue (budget periods likely don't match order attribution windows), not a real marketing failure — see [`docs/business_analysis.md`](docs/business_analysis.md) for the full reasoning.

<br/>

## Dashboards

<p align="center">
  <img src="dashboards/monthly_revenue_trend.png" width="46%" />
  <img src="dashboards/revenue_by_channel.png" width="46%" />
</p>
<p align="center">
  <img src="dashboards/profit_by_category.png" width="46%" />
  <img src="dashboards/customer_segments.png" width="46%" />
</p>
<p align="center">
  <img src="dashboards/return_reasons.png" width="46%" />
</p>

<br/>

## How to reproduce

```bash
# 1. MySQL setup
mysql -u root < sql/01_create_raw_tables.sql
mysql --local-infile=1 -u root < sql/02_load_raw_data.sql
mysql -u root ecommerce_analytics < sql/03_business_queries.sql

# 2. Python environment
pip install -r requirements.txt

# 3. Run the notebook end to end
jupyter nbconvert --to notebook --execute --inplace notebooks/01_cleaning_and_analysis.ipynb
```

<br/>

## What I'd build next

- [ ] dbt models for `fact_orders` / `fact_order_items` / `dim_*` with automated tests (uniqueness, not-null, referential integrity)
- [ ] Tableau executive dashboard that reconciles against `daily_kpi_snapshot` and surfaces the discrepancy instead of hiding it
- [ ] Cohort retention curves using `signup_cohort` (already engineered in the notebook, not yet visualized)
- [ ] Category-level return rate to prioritize the three returns workstreams

<br/>

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=timeGradient&height=120&section=footer" />

**If you found the data-quality catches interesting, that's the point of the project.**
Full business writeup → [`docs/business_analysis.md`](docs/business_analysis.md) · Resume & interview prep → [`docs/resume_and_linkedin.md`](docs/resume_and_linkedin.md)

</div>
