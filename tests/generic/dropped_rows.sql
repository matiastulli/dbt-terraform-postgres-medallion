{#
    Custom generic test: returns the rows of `upstream` whose key never reached `model`.
    Meant for int_ models, which drop invalid stg_ rows. Each returned row is a
    dropped row, so with store_failures they land in dev_audit for inspection.
    Usage, on the key column of an int_ model:
        - dropped_rows:
            arguments:
              upstream: ref('stg_orders')
    A null key upstream counts as dropped too, since int_ models drop null ids.
    The test has two parents (stg_ and int_), so selecting the stg_ model
    (dbt build --select stg_orders) runs it as well.
#}
{% test dropped_rows(model, column_name, upstream) %}

select upstream.*

from {{ upstream }} as upstream
left join {{ model }} as kept
    on upstream.{{ column_name }} = kept.{{ column_name }}

where kept.{{ column_name }} is null

{% endtest %}
