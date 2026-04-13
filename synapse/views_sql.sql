
CREATE OR ALTER VIEW vw_monthly_transaction_trends AS
SELECT 
    t.year,
    t.month,
    COUNT(*) AS total_transactions,
    SUM(f.amount_clean) AS total_spent
FROM fact_transactions f
JOIN dim_time t 
    ON f.date_key = t.date_key
GROUP BY t.year, t.month;


CREATE OR ALTER VIEW vw_card_and_merchant_summary AS
SELECT 
    c.card_brand,
    c.card_type,
    m.merchant_category,
    COUNT(*) AS total_transactions,
    SUM(f.amount_clean) AS total_spent,
    AVG(c.spending_limit) AS avg_spending_limit
FROM fact_transactions f
JOIN dim_card c ON f.card_id = c.card_id
JOIN dim_merchant m ON f.merchant_id = m.merchant_id
GROUP BY c.card_brand, c.card_type, m.merchant_category;

CREATE OR ALTER VIEW vw_busiest_periods AS
SELECT 
    t.day_of_week,
    t.is_weekend,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) AS total_fraud_transactions,
    AVG(f.amount_clean) AS avg_transaction_amount
FROM fact_transactions f
JOIN dim_time t ON f.date_key = t.date_key
GROUP BY t.day_of_week, t.is_weekend;


CREATE OR ALTER VIEW vw_customer_spending_by_segment AS
SELECT 
    u.age_group,
    u.gender,
    AVG(u.yearly_income) AS avg_yearly_income,
    COUNT(f.transaction_id) AS total_transactions,
    SUM(f.amount_clean) AS total_spent,
    AVG(f.amount_clean) AS avg_spent
FROM fact_transactions f
JOIN dim_customer u ON f.client_id = u.client_id
GROUP BY u.age_group, u.gender;

CREATE OR ALTER VIEW vw_credit_health_and_errors AS
SELECT 
    u.credit_score_band,
    COUNT(f.transaction_id) AS total_transactions,
    SUM(CASE WHEN f.errors <> 'No Error' THEN 1 ELSE 0 END) AS error_count,
    AVG(u.debt_to_income_ratio) AS avg_debt_to_income
FROM fact_transactions f
JOIN dim_customer u ON f.client_id = u.client_id
GROUP BY u.credit_score_band;

CREATE OR ALTER VIEW vw_fraud_hotspots AS
SELECT 
    m.merchant_state,
    m.merchant_category,
    COUNT(*) AS total_fraud_transactions,
    SUM(f.amount_clean) AS total_fraud_amount,
    AVG(f.amount_clean) AS avg_fraud_amount
FROM fact_transactions f
JOIN dim_merchant m ON f.merchant_id = m.merchant_id
WHERE f.is_fraud = 'Yes'
GROUP BY m.merchant_state, m.merchant_category;



SELECT TOP 10 * FROM vw_monthly_transaction_trends;
SELECT TOP 10 * FROM vw_card_and_merchant_summary;
SELECT TOP 10 * FROM vw_busiest_periods;
SELECT TOP 10 * FROM vw_customer_spending_by_segment;
SELECT TOP 10 * FROM vw_credit_health_and_errors;
SELECT TOP 10 * FROM vw_fraud_hotspots;

SELECT * FROM vw_customer_spending_by_segment;

-- ML Model views
CREATE OR ALTER VIEW vw_executive_kpis AS
SELECT
    COUNT(DISTINCT f.transaction_id) AS total_transactions,
    COUNT(DISTINCT f.client_id) AS total_customers,
    ROUND(
        CAST(SUM(CASE WHEN f.is_fraud = 'Yes'
             THEN 1 ELSE 0 END) AS FLOAT)
        / COUNT(*) * 100, 4) AS fraud_rate_pct,
    ROUND(AVG(f.amount_clean), 2) AS avg_spend_per_transaction,
    (SELECT COUNT(*) FROM fraud_predictions 
     WHERE fraud_tier = 'Tier 1-Auto Block') AS auto_blocked_transactions,
    (SELECT COUNT(*) FROM fraud_predictions 
     WHERE fraud_tier = 'Tier 2-Investigate') AS flagged_for_investigation,
    ROUND(SUM(f.amount_clean), 2) AS total_transaction_value
FROM fact_transactions f;

CREATE OR ALTER VIEW vw_customer_segments AS
SELECT
    cs.segment,
    cs.segment_name,
    COUNT(DISTINCT cs.client_id) AS customer_count,
    ROUND(AVG(cs.total_transaction_count), 1) AS avg_txn_count,
    ROUND(AVG(cs.days_since_last_transaction), 1) AS avg_days_inactive,
    ROUND(AVG(cs.transaction_frequency_trend), 4) AS avg_freq_trend,
    ROUND(AVG(cs.avg_spend_per_transaction), 2) AS avg_spend,
    ROUND(AVG(cs.error_rate), 4) AS avg_error_rate,
    ROUND(AVG(cs.insufficient_balance_count), 2) AS avg_insuff_balance
FROM customer_segments cs
JOIN dim_customer dc ON cs.client_id = dc.client_id
GROUP BY
    cs.segment,
    cs.segment_name;

CREATE OR ALTER VIEW vw_fraud_risk_by_customer AS
SELECT
    fp.client_id,
    fp.fraud_tier,
    ROUND(AVG(fp.rf_fraud_probability), 4) AS avg_rf_probability,
    ROUND(AVG(fp.combined_fraud_score), 4) AS avg_combined_score,
    COUNT(*) AS total_transactions,
    SUM(fp.is_fraud_label) AS confirmed_fraud_count,
    dc.age_group,
    dc.credit_score_band,
    dc.yearly_income,
    dc.gender,
    cs.segment_name
FROM fraud_predictions fp
JOIN dim_customer dc ON fp.client_id = dc.client_id
LEFT JOIN customer_segments cs ON fp.client_id = cs.client_id
GROUP BY
    fp.client_id,
    fp.fraud_tier,
    dc.age_group,
    dc.credit_score_band,
    dc.yearly_income,
    dc.gender,
    cs.segment_name;

CREATE OR ALTER VIEW vw_fraud_customer_and_churn_overlap AS
SELECT
    cs.segment_name,
    f.use_chip AS transaction_method,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 
        ELSE 0 END) AS fraud_count,
    ROUND(
        CAST(SUM(CASE WHEN f.is_fraud = 'Yes' 
             THEN 1 ELSE 0 END) AS FLOAT)
        / COUNT(*) * 100, 4) AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN f.is_fraud = 'Yes' 
        THEN f.amount_clean ELSE 0 END), 2) AS total_fraud_amount,
    COUNT(DISTINCT f.client_id) AS affected_customers
FROM fact_transactions f
JOIN customer_segments cs ON f.client_id = cs.client_id
GROUP BY
    cs.segment_name,
    f.use_chip;

-- View 7: Executive KPIs
SELECT * FROM vw_executive_kpis;

-- View 8: Customer Segments
SELECT TOP 10 * FROM vw_customer_segments
ORDER BY segment_name, customer_count DESC;

-- View 9: Fraud Risk by Customer
SELECT TOP 10 * FROM vw_fraud_risk_by_customer
ORDER BY avg_combined_score DESC;

-- View 10: Fraud Customer and Segment Overlap
SELECT * FROM vw_fraud_customer_and_churn_overlap
ORDER BY fraud_rate_pct DESC;

