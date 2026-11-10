-- Grain: one row per payment. fct_orders has the same money summed per order.
-- Raw payments have no date of their own, so the order's date is carried over
-- and keeps its name (order_date) instead of pretending to be a payment date.

with payments as (

    select * from {{ ref('int_payments') }}

),

orders as (

    select order_id, customer_id, order_date from {{ ref('int_orders') }}

),

final as (

    select
        payments.payment_id,
        payments.order_id,
        orders.customer_id,
        orders.order_date,
        payments.payment_method,
        payments.amount

    from payments
    -- int_payments only keeps payments for orders in int_orders, so no row is lost here
    inner join orders
        on payments.order_id = orders.order_id

)

select * from final
