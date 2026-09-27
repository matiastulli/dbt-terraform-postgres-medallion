-- Valid payments only. Rows that break a rule go to stg_payments_quarantine instead;
-- the rules themselves live in base/base_payments.sql.

select
    payment_id,
    order_id,
    payment_method,
    amount

from {{ ref('base_payments') }}
where quarantine_reason is null
