# Financial Transactions Data Engineering Pipeline

A cloud-based data engineering pipeline built on Microsoft Azure that ingests, transforms, and analyses financial transaction data to support customer churn prediction, fraud detection, and spending behaviour analysis.

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
9. [Repository Structure](#9-repository-structure)
10. [Team](#10-team)

---

## 1. Project Overview

This pipeline processes a financial transactions dataset sourced from Kaggle, spanning the 2010s decade. The end goal is to build an analytics-ready data warehouse that powers an interactive Power BI dashboard and a machine learning model that identifies customers at risk of churning.

**80/20 split:**
- 80% — Data architecture: schema design, ETL, feature engineering, dashboards
- 20% — Machine learning: customer churn prediction model

**Key business questions this pipeline answers:**
- Which customers are at risk of churning and why?
- Where are fraud patterns concentrated — by geography, merchant category, or card type?
- How has customer spending behaviour changed over time?
- Which customer segments generate the most revenue at risk?

---

## 2. Architecture Overview

```
GitHub (raw data)
      ↓
Azure Data Factory (ingestion + orchestration)
      ↓
Azure Data Lake Storage Gen2 (raw/ → cleaned/ → curated/)
      ↓
Azure Databricks (transformation + feature engineering + ML)
      ↓
Azure Synapse Analytics (data warehouse + SQL analysis)
      ↓
Power BI (dashboards + reporting)
```

All services are deployed in the **Canada Central** region under the resource group `rg-fintech-pipeline`, ensuring data residency compliance with Canadian financial data regulations (PIPEDA).

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
| Azure Databricks | dbw-fintech-pipeline | Data transformation, feature engineering, ML |
| Azure Synapse Analytics | synw-fintech-pipeline | Data warehouse and SQL business analysis |

### Storage Structure
The storage account follows a **medallion architecture** pattern — three containers representing three stages of data quality:

```
stfintechpipeline/
├── raw/          ← original files as ingested, never modified
├── cleaned/      ← cleaned and validated data, ready for transformation
└── curated/      ← analytics-ready star schema tables for Synapse and Power BI
```

---

## 4. GitHub Setup

The dataset files are stored in this private GitHub repository using **Git Large File Storage (Git LFS)** because the files exceed GitHub's standard 100MB file size limit.

### Why Git LFS?
Git LFS stores large files on GitHub's servers separately from the regular repository. A small pointer file is kept in the repo in place of the actual file. This keeps the repository lightweight while still allowing large files to be versioned and accessed via raw URLs.

### Setup Instructions

**Prerequisites:**
- Git installed
- Git LFS installed (`sudo apt-get install git-lfs` on Ubuntu, `brew install git-lfs` on Mac)

**Steps to reproduce this setup:**

```bash
# Install and initialise Git LFS
git lfs install

# Initialise repo and connect to GitHub
git init
git remote add origin https://github.com/YOUR_USERNAME/fintech-pipeline-data.git

# Track large file types via LFS
git lfs track "*.csv"
git lfs track "*.json"
git add .gitattributes

# Add dataset files
git add transactions_data.csv cards_data.csv users_data.csv mcc_codes.json train_fraud_labels.json

# Commit and push
git commit -m "add raw financial transaction dataset"
git push -u origin master
```

**Verify LFS is working:**
After pushing, each file in the GitHub repo should display **"stored with Git LFS"** next to the file name.

### Raw File URLs
These URLs are used by Azure Data Factory to pull files directly into ADLS:

| File | Raw URL |
|---|---|
| transactions_data.csv | `https://raw.githubusercontent.com/YOUR_USERNAME/fintech-pipeline-data/master/transactions_data.csv` |
| cards_data.csv | `https://raw.githubusercontent.com/YOUR_USERNAME/fintech-pipeline-data/master/cards_data.csv` |
| users_data.csv | `https://raw.githubusercontent.com/YOUR_USERNAME/fintech-pipeline-data/master/users_data.csv` |
| mcc_codes.json | `https://raw.githubusercontent.com/YOUR_USERNAME/fintech-pipeline-data/master/mcc_codes.json` |
| train_fraud_labels.json | `https://raw.githubusercontent.com/YOUR_USERNAME/fintech-pipeline-data/master/train_fraud_labels.json` |

---

## 5. Dataset Overview

The dataset is sourced from the [Kaggle Financial Transactions Dataset](https://www.kaggle.com) and consists of five files:

| File | Rows | Description |
|---|---|---|
| transactions_data.csv | 13.3 million | Individual transaction records — the core of the pipeline |
| cards_data.csv | 6,146 | Card details linked to customers |
| users_data.csv | 2,000 | Customer demographic and financial information |
| mcc_codes.json | — | Merchant category code lookup table |
| train_fraud_labels.json | — | Ground truth fraud labels for ML training |

---

## 6. Data Dictionary

A data dictionary documents every column across all five files — what it means, its data type, whether it has missing values, and what action is taken during transformation.

**Action key:**
- **Keep** — used as-is
- **Drop** — removed for security or irrelevance
- **Clean** — requires transformation before use
- **Derive** — new column created from this column

---

### transactions_data.csv

| Column | Type | Nulls | Description | Action |
|---|---|---|---|---|
| id | INT (PK) | 0 | Unique transaction identifier | Keep — rename to transaction_id |
| date | DATETIME | 0 | Timestamp of transaction | Clean — parse to datetime, split into year/month/day/hour for dim_time |
| client_id | INT (FK) | 0 | Links to users_data — identifies the customer | Keep — foreign key to dim_customer |
| card_id | INT (FK) | 0 | Links to cards_data — identifies the card used | Keep — foreign key to dim_card |
| amount | STRING → FLOAT | 0 | Transaction value stored as "$45.23" — $ sign makes it a string | Clean — strip $ and cast to float |
| use_chip | STRING | 0 | How card was used — Chip, Swipe, or Online | Keep — fraud signal |
| merchant_id | INT (FK) | 0 | Identifies the merchant | Keep — foreign key to dim_merchant |
| merchant_city | STRING | 0 | City where transaction occurred | Keep — move to dim_merchant |
| merchant_state | STRING | 1,563,700 | State where transaction occurred — nulls likely online transactions | Clean — fill nulls with "Online" or "Unknown" |
| zip | FLOAT | 1,652,706 | Merchant zip code — frequently missing | Clean — fill nulls with "Unknown" |
| mcc | INT (FK) | 0 | 4-digit merchant category code — links to mcc_codes.json | Keep — join to mcc_codes for readable category |
| errors | STRING | 13,094,522 | Error code if transaction failed — null means success | Clean — fill nulls with "None". Strong churn and fraud signal |

---

### cards_data.csv

| Column | Type | Nulls | Description | Action |
|---|---|---|---|---|
| id | INT (PK) | 0 | Unique card identifier — matches card_id in transactions | Keep — rename to card_id |
| client_id | INT (FK) | 0 | Links to users_data — identifies card owner | Keep — foreign key to dim_customer |
| card_brand | STRING | 0 | Visa, Mastercard, Amex etc. | Keep — useful for segmentation |
| card_type | STRING | 0 | Credit or Debit | Keep — churn signal |
| card_number | INT | 0 | Full 16-digit card number | Drop — security risk, no analytical value |
| expires | STRING → DATE | 0 | Card expiry date MM/YYYY | Clean — parse to date |
| cvv | INT | 0 | 3-digit card security code | Drop — serious security risk, never store |
| has_chip | BOOLEAN | 0 | Whether card has EMV chip — chipless cards are easier to clone | Keep — fraud signal |
| num_cards_issued | INT | 0 | Number of replacement cards issued — high count may indicate fraud history | Keep |
| credit_limit | STRING → FLOAT | 0 | Maximum card spend stored as "$5,000" | Clean — strip $ and commas, cast to float |
| acct_open_date | STRING → DATE | 0 | When account was opened | Derive — calculate acct_tenure_days |
| year_pin_last_changed | INT | 0 | Last year PIN was changed | Keep — security behaviour signal |
| card_on_dark_web | BOOLEAN | 0 | Whether card details found on dark web | Keep — strongest fraud signal in dataset, encode as 0/1 |

---

### users_data.csv

| Column | Type | Nulls | Description | Action |
|---|---|---|---|---|
| id | INT (PK) | 0 | Unique customer identifier — matches client_id everywhere | Keep — rename to client_id |
| current_age | INT | 0 | Customer age — ranges 18 to 101, avg 45 | Derive — create age_group bins |
| retirement_age | INT | 0 | Expected retirement age — avg 66 | Derive — calculate years_to_retirement |
| birth_year | INT | 0 | Customer birth year | Clean — combine with birth_month into birth_date |
| birth_month | INT | 0 | Customer birth month | Clean — combine with birth_year into birth_date |
| gender | STRING | 0 | Customer gender | Keep — segmentation variable |
| address | STRING | 0 | Full home address | Clean — extract state only, mask full address for privacy |
| latitude | FLOAT | 0 | Customer home latitude | Keep — geographic churn analysis and Power BI maps |
| longitude | FLOAT | 0 | Customer home longitude | Keep — geographic churn analysis and Power BI maps |
| per_capita_income | STRING → FLOAT | 0 | Area income level stored as "$45,000" | Clean — strip $ and commas, cast to float |
| yearly_income | STRING → FLOAT | 0 | Customer annual income stored as "$72,000" | Clean — strip $ and commas, cast to float |
| total_debt | STRING → FLOAT | 0 | Customer total debt stored as "$12,000" | Clean + Derive — cast to float, calculate debt_to_income ratio |
| credit_score | INT | 0 | Credit score — ranges 480 to 850, avg 710 | Derive — bin into Poor/Fair/Good/Excellent bands |
| num_credit_cards | INT | 0 | Total credit cards held across all banks | Keep — high count is a churn risk indicator |

---

### mcc_codes.json

| Field | Type | Description | Action |
|---|---|---|---|
| key (mcc) | INT (PK) | 4-digit merchant category code — matches mcc in transactions_data | Join to transactions on mcc column |
| value (description) | STRING | Human readable business type e.g. "Grocery Stores and Supermarkets" | Add as merchant_category column in dim_merchant |

---

### train_fraud_labels.json

| Field | Type | Description | Action |
|---|---|---|---|
| transaction_id (key) | INT (FK) | Matches id in transactions_data | Join to fact_transactions on transaction_id |
| is_fraud (value) | BOOLEAN | 1 = fraudulent, 0 = legitimate. Ground truth for ML model | Add as is_fraud in fact_transactions. Unmatched rows stay NULL — do not fill with 0 |

---

## 7. Star Schema Design

The data is modelled using a **star schema** — an industry standard pattern for financial analytics. One central fact table is surrounded by four dimension tables.

**Fact table grain:** One row per financial transaction — each row represents a single card payment made by one customer at one merchant at one specific point in time.

**Fact table purpose:** Records every financial transaction to support fraud detection, churn prediction, and customer spending behaviour analysis across the 2010s decade.

```
                  DimCustomer
                  (client_id PK)
                       ↑
DimCard ───────── FactTransactions ───────── DimMerchant
(card_id PK)      (transaction_id PK)        (merchant_id PK)
                  FK: client_id
                  FK: card_id
                  FK: merchant_id
                  FK: date_key
                       ↓
                    DimTime
                  (date_key PK)
```

### Table Columns

**FactTransactions**
transaction_id (PK), client_id (FK), card_id (FK), merchant_id (FK), date_key (FK), amount, use_chip, errors, is_fraud, churn_risk_score

**DimCustomer**
client_id (PK), age, age_group, gender, credit_score, credit_band, yearly_income, total_debt, debt_to_income, latitude, longitude

**DimCard**
card_id (PK), client_id (FK), card_brand, card_type, credit_limit, has_chip, card_on_dark_web, acct_tenure_days

**DimMerchant**
merchant_id (PK), merchant_city, merchant_state, zip, mcc, merchant_category

**DimTime**
date_key (PK), full_date, year, quarter, month, month_name, day_of_week, is_weekend, hour

> Note: churn_risk_score will be populated in Week 4 after the ML model produces predictions.

---

## 8. ADF Pipeline Setup

### Linked Services
| Name | Type | Authentication | Purpose |
|---|---|---|---|
| ls_github_http | HTTP | Anonymous | Connects to GitHub raw file URLs |
| ls_adls_fintech | Azure Data Lake Storage Gen2 | Account key | Connects to stfintechpipeline storage account |

### Datasets

**Source datasets — GitHub:**
| Name | Format | Relative URL |
|---|---|---|
| ds_github_transactions | DelimitedText (CSV) | transactions_data.csv |
| ds_github_cards | DelimitedText (CSV) | cards_data.csv |
| ds_github_users | DelimitedText (CSV) | users_data.csv |
| ds_github_mcc | JSON | mcc_codes.json |
| ds_github_fraud | JSON | train_fraud_labels.json |

**Sink datasets — ADLS raw/:**
| Name | Format | Destination |
|---|---|---|
| ds_adls_raw_transactions | DelimitedText (CSV) | raw/transactions_data.csv |
| ds_adls_raw_cards | DelimitedText (CSV) | raw/cards_data.csv |
| ds_adls_raw_users | DelimitedText (CSV) | raw/users_data.csv |
| ds_adls_raw_mcc | JSON | raw/mcc_codes.json |
| ds_adls_raw_fraud | JSON | raw/train_fraud_labels.json |

### Pipeline — pl_ingest_github_to_raw

Five parallel Copy Data activities ingest all files from GitHub into ADLS raw/ simultaneously:

```
Copy_Transactions ─┐
Copy_Cards        ─┤
Copy_Users        ─┼─→ ADLS raw/ container
Copy_MCC          ─┤
Copy_Fraud        ─┘
```

**To run manually:** ADF Studio → Author → pl_ingest_github_to_raw → Add trigger → Trigger Now

**To monitor:** ADF Studio → Monitor tab → view activity run status and row counts

> Databricks notebook activities will be added to this pipeline in Week 3 to extend it into a full end-to-end orchestrated pipeline: ingest → clean → feature engineer.

---

## 9. Repository Structure

```
fintech-pipeline-data/
├── transactions_data.csv         ← stored via Git LFS
├── cards_data.csv                ← stored via Git LFS
├── users_data.csv                ← stored via Git LFS
├── mcc_codes.json                ← stored via Git LFS
├── train_fraud_labels.json       ← stored via Git LFS
└── README.md
```

> Notebooks, SQL scripts, and architecture diagrams will be added in subsequent weeks.

---
