with city_frequencies as (
    select
        zip_code,
        city,
        state_code,
        count(distinct listing_id) as city_listings_count,
        max(extracted_at) as city_last_updated_at
    from {{ ref('stg_zillow__listings') }}
    where zip_code is not null
    group by zip_code,city,state_code
),

zip_centroids as (
    select
        zip_code,
        round(avg(latitude), 6) as centroid_latitude,
        round(avg(longitude), 6) as centroid_longitude,
        min(extracted_at) as first_seen_at,
        max(extracted_at) as last_updated_at
    from {{ ref('stg_zillow__listings') }}
    where zip_code is not null
    group by zip_code
),
ranked_locations as (
    select
        cf.zip_code,
        cf.state_code,
        cf.city,
        zc.centroid_latitude,
        zc.centroid_longitude,
        zc.first_seen_at,
        zc.last_updated_at,
        row_number() OVER(partition by cf.zip_code
        order by cf.city_listings_count desc, city_last_updated_at desc, cf.city asc) as rn
    from city_frequencies cf
    join zip_centroids zc on cf.zip_code = zc.zip_code),

census_income as (
   select * from {{ ref('stg_census__income') }}
)

select
    l.zip_code,
    l.city,
    l.state_code,
    l.centroid_latitude,
    l.centroid_longitude,
    c.median_household_income,
    c.mean_household_income,
    l.first_seen_at,
    l.last_updated_at

from ranked_locations l
left join census_income c
    on l.zip_code = c.zip_code
where l.rn = 1