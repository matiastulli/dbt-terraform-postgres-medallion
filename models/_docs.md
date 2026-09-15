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
