-- Grain: one row per zip code.
-- A zip can map to several city names in the API; pick the most frequent (ties: most recent, then A-Z).

with valid as (
    select * from {{ ref('int_listing_snapshots__validated') }}
    where is_valid_listing
),

city_frequencies as (
    select
        zip_code,
        city,
        state_code,
        count(distinct listing_id) as city_listings_count,
        max(extracted_at)          as city_last_updated_at
    from valid
    group by zip_code, city, state_code
),

zip_centroids as (
    select
        zip_code,
        round(avg(latitude), 6)  as listings_avg_latitude,
        round(avg(longitude), 6) as listings_avg_longitude,
        min(extracted_at)        as first_seen_at,
        max(extracted_at)        as last_updated_at
    from valid
    group by zip_code
),

ranked as (
    select
        cf.zip_code,
        cf.city,
        cf.state_code,
        zc.listings_avg_latitude,
        zc.listings_avg_longitude,
        zc.first_seen_at,
        zc.last_updated_at,
        row_number() over (
            partition by cf.zip_code
            order by cf.city_listings_count desc, cf.city_last_updated_at desc, cf.city asc
        ) as rn
    from city_frequencies cf
    join zip_centroids zc on cf.zip_code = zc.zip_code
)

select * exclude (rn)
from ranked
where rn = 1
