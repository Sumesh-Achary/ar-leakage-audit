Drop TABLE if
CREATE TABLE invoices (
    invoice_id VARCHAR(20),
    customer_id VARCHAR(20),
    customer_name VARCHAR(100),
    customer_segment VARCHAR(50),
    region VARCHAR(50),
    invoice_date DATE,
    due_date DATE,
    invoice_amount NUMERIC(15,2),
    amount_paid NUMERIC(15,2),
    payment_date DATE,
    payment_status VARCHAR(50),
    invoice_category VARCHAR(50),
    sales_rep VARCHAR(100),
    dispute_flag VARCHAR(5),
    dispute_reason VARCHAR(100),
    outstanding_amount NUMERIC(15,2),
    days_to_pay INTEGER,
    days_overdue INTEGER,
    aging_bucket VARCHAR(20),
    recovery_priority VARCHAR(50)
);

select * from invoices;

TRUNCATE TABLE invoices;

SELECT invoice_id, payment_status, days_overdue, aging_bucket 
FROM invoices 
WHERE payment_status IN ('Partial', 'Disputed') 
LIMIT 10;

SELECT 
    aging_bucket,
    COUNT(*) AS invoice_count,
    ROUND(SUM(outstanding_amount), 2) AS outstanding_value,
    ROUND(AVG(outstanding_amount), 2) AS avg_outstanding,
    ROUND(SUM(outstanding_amount) * 100.0 / 
        SUM(SUM(outstanding_amount)) OVER(), 2) AS pct_of_total
FROM invoices
WHERE payment_status IN ('Overdue', 'Partial', 'Disputed')
GROUP BY aging_bucket
ORDER BY 
    CASE aging_bucket
        WHEN '90+ Days' THEN 1
        WHEN '61-90 Days' THEN 2
        WHEN '31-60 Days' THEN 3
        WHEN '0-30 Days' THEN 4
        ELSE 5
    END;


SELECT 
    aging_bucket,
    customer_segment,
    COUNT(*) AS invoice_count,
    ROUND(SUM(outstanding_amount), 2) AS recoverable_amount,
    CASE 
        WHEN aging_bucket = '0-30 Days' THEN 'High - Immediate Follow Up'
        WHEN aging_bucket = '31-60 Days' THEN 'Medium - Escalate to Manager'
        WHEN aging_bucket = '61-90 Days' THEN 'Low - Legal Notice Territory'
        ELSE 'Critical - Write Off Review'
    END AS recovery_action
FROM invoices
WHERE payment_status IN ('Overdue', 'Partial', 'Disputed')
GROUP BY aging_bucket, customer_segment
ORDER BY recoverable_amount DESC;