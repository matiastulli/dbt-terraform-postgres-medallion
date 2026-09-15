with source as (

    select * from {{ source('jaffle_shop', 'raw_payments') }}

),

renamed as (

    select
        id as payment_id,
        order_id,
        payment_method,
        -- raw amount is stored in cents (macro lives in macros/cents_to_dollars.sql)
        {{ cents_to_dollars('amount') }} as amount

    from source

)

select * from renamed
