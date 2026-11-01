-- Grain: one row per listing (accumulating snapshot fact).
-- Milestones in a listing's life as observed by our own repeated extractions.

with history as (
    select * from {{ ref('int_listing_price_history') }}
),

latest_run as (
    select max(extracted_at) as max_extracted_at from history
),

per_listing as (
    select
        listing_id,
        min(extracted_at)                                              as first_seen_at,
        max(extracted_at)                                              as last_seen_at,
        count(*)                                                       as snapshots_count,
        arg_min(price_usd, extracted_at)                               as first_seen_price_usd,
        arg_max(price_usd, extracted_at)                               as latest_price_usd,
        min(case when is_observed_price_cut then extracted_at end)     as first_observed_cut_at,
        count(*) filter (where is_observed_price_cut)                  as price_cut_count
    from history
    group by listing_id
)

select
    p.listing_id,
    cast(p.first_seen_at as date)                                      as first_seen_date,
    cast(p.last_seen_at as date)                                       as last_seen_date,
    p.snapshots_count,
    p.first_seen_price_usd,
    p.latest_price_usd,
    p.first_observed_cut_at,
    date_diff('day', p.first_seen_at, p.first_observed_cut_at)         as days_to_first_cut,
    p.price_cut_count,
    round((p.latest_price_usd - p.first_seen_price_usd)
          / nullif(p.first_seen_price_usd, 0), 4)                      as total_price_change_pct,
    -- Not returned in the latest run = likely sold or withdrawn (proxy, see README)
    p.last_seen_at = lr.max_extracted_at                               as is_active
from per_listing p
cross join latest_run lr
