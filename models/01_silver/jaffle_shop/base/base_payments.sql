-- Rename/cast raw payments and flag every row that breaks a rule.
-- Ephemeral: compiled as a CTE into stg_payments (valid rows) and
-- stg_payments_quarantine (invalid rows), so the rules live in one place.

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

),

-- Valid orders only: a payment for a quarantined order is quarantined too,
-- otherwise its revenue would reach silver but never gold.
orders as (

    select order_id from {{ ref('stg_orders') }}

),

validated as (

    select
        renamed.*,
        -- Every broken rule, comma-separated; null when the row is valid.
        -- concat_ws skips nulls, so a valid row yields '' -> null.
        nullif(concat_ws(', ',
            case when renamed.payment_id is null then 'missing_payment_id' end,
            case when orders.order_id is null then 'unknown_order' end,
            case when renamed.payment_method is null
                or renamed.payment_method not in ('{{ var("payment_methods") | join("', '") }}')
                then 'invalid_payment_method' end,
            case when renamed.amount is null or renamed.amount < 0 then 'invalid_amount' end
        ), '') as quarantine_reason

    from renamed
    left join orders
        on renamed.order_id = orders.order_id

)

select * from validated
