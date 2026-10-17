with location_stats as (
    select
        zip_code,
        city,
        state_code,
        latitude,
        longitude,
        extracted_at,
        listing_id,
        count(*) over (partition by zip_code, city) as city_frequency
    from {{ ref('stg_zillow__listings') }}
    where zip_code is not null
),

ranked_locations as (
    select
        zip_code,
        city,
        state_code,
        round(avg(latitude) over (partition by zip_code), 6) as centroid_latitude,
        round(avg(longitude) over (partition by zip_code), 6) as centroid_longitude,
        count(distinct listing_id) over (partition by zip_code) as total_listings_count,
        min(extracted_at) over (partition by zip_code) as first_seen_at,
        max(extracted_at) over (partition by zip_code) as last_updated_at,
        row_number() over (
            partition by zip_code
            order by city_frequency desc, city asc
        ) as row_num
    from location_stats
),

census_income as (
    select * from {{ ref('stg_census__income') }}
)

select
    l.zip_code,
    l.city,
    l.state_code,
    l.centroid_latitude,
    l.centroid_longitude,
    l.total_listings_count,
    c.median_household_income,
    c.mean_household_income,

    l.first_seen_at,
    l.last_updated_at

from ranked_locations l
left join census_income c
    on l.zip_code = c.zip_code
where l.row_num = 1