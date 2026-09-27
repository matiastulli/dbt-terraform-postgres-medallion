{% docs order_status %}

Where the order is in its lifecycle:

| status | meaning |
|---|---|
| placed | Order placed, not yet shipped |
| shipped | Order shipped, not yet delivered |
| completed | Order received by the customer |
| return_pending | Customer has asked to return the order, not yet received back |
| returned | Order returned by the customer and received at the warehouse |

{% enddocs %}

{% docs amount_dollars %}
Amount in dollars, rounded to cents. Converted from the raw integer cents in `raw_payments`.
{% enddocs %}

{% docs quarantine_model %}
Rows from the source that broke at least one validation rule, with the reason.
They are kept out of silver's clean model (and so out of gold) instead of failing
the pipeline. The rules live in the matching ephemeral `base_*` model.
An `is_empty` test with `severity: warn` reports any rows here on every build.
{% enddocs %}

{% docs quarantine_reason %}
Comma-separated list of every rule the row broke, e.g. `unknown_order, invalid_amount`.

| reason | meaning |
|---|---|
| missing_order_id / missing_payment_id | Primary key is null |
| missing_order_date | Order has no date |
| unknown_customer | Customer isn't in `stg_customers` |
| unknown_order | Order isn't in `stg_orders` (missing, or quarantined itself) |
| invalid_status | Status is null or not in `var('order_statuses')` |
| invalid_payment_method | Method is null or not in `var('payment_methods')` |
| invalid_amount | Amount is null or negative |

{% enddocs %}
