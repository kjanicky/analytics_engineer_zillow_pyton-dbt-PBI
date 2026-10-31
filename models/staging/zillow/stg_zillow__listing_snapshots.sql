-- Grain: one row per listing per extraction run.
-- Only rename / cast / parse JSON here. No rows are filtered out (see int_listing_snapshots__validated).

with source as (
    select * from {{ source('zillow', 'listings') }}
),

renamed as (
    select
        -- keys
        {{ dbt_utils.generate_surrogate_key(['zpid', 'extracted_at']) }}      as listing_snapshot_sk,
        cast(zpid as bigint)                                                   as listing_id,
        payload->>'$.address.buildingId'                                       as building_id,

        -- lineage
        run_id,
        searched_city,
        cast(extracted_at as timestamp)                                        as extracted_at,

        -- location
        payload->>'$.address.streetAddress'                                    as street_address,
        payload->>'$.address.city'                                             as city,
        payload->>'$.address.state'                                            as state_code,
        payload->>'$.address.zipcode'                                          as zip_code,
        try_cast(payload->>'$.location.latitude'  as double)                   as latitude,
        try_cast(payload->>'$.location.longitude' as double)                   as longitude,

        -- property
        payload->>'$.propertyType'                                             as property_type,
        try_cast(payload->>'$.bedrooms'   as integer)                          as bedrooms_count,
        try_cast(payload->>'$.bathrooms'  as decimal(4, 1))                    as bathrooms_count,
        try_cast(payload->>'$.livingArea' as integer)                          as living_area_sqft,
        try_cast(payload->>'$.yearBuilt'  as integer)                          as year_built,
        try_cast(payload->>'$.lotSizeWithUnit.lotSize' as decimal(14, 2))     as lot_size,
        payload->>'$.lotSizeWithUnit.lotSizeUnit'                              as lot_size_unit,

        -- finance
        try_cast(payload->>'$.price.value'              as decimal(12, 2))     as price_usd,
        try_cast(payload->>'$.price.pricePerSquareFoot' as decimal(10, 2))     as price_per_sqft,
        try_cast(payload->>'$.price.priceChange'        as decimal(12, 2))     as price_change_usd,
        try_cast(payload->>'$.estimates.zestimate'      as decimal(12, 2))     as zestimate_usd,
        try_cast(payload->>'$.estimates.rentZestimate'  as decimal(12, 2))     as rent_zestimate_usd,
        try_cast(payload->>'$.taxAssessment.taxAssessedValue'  as decimal(12, 2)) as tax_assessed_value_usd,
        try_cast(payload->>'$.taxAssessment.taxAssessmentYear' as integer)        as tax_assessment_year,

        -- dates
        epoch_ms(try_cast(payload->>'$.listingDateTimeOnZillow' as bigint))   as listed_at,
        epoch_ms(try_cast(payload->>'$.price.changedDate'       as bigint))   as price_changed_at,
        try_cast(payload->>'$.daysOnZillow' as integer)                        as days_on_zillow,

        -- listing channel
        coalesce(try_cast(payload->>'$.listing.listingSubType.isFSBO'      as boolean), false) as is_fsbo,
        coalesce(try_cast(payload->>'$.listing.listingSubType.isFSBA'      as boolean), false) as is_fsba,
        coalesce(try_cast(payload->>'$.listing.listingSubType.isBankOwned' as boolean), false) as is_bank_owned,
        coalesce(try_cast(payload->>'$.listing.listingSubType.isOpenHouse' as boolean), false) as has_open_house,
        payload->>'$.propertyDisplayRules.mls.brokerName'                      as broker_name,

        -- marketing
        coalesce(try_cast(payload->>'$.hasFloorPlan'     as boolean), false)   as has_floor_plan,
        coalesce(try_cast(payload->>'$.media.hasVRModel' as boolean), false)   as has_vr_model,
        coalesce(try_cast(payload->>'$.isFeatured'       as boolean), false)   as is_featured,
        payload->>'$.media.propertyPhotoLinks.mediumSizeLink'                  as primary_photo_url,
        payload->>'$.hdpView.hdpUrl'                                           as zillow_detail_url
    from source
)

select * from renamed
