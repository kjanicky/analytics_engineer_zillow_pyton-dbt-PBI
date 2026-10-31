-- Grain: one row per zip code.
-- The seed is at census-tract level; tract medians are averaged, so the median is an approximation.

with source as (
    select * from {{ ref('mean_median_income_US') }}
)

select
    lpad(cast(Zip_Code as varchar), 5, '0')  as zip_code,
    round(avg(Median), 2)                     as approx_median_household_income,
    round(avg(Mean), 2)                       as mean_household_income,
    min(State_ab)                             as state_code,
    min(City)                                 as city
from source
where Zip_Code is not null
group by 1
