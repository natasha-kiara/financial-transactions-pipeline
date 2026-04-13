-- CREATE DATABASE fintech_dw;
-- DROP EXTERNAL TABLE dim_customer;

CREATE EXTERNAL FILE FORMAT parquet_format
WITH(
    FORMAT_TYPE = PARQUET
);

CREATE EXTERNAL TABLE dim_customer(
    client_id INT,
    current_age INT,
    gender VARCHAR(10),
    birth_year INT,
    birth_mont INT,
    retirement_age INT,
    years_to_retirement INT,
    age_group VARCHAR(20),
    yearly_income FLOAT,
    per_capita_income FLOAT,
    total_debt FLOAT,
    credit_score INT,
    credit_score_band VARCHAR(20),
    debt_to_income_ratio FLOAT,
    num_credit_cards INT,
    latitude FLOAT,
    longitude FLOAT
)
WITH(
    LOCATION = 'dim_customer/',
    DATA_SOURCE = curated_adls,
    FILE_FORMAT = parquet_format
);

CREATE EXTERNAL TABLE dim_card(
    card_id INT,
    client_id INT,
    card_brand VARCHAR(20),
    card_type VARCHAR(20),
    has_chip VARCHAR(5),
    num_cards_issued INT,
    spending_limit FLOAT,
    acct_open_date VARCHAR(10),
    account_tenure_days INT,
    expires VARCHAR(10),
    has_expired_card BIT,
    days_until_card_expiry INT,
    year_pin_last_changed INT,
    pin_change_recency INT
)
WITH(
    LOCATION ='dim_card/',
    DATA_SOURCE = curated_adls,
    FILE_FORMAT = parquet_format
);

CREATE EXTERNAL TABLE dim_merchant(
    merchant_id INT,
    merchant_city VARCHAR(100),
    merchant_state VARCHAR(50),
    mcc INT,
    merchant_category VARCHAR(100)
)
WITH (
    LOCATION = 'dim_merchant/',
    DATA_SOURCE = curated_adls,
    FILE_FORMAT = parquet_format
);

CREATE EXTERNAL TABLE dim_time(
    date_key INT,
    full_date DATE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    day_of_month INT,
    day_of_week VARCHAR(20),
    is_weekend BIT
)
WITH (
    LOCATION = 'dim_time/',
    DATA_SOURCE = curated_adls,
    FILE_FORMAT = parquet_format
);

DROP EXTERNAL TABLE fact_transactions;

CREATE EXTERNAL TABLE fact_transactions (
    transaction_id    BIGINT,
    client_id         INT,
    card_id           INT,
    merchant_id       INT,
    date_key          INT,
    amount_clean      FLOAT,
    use_chip          VARCHAR(20),
    is_fraud          VARCHAR(10),
    merchant_category VARCHAR(100),
    errors            VARCHAR(100),
    churn_risk_score  FLOAT
)
WITH (
    LOCATION = 'fact_transactions/',
    DATA_SOURCE = curated_adls,
    FILE_FORMAT = parquet_format
);

CREATE EXTERNAL TABLE customer_features(
    client_id INT,
    total_transaction_count INT,
    total_spend FLOAT,
    avg_spend_per_transaction FLOAT,
    days_since_last_transaction INT,
    avg_days_between_transactions FLOAT,
    error_count INT,
    error_rate FLOAT,
    insufficient_balance_count INT,
    transaction_frequency_trend FLOAT,
    max_spending_limit FLOAT,
    max_account_tenure_days INT,
    max_spending_limit_utilization FLOAT,
    chip_card_count INT,
    current_age INT,
    gender VARCHAR(10),
    yearly_income FLOAT,
    total_debt FLOAT,
    per_capita_income FLOAT,
    credit_score INT,
    num_credit_cards INT,
    latitude FLOAT,
    longitude FLOAT,
    debt_to_income_ratio FLOAT,
    years_to_retirement INT,
    credit_score_band VARCHAR(20),
    age_group VARCHAR(20),
    debt_to_income_band VARCHAR(20)
)
WITH (
    LOCATION = 'customer_features/',
    DATA_SOURCE = curated_adls,
    FILE_FORMAT = parquet_format
);

SELECT COUNT(*) AS row_count FROM dim_customer;
SELECT COUNT(*) AS row_count FROM dim_card;
SELECT COUNT(*) AS row_count FROM dim_merchant;
SELECT COUNT(*) AS row_count FROM dim_time;
SELECT COUNT(*) AS row_count FROM fact_transactions;
SELECT TOP 5 * FROM customer_features;

SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'customer_features'
ORDER BY ORDINAL_POSITION;

-- ML model external tables
CREATE EXTERNAL TABLE fraud_predictions (
    id                      BIGINT,
    client_id               INT,
    rf_fraud_probability    FLOAT,
    if_anomaly_score        FLOAT,
    combined_fraud_score    FLOAT,
    fraud_tier              VARCHAR(30),
    is_fraud_label          INT
)
WITH (
    LOCATION = 'fraud_predictions/',
    DATA_SOURCE = curated_adls,
    FILE_FORMAT = parquet_format
);

CREATE EXTERNAL TABLE customer_segments (
    client_id                       INT,
    segment                         INT,
    total_transaction_count         BIGINT,
    days_since_last_transaction     INT,
    transaction_frequency_trend     FLOAT,
    avg_spend_per_transaction       FLOAT,
    error_rate                      FLOAT,
    insufficient_balance_count      BIGINT,
    segment_name                    VARCHAR(30)
)
WITH (
    LOCATION = 'customer_segments/',
    DATA_SOURCE = curated_adls,
    FILE_FORMAT = parquet_format
);

SELECT TOP 5 * FROM fraud_predictions;
SELECT TOP 5 * FROM customer_segments;
