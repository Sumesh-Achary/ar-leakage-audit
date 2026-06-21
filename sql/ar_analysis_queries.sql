Drop TABLE if exists invoices;
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
    days_to_pay INT,
    days_overdue INT,
    aging_bucket VARCHAR(20),
    recovery_priority VARCHAR(50)
);

select count(*) from invoices;
select * from invoices;

--1: Overall collection health
SELECT 
    payment_status,
    COUNT(*) AS invoice_count,
    ROUND(SUM(invoice_amount), 2) AS total_billed,
    ROUND(SUM(amount_paid), 2) AS total_collected,
    ROUND(SUM(outstanding_amount), 2) AS total_outstanding,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_invoices
FROM invoices
GROUP BY payment_status
ORDER BY total_outstanding DESC;

--2: Aging bucket breakdown
SELECT 
    aging_bucket,
    COUNT(*) AS invoice_count,
    ROUND(SUM(outstanding_amount), 2) AS outstanding_value,
    ROUND(AVG(outstanding_amount), 2) AS avg_outstanding,
    ROUND(SUM(outstanding_amount) * 100.0 / 
        SUM(SUM(outstanding_amount)) OVER(), 2) AS pct_of_total
FROM invoices
WHERE payment_status IN ('Overdue', 'Partial')
GROUP BY aging_bucket
ORDER BY 
    CASE aging_bucket
        WHEN '90+ Days' THEN 1
        WHEN '61-90 Days' THEN 2
        WHEN '31-60 Days' THEN 3
        WHEN '0-30 Days' THEN 4
        ELSE 5
    END;
		
-- 3: Top 10 worst paying customers
SELECT 
    customer_name,
    customer_segment,
    region,
	COUNT(*) AS total_invoices,
    ROUND(SUM(invoice_amount), 2) AS total_billed,
    ROUND(SUM(outstanding_amount), 2) AS total_outstanding,
    ROUND(AVG(days_overdue), 0) AS avg_days_overdue,
    MAX(days_overdue) AS max_days_overdue
FROM invoices
WHERE payment_status IN ('Overdue', 'Partial', 'Disputed')
GROUP BY customer_name, customer_segment, region
ORDER BY total_outstanding DESC
LIMIT 10;


--4: DSO trend by month
SELECT 
    TO_CHAR(invoice_date, 'YYYY-MM') AS invoice_month,
    ROUND(AVG(days_to_pay), 1) AS avg_days_to_pay,
    COUNT(*) AS invoices_paid,
    ROUND(SUM(invoice_amount), 2) AS total_billed
FROM invoices
WHERE payment_status IN ('Paid', 'Late_Paid')
    AND days_to_pay IS NOT NULL
GROUP BY TO_CHAR(invoice_date, 'YYYY-MM')
ORDER BY invoice_month;


--5: Which sales rep has most overdue AR?

SELECT 
    sales_rep,
    COUNT(*) AS overdue_invoices,
    ROUND(SUM(outstanding_amount), 2) AS overdue_value,
    ROUND(AVG(days_overdue), 1) AS avg_days_overdue,
    COUNT(CASE WHEN dispute_flag = 'Yes' THEN 1 END) AS disputed_invoices
FROM invoices
WHERE payment_status IN ('Overdue', 'Partial', 'Disputed')
GROUP BY sales_rep
ORDER BY overdue_value DESC;

--6: Which customer segment pays slowest?

SELECT 
    customer_segment,
    ROUND(AVG(days_to_pay), 1) AS avg_days_to_pay,
    ROUND(AVG(CASE WHEN payment_status = 'Overdue' 
        THEN days_overdue END), 1) AS avg_days_overdue,
    COUNT(CASE WHEN payment_status = 'Overdue' THEN 1 END) AS overdue_count,
    ROUND(SUM(outstanding_amount), 2) AS total_outstanding
FROM invoices
GROUP BY customer_segment
ORDER BY avg_days_to_pay DESC NULLS LAST;

--7: Which invoice types get disputed most?

SELECT 
    invoice_category,
    dispute_reason,
    COUNT(*) AS dispute_count,
    ROUND(SUM(invoice_amount), 2) AS disputed_value,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_disputes
FROM invoices
WHERE dispute_flag = 'Yes'
GROUP BY invoice_category, dispute_reason
ORDER BY dispute_count DESC;

--8: Realistic cash recovery in next 30 days

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
WHERE payment_status IN ('Overdue', 'Partial')
GROUP BY aging_bucket, customer_segment
ORDER BY recoverable_amount DESC;


--9: Which regions have worst payment behaviour?

SELECT 
    region,
    COUNT(*) AS total_invoices,
    ROUND(SUM(invoice_amount), 2) AS total_billed,
    ROUND(SUM(outstanding_amount), 2) AS total_outstanding,
    ROUND(SUM(outstanding_amount) * 100.0 / 
        SUM(invoice_amount), 2) AS outstanding_pct,
    ROUND(AVG(days_overdue), 1) AS avg_days_overdue
FROM invoices
GROUP BY region
ORDER BY outstanding_pct DESC;


--10: Collection efficiency ratio by month

SELECT 
    TO_CHAR(invoice_date, 'YYYY-MM') AS month,
    ROUND(SUM(amount_paid) * 100.0 / 
        NULLIF(SUM(invoice_amount), 0), 2) AS collection_efficiency_pct,
    ROUND(SUM(invoice_amount), 2) AS total_billed,
    ROUND(SUM(amount_paid), 2) AS total_collected,
    ROUND(SUM(outstanding_amount), 2) AS total_outstanding
FROM invoices
GROUP BY TO_CHAR(invoice_date, 'YYYY-MM')
ORDER BY month;
