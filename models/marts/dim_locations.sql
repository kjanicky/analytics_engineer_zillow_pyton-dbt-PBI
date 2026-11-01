-- Grain: one row per zip code.

select
    z.zip_code,
    z.city,
    z.state_code,
    z.listings_avg_latitude,
    z.listings_avg_longitude,
    c.approx_median_household_income,
    c.mean_household_income,
    z.first_seen_at,
    z.last_updated_at
from {{ ref('int_zip_codes__resolved') }} z
left join {{ ref('stg_census__zip_income') }} c
    on z.zip_code = c.zip_code
