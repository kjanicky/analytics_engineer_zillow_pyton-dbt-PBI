select
    listing_id,
    building_id,
    street_address,
    zip_code,
    latitude,
    longitude,
    property_type,
    bedrooms_count,
    bathrooms_count,
    living_area_sqft,
    lot_size,
    lot_size_unit,
    year_built,
    has_floor_plan,
    has_vr_model,
    primary_photo_url,
    zillow_detail_url,
    min(extracted_at) over (partition by listing_id) as first_seen_at,
    max(extracted_at) over (partition by listing_id) as last_updated_at
from {{ ref('stg_zillow__listings') }}
qualify row_number() over (partition by listing_id order by extracted_at desc) = 1