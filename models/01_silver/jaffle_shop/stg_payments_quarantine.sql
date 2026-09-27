-- Payments that broke at least one rule in base/base_payments.sql, with the reason.
-- Kept out of stg_payments (and so out of gold) instead of failing the pipeline.

select *
from {{ ref('base_payments') }}
where quarantine_reason is not null
