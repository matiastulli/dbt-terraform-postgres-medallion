{#
    Converts an integer amount in cents to a decimal amount in dollars.
    Usage: {{ cents_to_dollars('amount') }}  ->  (amount / 100.0)::numeric(16, 2)
#}
{% macro cents_to_dollars(column_name, scale=2) -%}
    ({{ column_name }} / 100.0)::numeric(16, {{ scale }})
{%- endmacro %}
