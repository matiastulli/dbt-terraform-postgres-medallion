-- Valid orders only: the business rules that decide which orders reach gold.
-- Drops orders with a null id or date, a status not in var('order_statuses'),
-- or a customer that isn't in int_customers.

with orders as (

    select * from {{ ref('stg_orders') }}

),

customers as (

    select customer_id from {{ ref('int_customers') }}

)

select orders.*

from orders
-- inner join drops orders whose customer is null or unknown
inner join customers
    on orders.customer_id = customers.customer_id

where orders.order_id is not null
    and orders.order_date is not null
    -- a null status fails the IN check too
    and orders.status in ('{{ var("order_statuses") | join("', '") }}')
