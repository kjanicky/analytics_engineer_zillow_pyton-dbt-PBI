-- Grain: one row per calendar day, covering every date present in the facts.

with date_values as (

    select cast(listed_at as date) as date_day
    from {{ ref('int_listing_price_history') }}
    where listed_at is not null

    union all

    select cast(extracted_at as date) as date_day
    from {{ ref('int_listing_price_history') }}
    where extracted_at is not null

),

bounds as (
    select
        min(date_day) as start_date,
        max(date_day) as end_date
    from date_values
),

spine as (
    select cast(unnest(generate_series(
        cast(start_date as timestamp),
        cast(end_date as timestamp),
        interval 1 day
    )) as date) as date_day
    from bounds
)

select
    date_day,
    extract(year from date_day)              as year,
    extract(quarter from date_day)           as quarter,
    extract(month from date_day)             as month,
    strftime(date_day, '%B')                 as month_name,
    strftime(date_day, '%Y-%m')              as year_month,
    extract(week from date_day)              as iso_week,
    strftime(date_day, '%A')                 as day_name,
    extract(isodow from date_day)            as day_of_week_iso,
    extract(isodow from date_day) in (6, 7)  as is_weekend
from spine
