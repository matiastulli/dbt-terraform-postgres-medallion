{#
    on-run-end hook (dbt_project.yml): appends one row per executed node to
    run_log in the audit schema (dev_audit). Append-only: every run adds rows,
    none are updated, so history (failures per run, durations) is derived by
    querying it. The primary key makes a double-logged run fail loudly instead
    of double-counting. The table is created on first use; the schema itself is
    owned by Terraform, so `terraform apply` must run before the first dbt run.
    `results` holds one entry per node dbt ran in this invocation.
#}
{% macro log_run_results(results) %}

    {%- if execute -%}
    {#- Same schema name the data_tests +schema: audit config resolves to -#}
    {%- set run_log = adapter.quote(generate_schema_name('audit')) ~ '.run_log' -%}

    create table if not exists {{ run_log }} (
        invocation_id    text not null,
        run_started_at   timestamptz not null,
        unique_id        text not null,
        resource_type    text not null,
        status           text not null,
        rows_affected    bigint,
        failures         bigint,
        execution_time_s numeric(10, 3),
        message          text,
        primary key (invocation_id, unique_id)
    );

    {%- if results %}

    insert into {{ run_log }} values
    {%- for result in results %}
    {#- Missing values are stored as null, never as 0 or ''. rows_affected only
        means something for models and seeds: Postgres reports -1 (unknown) for
        CREATE VIEW, and a test's value is just the row of its count query. -#}
    {%- set rows_affected = (result.adapter_response or {}).get('rows_affected') -%}
    {%- if result.node.resource_type not in ('model', 'seed') or rows_affected == -1 -%}
        {%- set rows_affected = none -%}
    {%- endif -%}
    (
        {{ sql_literal(invocation_id) }},
        {{ sql_literal(run_started_at) }},
        {{ sql_literal(result.node.unique_id) }},
        {{ sql_literal(result.node.resource_type) }},
        {{ sql_literal(result.status) }},
        {{ 'null' if rows_affected is none else rows_affected }},
        {{ 'null' if result.failures is none else result.failures }},
        {{ result.execution_time | round(3) }},
        {{ sql_literal(result.message) }}
    ){{ "," if not loop.last }}
    {%- endfor %};

    {%- endif -%}
    {%- endif -%}

{% endmacro %}


{#- A value as a quoted SQL string literal (single quotes doubled), or null. -#}
{% macro sql_literal(value) -%}
    {{ 'null' if value is none else "'" ~ (value | string | replace("'", "''")) ~ "'" }}
{%- endmacro %}
