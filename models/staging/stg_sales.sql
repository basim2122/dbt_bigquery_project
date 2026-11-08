{{ config(materialized='view') }}

SELECT
    order_id,
    product_name,
    amount,
    country,
    order_date,
    {{ dynamic_partition('order_date', 'MONTH') }}  -- Dynamic partitioning
FROM `sales-analytics-514110.sales_dataset.raw_sales`