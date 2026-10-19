with source as (
    select * from {{ ref('mean_median_income_US') }}
)

select
    lpad(cast(Zip_Code as varchar), 5, '0') as zip_code,

    round(avg(Median), 2) as median_household_income,
    round(avg(Mean), 2) as mean_household_income,

    any_value(State_ab) as state_code,
    any_value(City) as city

from source
where Zip_Code is not null
group by
    lpad(cast(Zip_Code as varchar), 5, '0')