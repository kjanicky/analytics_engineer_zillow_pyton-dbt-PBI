-- Grain: one row per valid listing per extraction run, with the previous snapshot's values.
-- Detects price changes we observed ourselves across runs.

with valid as (
    select * from {{ ref('int_listing_snapshots__validated') }}
    where is_valid_listing
)

select
    *,
    lag(price_usd)    over w                              as previous_price_usd,
    lag(extracted_at) over w                              as previous_extracted_at,
    price_usd - lag(price_usd) over w                     as observed_price_change_usd,
    coalesce(price_usd < lag(price_usd) over w, false)    as is_observed_price_cut,
    row_number() over w                                   as snapshot_sequence
from valid
window w as (partition by listing_id order by extracted_at)
