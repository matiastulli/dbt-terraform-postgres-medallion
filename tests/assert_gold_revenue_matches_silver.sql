-- Singular test: passes when it returns zero rows.
-- Revenue must survive silver -> gold without being lost or double-counted.
-- Three totals must match: valid payments in silver, the payment-grain fact,
-- and the order-grain fact (which can drift, since it's incremental).

with totals as (

    select
        (select sum(amount) from {{ ref('int_payments') }}) as silver_payments,
        (select sum(amount) from {{ ref('fct_payments') }}) as gold_payments,
        (select sum(amount) from {{ ref('fct_orders') }}) as gold_orders

)

select *
from totals
where silver_payments <> gold_payments
    or silver_payments <> gold_orders
