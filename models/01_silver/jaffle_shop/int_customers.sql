-- Valid customers. No rules yet, so it's a straight copy of stg_customers.
-- It exists so gold and the other int_ models always read int_ models:
-- a customer rule added here later reaches everything downstream.

select * from {{ ref('stg_customers') }}
