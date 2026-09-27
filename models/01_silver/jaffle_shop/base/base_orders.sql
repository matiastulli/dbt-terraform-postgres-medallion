-- Rename/cast raw orders and flag every row that breaks a rule.
-- Ephemeral: compiled as a CTE into stg_orders (valid rows) and
-- stg_orders_quarantine (invalid rows), so the rules live in one place.

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

),

customers as (

    select customer_id from {{ ref('stg_customers') }}

),

validated as (

    select
        renamed.*,
        -- Every broken rule, comma-separated; null when the row is valid.
        -- concat_ws skips nulls, so a valid row yields '' -> null.
        nullif(concat_ws(', ',
            case when renamed.order_id is null then 'missing_order_id' end,
            case when customers.customer_id is null then 'unknown_customer' end,
            case when renamed.order_date is null then 'missing_order_date' end,
            case when renamed.status is null
                or renamed.status not in ('{{ var("order_statuses") | join("', '") }}')
                then 'invalid_status' end
        ), '') as quarantine_reason

    from renamed
    left join customers
        on renamed.customer_id = customers.customer_id

)

select * from validated
