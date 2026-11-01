-- Grain: one row per calendar day, covering every date present in the facts.

with bounds as (
    select
        min(cast(least(listed_at, extracted_at) as date)) as start_date,
        max(cast(extracted_at as date))                   as end_date
    from {{ ref('int_listing_snapshots__validated') }}
    where is_valid_listing
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
