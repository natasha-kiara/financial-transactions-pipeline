# Financial Transactions Data Engineering Pipeline

A cloud-based, end-to-end data engineering pipeline built on Microsoft Azure that ingests, transforms, and analyses 13.3 million financial transactions to support fraud detection, customer segmentation, and spending behaviour analysis.

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Azure Setup](#3-azure-setup)
4. [GitHub Setup](#4-github-setup)
5. [Dataset Overview](#5-dataset-overview)
6. [Data Dictionary](#6-data-dictionary)
7. [Star Schema Design](#7-star-schema-design)
8. [ADF Pipeline Setup](#8-adf-pipeline-setup)
9. [Databricks Notebooks](#9-databricks-notebooks)
10. [Synapse Analytics](#10-synapse-analytics)
11. [Machine Learning](#11-machine-learning)
12. [Key Findings](#12-key-findings)
13. [Repository Structure](#13-repository-structure)
14. [Team](#14-team)

---

## 1. Project Overview

This pipeline processes a financial transactions dataset sourced from Kaggle, spanning the 2010s decade. It delivers an analytics-ready data warehouse powering an interactive Power BI dashboard and two machine learning components — customer segmentation and layered fraud detection.

**80/20 split:**
- 80% — Data architecture: schema design, ETL, feature engineering, dashboards
- 20% — Machine learning: customer segmentation + fraud detection

**Business questions this pipeline answers:**
- Where are fraud patterns concentrated — by geography, merchant category, or transaction method?
- Which customers are disengaging and what do they look like?
- How has customer spending behaviour changed over the decade?
- Which customer segments require different intervention strategies?
- Which merchants and regions drive the highest transaction volume?

---

## 2. Architecture Overview

```
GitHub (raw data source — Git LFS)
            ↓
Azure Data Factory (ingestion + orchestration)
            ↓
Azure Data Lake Storage Gen2
raw/ → cleaned/ → curated/  (medallion architecture)
            ↓
Azure Databricks (EDA, cleaning, feature engineering, star schema, ML)
            ↓
Azure Synapse Analytics (external tables + 10 SQL views)
            ↓
Power BI (6-page dashboard)
```

All services deployed in **Canada Central** region under resource group `rg-fintech-pipeline` — ensuring PIPEDA compliance for Canadian financial data residency requirements.

---

## 3. Azure Setup

### Resource Group
| Setting | Value |
|---|---|
| Name | rg-fintech-pipeline |
| Region | Canada Central |
| Subscription | Azure for Students |

### Services Provisioned
| Service | Name | Purpose |
|---|---|---|
| Azure Data Lake Storage Gen2 | stfintechpipeline | Raw, cleaned, and curated data storage |
| Azure Data Factory | adf-fintech-pipeline | Data ingestion and pipeline orchestration |
| Azure Databricks | dbw-fintech-pipeline | EDA, transformation, feature engineering, ML |
| Azure Synapse Analytics | synw-fintech-pipeline | Data warehouse, external tables, SQL views |

### Storage Structure — Medallion Architecture
```
stfintechpipeline/
├── raw/          ← original files as ingested, never modified
├── cleaned/      ← cleaned, typed, joined data written as Parquet
└── curated/      ← star schema tables + ML outputs, consumed by Synapse and Power BI
    ├── fact_transactions/
    ├── dim_customer/
    ├── dim_card/
    ├── dim_merchant/
    ├── dim_time/
    ├── customer_features/
    └── fraud_predictions/
```

**Why Parquet?** Column-based format — Synapse reads only the columns a query needs, not the entire file. 3–5× smaller than equivalent CSVs. Native format for serverless SQL pools.

---

## 4. GitHub Setup

Dataset files are stored using **Git Large File Storage (Git LFS)** — files exceed GitHub's 100MB limit.

### Setup Instructions

```bash
# Install Git LFS
git lfs install

# Initialise repo
git init
git remote add origin https://github.com/YOUR_USERNAME/fintech-pipeline-data.git

# Track large file types
git lfs track "*.csv"
git lfs track "*.json"
git add .gitattributes

# Add and push
git add .
git commit -m "add raw financial transaction dataset"
git push -u origin master
```
---

## 5. Dataset Overview

Sourced from the [Kaggle Financial Transactions Dataset](https://www.kaggle.com):

| File | Rows | Description |
|---|---|---|
| transactions_data.csv | 13.3 million | Individual transaction records — core of the pipeline |
| cards_data.csv | 6,146 | Card details linked to customers |
| users_data.csv | 2,000 | Customer demographic and financial information |
| mcc_codes.json | Lookup | Merchant category code descriptions |
| train_fraud_labels.json | 13,332 | Ground truth fraud labels for supervised ML |

---

## 6. Data Dictionary

**Action key:** Keep · Drop · Clean · Derive

### transactions_data.csv

| Column | Type | Nulls | Description | Action |
|---|---|---|---|---|
| id | INT (PK) | 0 | Unique transaction identifier | Keep — rename to transaction_id |
| date | DATETIME | 0 | Timestamp of transaction | Clean — parse to timestamp, extract components for dim_time |
| client_id | INT (FK) | 0 | Links to users_data | Keep — FK to dim_customer |
| card_id | INT (FK) | 0 | Links to cards_data | Keep — FK to dim_card |
| amount | STRING → FLOAT | 0 | Transaction value stored as "$45.23" | Clean — strip $ and cast to float |
| use_chip | STRING | 0 | Chip / Swipe / Online Transaction | Keep — fraud signal |
| merchant_id | INT (FK) | 0 | Identifies the merchant | Keep — FK to dim_merchant |
| merchant_city | STRING | 0 | City where transaction occurred | Keep — move to dim_merchant |
| merchant_state | STRING | 1,563,700 | State — nulls confirmed as online transactions via EDA | Clean — fill "Online" where use_chip is Online Transaction, "Unknown" for residual 5,788 |
| zip | FLOAT | 1,652,706 | Merchant zip code | Drop — 1.65M nulls, redundant with city and state |
| mcc | INT (FK) | 0 | 4-digit merchant category code | Keep — join to mcc_codes for readable category |
| errors | STRING | 13,094,522 | Error type if transaction failed — null means no error | Clean — fill nulls with "No Error" |

### cards_data.csv

| Column | Type | Nulls | Description | Action |
|---|---|---|---|---|
| id | INT (PK) | 0 | Unique card identifier | Keep — rename to card_id |
| client_id | INT (FK) | 0 | Links to users_data | Keep — FK to dim_customer |
| card_brand | STRING | 0 | Visa, Mastercard, Amex, Discover | Keep |
| card_type | STRING | 0 | Credit / Debit / Prepaid | Keep |
| card_number | INT | 0 | Full 16-digit card number | Drop — security compliance |
| expires | STRING → DATE | 0 | Card expiry MM/YYYY | Clean — parse to date |
| cvv | INT | 0 | 3-digit security code | Drop — security compliance |
| has_chip | BOOLEAN | 0 | Whether card has EMV chip | Keep — fraud signal |
| num_cards_issued | INT | 0 | Number of replacement cards issued | Keep |
| credit_limit | STRING → FLOAT | 0 | Stored as "$5,000" | Clean — strip $ and commas, cast to float, rename spending_limit |
| acct_open_date | STRING → DATE | 0 | Account open date | Derive — calculate account_tenure_days |
| year_pin_last_changed | INT | 0 | Last year PIN was changed | Derive — calculate pin_change_recency |
| card_on_dark_web | STRING | 0 | Whether card found on dark web | Drop — zero variation, all "No" confirmed by EDA |

### users_data.csv

| Column | Type | Nulls | Description | Action |
|---|---|---|---|---|
| id | INT (PK) | 0 | Unique customer identifier | Keep — rename to client_id |
| current_age | INT | 0 | Customer age | Derive — create age_group bins (Under 30 / 30–44 / 45–59 / 60+) |
| retirement_age | INT | 0 | Expected retirement age | Keep |
| birth_year | INT | 0 | Birth year | Keep |
| birth_month | INT | 0 | Birth month | Keep |
| gender | STRING | 0 | Customer gender | Keep |
| address | STRING | 0 | Full home address | Drop — latitude and longitude already capture location |
| latitude | FLOAT | 0 | Home latitude | Keep |
| longitude | FLOAT | 0 | Home longitude | Keep |
| per_capita_income | STRING → FLOAT | 0 | Area income stored as "$45,000" | Clean — strip $ and cast to float |
| yearly_income | STRING → FLOAT | 0 | Annual income stored as "$72,000" | Clean — strip $ and cast to float |
| total_debt | STRING → FLOAT | 0 | Total debt stored as "$12,000" | Clean + Derive — cast to float, calculate debt_to_income_ratio |
| credit_score | INT | 0 | Credit score 480–850 | Derive — bin into Poor / Fair / Good / Excellent |
| num_credit_cards | INT | 0 | Total cards held across all banks | Keep |

### mcc_codes.json

| Field | Type | Description | Action |
|---|---|---|---|
| key (mcc) | INT (PK) | 4-digit merchant category code | Join to transactions on mcc |
| value (description) | STRING | Human-readable business type | Add as merchant_category in dim_merchant |

### train_fraud_labels.json

| Field | Type | Description | Action |
|---|---|---|---|
| transaction_id (key) | INT (FK) | Matches id in transactions_data | Join to fact_transactions |
| is_fraud (value) | BOOLEAN | 1 = fraud, 0 = legitimate | Add as is_fraud in fact_transactions |

---

## 7. Star Schema Design

Industry standard dimensional model for analytical queries. One central fact table surrounded by four dimension tables.

**Grain:** One row per financial transaction — one customer, one card, one merchant, one point in time.

```
                  dim_customer
                  (client_id PK)
                       ↑
dim_card ────── fact_transactions ────── dim_merchant
(card_id PK)    (transaction_id PK)      (merchant_id PK)
                FK: client_id
                FK: card_id
                FK: merchant_id
                FK: date_key
                       ↓
                    dim_time
                  (date_key PK)
```

### Final Schema — Post EDA and Cleaning

**fact_transactions**
transaction_id (PK), client_id (FK), card_id (FK), merchant_id (FK), date_key (FK), amount_clean, use_chip, errors, is_fraud, merchant_category

**dim_customer**
client_id (PK), current_age, age_group, gender, credit_score, credit_score_band, yearly_income, total_debt, debt_to_income_ratio, per_capita_income, latitude, longitude, num_credit_cards

**dim_card**
card_id (PK), client_id (FK), card_brand, card_type, spending_limit, has_chip, num_cards_issued, acct_open_date, account_tenure_days, has_expired_card, pin_change_recency

**dim_merchant**
merchant_id (PK), merchant_city, merchant_state, mcc, merchant_category

**dim_time**
date_key (PK), full_date, year, quarter, month, month_name, transaction_day, day_of_week, is_weekend, transaction_hour

**Columns dropped from original design:** zip (high nulls, redundant), cvv (security), card_number (security), card_on_dark_web (zero variation), address (redundant with lat/long)

---

## 8. ADF Pipeline Setup

### Linked Services
| Name | Type | Authentication |
|---|---|---|
| ls_github_http | HTTP | Anonymous |
| ls_adls_fintech | Azure Data Lake Storage Gen2 | Account key |

### Pipeline — pl_ingest_github_to_raw

Five parallel Copy Data activities ingest all files from GitHub into ADLS raw/ simultaneously, followed by three sequential Databricks notebook activities:

```
Copy_Transactions ─┐
Copy_Cards        ─┤
Copy_Users        ─┼─→ [Cleaning Notebook] → [Feature Engineering] → [Star Schema Notebook]
Copy_MCC          ─┤
Copy_Fraud        ─┘
```

**To trigger:** ADF Studio → Author → pl_ingest_github_to_raw → Add trigger → Trigger Now

**To monitor:** ADF Studio → Monitor tab → view all 8 activity statuses

> Note: ADF ARM template export is available on request — excluded from this repo due to file size.

---

## 9. Databricks Notebooks

All notebooks are in the `notebooks/` folder. Run in order — each depends on the previous.

| Notebook | Purpose | Reads From | Writes To |
|---|---|---|---|
| 01_eda.py | 22 investigations across all files — findings drive all downstream decisions | raw/ | — |
| 02_cleaning.py | Strip $, fill nulls, drop security columns, join fraud labels and MCC codes | raw/ | cleaned/ |
| 03_feature_engineering.py | Build transaction-level and customer-level features for ML and Synapse views | cleaned/ | curated/customer_features/ |
| 04_star_schema.py | Construct five star schema tables | cleaned/ | curated/ (all 5 tables) |
| 05_ml_segmentation.py | K-Means customer segmentation — three segments identified | curated/customer_features/ | curated/customer_segments/ |
| 06_ml_fraud_detection.py | Logistic Regression, Random Forest, Isolation Forest + layered detection | cleaned/ | curated/fraud_predictions/ |

### Key Cleaning Decisions (from EDA)

| Decision | EDA Evidence |
|---|---|
| Fill null merchant_state → "Online" | 100% of null states confirmed as Online transactions by groupby |
| Drop zip | 1.65M nulls, 25,256 unique values, redundant with city and state |
| Drop card_on_dark_web | All 6,146 cards returned "No" — zero analytical value |
| errors fill → "No Error" | 13M nulls = clean transactions, not missing data |
| Drop address | Latitude and longitude already capture location |

---

## 10. Synapse Analytics

### External Tables
Five external tables point directly to curated/ Parquet files — no data copying, no duplication.

| Table | ADLS Path |
|---|---|
| fact_transactions | curated/fact_transactions/ |
| dim_customer | curated/dim_customer/ |
| dim_card | curated/dim_card/ |
| dim_merchant | curated/dim_merchant/ |
| dim_time | curated/dim_time/ |

SQL scripts for external table creation and all views are in the `synapse/` folder.

### SQL Views — 10 Views Across 5 Stakeholder Audiences

| View | Stakeholder | What It Returns |
|---|---|---|
| vw_monthly_transaction_trends | Bank Manager | Monthly volume and spend 2010–2019 |
| vw_card_and_merchant_summary | Bank Manager | Card usage breakdown and top merchants |
| vw_busiest_periods | Bank Manager + Fraud | Peak transaction days and hours |
| vw_customer_spending_by_segment | Marketing | Spend patterns by income and age group |
| vw_credit_health_and_errors | Credit Risk | Error rates and debt profiles by customer |
| vw_fraud_hotspots | Fraud Team | Fraud concentration by state and merchant category |
| vw_fraud_analysis | Fraud Team | Fraud by transaction method and time of day |
| vw_churn_risk_segments | Marketing + Retention | K-Means segment assignments and signals |
| vw_retention_priority | Retention | Voluntary disengager customers ranked by inactivity |
| vw_fraud_customer_overlap | Fraud + Risk | Customers appearing in both fraud and stress signals |

**Pool:** Built-in serverless SQL — $5/TB, fractions of a cent per query at this dataset scale.

---

## 11. Machine Learning

### ML Component 1 — Customer Segmentation

Churn prediction was attempted using five methodologies — 60-day inactivity threshold, 180-day threshold, transaction frequency comparison, K-Means k=2, and PCA + clustering. None produced a viable churn label. The dataset was designed for fraud detection and shows consistent decade-long growth with no natural disengagement patterns.

**Outcome:** K-Means k=3 produced three actionable customer segments:

| Segment | Customers | Key Signal | Recommended Action |
|---|---|---|---|
| Voluntary Disengagers | 429 (35%) | 38.5 days inactive, lowest transactions (7,409 avg), low errors | Proactive retention outreach |
| Financially Stressed | 512 (42%) | Almost zero inactivity, highest error rate, 114 avg Insufficient Balance errors | Financial wellness products, credit review |
| Power Users | 278 (23%) | Highest transactions (16,144 avg), highest spend ($56.91 avg), lowest fraud | Loyalty rewards, premium card offers |

### ML Component 2 — Fraud Detection

Three models trained and compared on 13.3M transactions with 13,332 confirmed fraud cases (0.1% fraud rate):

| Metric | Logistic Regression | Random Forest | Isolation Forest |
|---|---|---|---|
| AUC-ROC | 0.9522 | **0.9843** | 0.8627 |
| AUC-PR | 0.1099 | **0.1887** | 0.4020 |
| Fraud Recall | 92.1% | 96.8% | 1% |
| False Alarms | 336,311 | ~83,000 | 30 |
| Needs Labels | Yes | Yes | No |

**Top fraud predictors (Random Forest):** merchant_state (38.5%), is_home_state (24.3%), merchant_category (21.5%). Fraud is primarily geographic — not behavioural.

### Layered Detection System

Combined RF and IF scores into one weighted score:

```
Combined Score = (0.6 × RF probability) + (0.4 × IF anomaly score)
```

| Tier | Threshold | Action |
|---|---|---|
| Tier 1 — Auto Block | Score > 0.8 | Block immediately |
| Tier 2 — Investigate | Score 0.5–0.8 | Queue for investigator review |
| Tier 3 — Monitor | Score < 0.5 | Proceed normally |

**Combined detection rate: ~93.5% of all fraud caught.**

---

## 12. Key Findings

- **Fraud is geographic** — online transactions carry 28× higher fraud rate than swipe. Location explains 84% of fraud prediction.
- **35% of customers quietly disengaging** — 429 customers inactive with no financial stress signal. Retention window still open.
- **42% financially stressed** — 512 customers hitting Insufficient Balance errors repeatedly while remaining highly active.
- **Insufficient Balance dominates errors** — 130,902 occurrences, strongest financial stress signal in the dataset.
- **Mastercard Debit dominates** — 2,191 cards. Amex is 100% credit. 646 chipless cards across all brands — higher fraud risk.
- **Dataset complete across the decade** — spending grew 2010–2013 then stabilised. No gaps or drop-offs.

---

## 13. Repository Structure

```
fintech-pipeline-data/
├── transactions_data.csv        ← stored via Git LFS
├── cards_data.csv               ← stored via Git LFS
├── users_data.csv               ← stored via Git LFS
├── mcc_codes.json               ← stored via Git LFS
├── train_fraud_labels.json      ← stored via Git LFS
├── notebooks/
│   ├── 01_eda.py
│   ├── 02_cleaning.py
│   ├── 03_feature_engineering.py
│   ├── 04_star_schema.py
│   ├── 05_ml_segmentation.py
│   └── 06_ml_fraud_detection.py
├── synapse/
│   ├── external_tables.sql
│   └── views.sql
├── adf/
│   ├── ARMTemplateForFactory.json
│   ├── ARMTemplateParametersForFactory.json
│   ├── factory/
│   └── linkedTemplates/
├── docs/
│   └── star_schema.png
└── README.md
```

---

## 14. Team

Natasha Kiara · Ujunwa Okwuaka · Oloruntobi Salami

**Course:** DAMG 7370 — Northeastern University, Canada Campus

**Platform:** Microsoft Azure (Canada Central) | **Tools:** Databricks · Synapse Analytics · ADF · Power BI · PySpark · SQL
