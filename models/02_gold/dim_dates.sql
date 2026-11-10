-- Grain: one row per calendar day, from var('dim_dates_start') to the day
-- before var('dim_dates_end'). Built from nothing: date_spine generates the
-- days, so this dimension doesn't depend on any source.
-- If orders arrive outside the range, the relationships tests on the facts
-- fail: widen the vars in dbt_project.yml.

with days as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('dim_dates_start') ~ "' as date)",
        end_date="cast('" ~ var('dim_dates_end') ~ "' as date)"
    ) }}

),

final as (

    select
        cast(date_day as date) as date_day,
        extract(year from date_day)::int as year,
        extract(quarter from date_day)::int as quarter,
        extract(month from date_day)::int as month,
        to_char(date_day, 'FMMonth') as month_name,
        extract(day from date_day)::int as day_of_month,
        -- ISO: Monday = 1 ... Sunday = 7
        extract(isodow from date_day)::int as day_of_week,
        to_char(date_day, 'FMDay') as day_name,
        extract(isodow from date_day) in (6, 7) as is_weekend

    from days

)

select * from final
