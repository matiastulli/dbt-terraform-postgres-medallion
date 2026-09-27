-- Valid orders only. Rows that break a rule go to stg_orders_quarantine instead;
-- the rules themselves live in base/base_orders.sql.

select
    order_id,
    customer_id,
    order_date,
    status

from {{ ref('base_orders') }}
where quarantine_reason is null
