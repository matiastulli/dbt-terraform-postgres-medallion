-- Valid payments only: the business rules that decide which payments reach gold.
-- Drops payments with a null id, a method not in var('payment_methods'),
-- a null or negative amount, or an order that isn't in int_orders.

with payments as (

    select * from {{ ref('stg_payments') }}

),

-- Valid orders only: a payment for a dropped order is dropped too,
-- otherwise its revenue would reach silver but never gold.
orders as (

    select order_id from {{ ref('int_orders') }}

)

select payments.*

from payments
inner join orders
    on payments.order_id = orders.order_id

where payments.payment_id is not null
    -- a null method fails the IN check too
    and payments.payment_method in ('{{ var("payment_methods") | join("', '") }}')
    and payments.amount >= 0
