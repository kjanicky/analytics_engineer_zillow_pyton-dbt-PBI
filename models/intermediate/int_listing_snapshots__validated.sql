-- Grain: one row per listing per extraction run.
-- Business rules live here. Invalid rows are FLAGGED, not deleted, so data quality stays measurable.

with snapshots as (
    select * from {{ ref('int_listing_snapshots__unioned') }}
)

select
    *,
    case
        when lot_size_unit = 'acres' then round(lot_size * 43560, 2)
        when lot_size_unit = 'sqft'  then lot_size
    end                                                                 as lot_size_sqft,
    case
        when year_built between 1800 and extract(year from extracted_at) then year_built
    end                                                                 as year_built_clean,
    coalesce(price_usd > 0 and listed_at is not null and zip_code is not null, false)
                                                                        as is_valid_listing
from snapshots
