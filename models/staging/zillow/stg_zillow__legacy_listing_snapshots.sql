-- Grain: one row per listing per extraction run (v1 flattened loader).
-- Output columns are identical to stg_zillow__listing_snapshots so both can be unioned by name.
-- If a column is missing in your legacy table, replace that line with: null as <column_name>

{{ config(enabled=var('include_legacy', true)) }}

with source as (
    select * from {{ source('zillow', 'listings_legacy') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['zpid', 'extracted_at']) }}    as listing_snapshot_sk,
    cast(zpid as bigint)                                                 as listing_id,
    cast("address.buildingId" as varchar)                                as building_id,
    'legacy'                                                             as run_id,
    cast(searched_city as varchar)                                       as searched_city,
    cast(extracted_at as timestamp)                                      as extracted_at,
    cast("address.streetAddress" as varchar)                             as street_address,
    cast("address.city" as varchar)                                      as city,
    cast("address.state" as varchar)                                     as state_code,
    cast("address.zipcode" as varchar)                                   as zip_code,
    try_cast("location.latitude" as double)                              as latitude,
    try_cast("location.longitude" as double)                             as longitude,
    cast(propertyType as varchar)                                        as property_type,
    try_cast(bedrooms as integer)                                        as bedrooms_count,
    try_cast(bathrooms as decimal(4, 1))                                 as bathrooms_count,
    try_cast(livingArea as integer)                                      as living_area_sqft,
    try_cast(yearBuilt as integer)                                       as year_built,
    try_cast("lotSizeWithUnit.lotSize" as decimal(14, 2))                as lot_size,
    cast("lotSizeWithUnit.lotSizeUnit" as varchar)                       as lot_size_unit,
    try_cast("price.value" as decimal(12, 2))                            as price_usd,
    try_cast("price.pricePerSquareFoot" as decimal(10, 2))               as price_per_sqft,
    try_cast("price.priceChange" as decimal(12, 2))                      as price_change_usd,
    try_cast("estimates.zestimate" as decimal(12, 2))                    as zestimate_usd,
    try_cast("estimates.rentZestimate" as decimal(12, 2))                as rent_zestimate_usd,
    try_cast("taxAssessment.taxAssessedValue" as decimal(12, 2))         as tax_assessed_value_usd,
    try_cast("taxAssessment.taxAssessmentYear" as integer)               as tax_assessment_year,
    epoch_ms(try_cast(listingDateTimeOnZillow as bigint))                as listed_at,
    epoch_ms(try_cast("price.changedDate" as bigint))                    as price_changed_at,
    try_cast(daysOnZillow as integer)                                    as days_on_zillow,
    coalesce(try_cast("listing.listingSubType.isFSBO" as boolean), false)       as is_fsbo,
    coalesce(try_cast("listing.listingSubType.isFSBA" as boolean), false)       as is_fsba,
    coalesce(try_cast("listing.listingSubType.isBankOwned" as boolean), false)  as is_bank_owned,
    coalesce(try_cast("listing.listingSubType.isOpenHouse" as boolean), false)  as has_open_house,
    cast("propertyDisplayRules.mls.brokerName" as varchar)               as broker_name,
    coalesce(try_cast(hasFloorPlan as boolean), false)                   as has_floor_plan,
    coalesce(try_cast("media.hasVRModel" as boolean), false)             as has_vr_model,
    coalesce(try_cast(isFeatured as boolean), false)                     as is_featured,
    cast("media.propertyPhotoLinks.mediumSizeLink" as varchar)           as primary_photo_url,
    cast("hdpView.hdpUrl" as varchar)                                    as zillow_detail_url
from source
