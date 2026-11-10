-- Staging: raw orders renamed, one row per source row. No filtering here;
-- invalid orders are dropped in int_orders.

with source as (

    select * from {{ source('jaffle_shop', 'raw_orders') }}

),

renamed as (

    select
        id as order_id,
        user_id as customer_id,
        order_date,
        status

    from source

)

select * from renamed
