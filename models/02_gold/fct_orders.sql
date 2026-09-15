-- Grain: one row per order.

-- Overrides the folder default (table) from dbt_project.yml.
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        on_schema_change='fail'
    )
}}

with orders as (

    select * from {{ ref('stg_orders') }}

    {% if is_incremental() %}
    -- Incremental runs only reprocess recent orders. The 3-day lookback re-reads
    -- orders that may have changed since the last run (status updates, new payments);
    -- merge on order_id then updates those rows instead of duplicating them.
    -- Changes to orders older than the window are NOT picked up: use --full-refresh.
    where order_date >= (select max(order_date) - interval '3 days' from {{ this }})
    {% endif %}

),

payments as (

    select * from {{ ref('stg_payments') }}
    where order_id in (select order_id from orders)

),

-- Collapse many payments per order into one row, split by method.
order_payments as (

    select
        order_id,
        sum(case when payment_method = 'credit_card' then amount else 0 end) as credit_card_amount,
        sum(case when payment_method = 'coupon' then amount else 0 end) as coupon_amount,
        sum(case when payment_method = 'bank_transfer' then amount else 0 end) as bank_transfer_amount,
        sum(case when payment_method = 'gift_card' then amount else 0 end) as gift_card_amount,
        sum(amount) as amount

    from payments
    group by order_id

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.status,
        coalesce(order_payments.credit_card_amount, 0) as credit_card_amount,
        coalesce(order_payments.coupon_amount, 0) as coupon_amount,
        coalesce(order_payments.bank_transfer_amount, 0) as bank_transfer_amount,
        coalesce(order_payments.gift_card_amount, 0) as gift_card_amount,
        coalesce(order_payments.amount, 0) as amount

    from orders
    left join order_payments
        on orders.order_id = order_payments.order_id

)

select * from final
