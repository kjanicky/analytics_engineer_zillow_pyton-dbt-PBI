with raw_date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast(current_date - interval 5 year as date)",
        end_date="cast(current_date + interval 1 year as date)"
    ) }}
),

date_spine as (select cast(date_day as date) as date_day
                from raw_date_spine)
select
    date_day,
    extract(year from date_day) as year,
    extract(month from date_day) as month,
    strftime(date_day, '%B') as month_name,
    strftime(date_day, '%Y-%m') as year_month,
    extract(quarter from date_day) as quarter,
    extract(week from date_day) as iso_week,
    strftime(date_day, '%A') as day_name,
    extract(isodow from date_day) as day_of_week_iso,
    case
        when extract(isodow from date_day) in (6, 7) then true
        else false
    end as is_weekend
from date_spine