-- Singular test: passes when it returns zero rows.
-- Revenue must survive the silver -> gold joins without being lost or double-counted
-- (e.g. payments for orders missing from stg_orders would be dropped).

with silver as (

    select sum(amount) as total from {{ ref('stg_payments') }}

),

gold as (

    select sum(amount) as total from {{ ref('fct_orders') }}

)

select
    silver.total as silver_total,
    gold.total as gold_total

from silver
cross join gold
where silver.total <> gold.total
