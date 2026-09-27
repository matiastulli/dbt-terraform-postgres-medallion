{#
    Custom generic test: passes when the model has no rows.
    Meant for quarantine models with severity: warn, so bad rows are
    reported on every build without blocking downstream models.
#}
{% test is_empty(model) %}

select * from {{ model }}

{% endtest %}
