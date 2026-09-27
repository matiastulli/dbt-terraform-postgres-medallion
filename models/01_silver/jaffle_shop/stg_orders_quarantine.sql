-- Orders that broke at least one rule in base/base_orders.sql, with the reason.
-- Kept out of stg_orders (and so out of gold) instead of failing the pipeline.

select *
from {{ ref('base_orders') }}
where quarantine_reason is not null
