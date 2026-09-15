with source as (

    select * from {{ source('jaffle_shop', 'raw_payments') }}

),

renamed as (

    select
        id as payment_id,
        order_id,
        payment_method,
        -- raw amount is stored in cents
        (amount / 100.0)::numeric(16, 2) as amount

    from source

)

select * from renamed
