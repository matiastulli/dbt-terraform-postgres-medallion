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
        -- One column per method in var('payment_methods') (dbt_project.yml).
        -- Column order must stay stable: on_schema_change='fail' guards this table.
        {% for payment_method in var('payment_methods') -%}
        sum(case when payment_method = '{{ payment_method }}' then amount else 0 end) as {{ payment_method }}_amount,
        {% endfor -%}
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
        {% for payment_method in var('payment_methods') -%}
        coalesce(order_payments.{{ payment_method }}_amount, 0) as {{ payment_method }}_amount,
        {% endfor -%}
        coalesce(order_payments.amount, 0) as amount

    from orders
    left join order_payments
        on orders.order_id = order_payments.order_id

)

select * from final
