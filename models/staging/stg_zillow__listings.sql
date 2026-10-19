with source as (
    select * from {{ source('main', 'raw_zillow_listings') }}
),

renamed as (
    select
        -- ids
        cast(zpid as bigint) as listing_id,
        cast("address.buildingId" as varchar) as building_id,

        -- metadata
        cast(searched_city as varchar) as searched_city,
        cast(extracted_at as timestamp) as extracted_at,

        -- location info
        cast("address.streetAddress" as varchar) as street_address,
        cast("address.city" as varchar) as city,
        cast("address.state" as varchar) as state_code,
        cast("address.zipcode" as varchar) as zip_code,
        cast("location.latitude" as double) as latitude,
        cast("location.longitude" as double) as longitude,

        -- property characteristics
        cast(propertyType as varchar) as property_type,
        cast(bedrooms as integer) as bedrooms_count,
        cast(bathrooms as numeric(4, 1)) as bathrooms_count,
        cast(livingArea as integer) as living_area_sqft,
        cast(yearBuilt as integer) as year_built,
        cast("lotSizeWithUnit.lotSize" as numeric(12, 2)) as lot_size,
        cast("lotSizeWithUnit.lotSizeUnit" as varchar) as lot_size_unit,

        -- finance
        cast("price.value" as numeric(12, 2)) as price_usd,
        cast("price.pricePerSquareFoot" as numeric(10, 2)) as price_per_sqft,
        cast("estimates.zestimate" as numeric(12, 2)) as zestimate_usd,
        cast("estimates.rentZestimate" as numeric(12, 2)) as rent_zestimate_usd,
        cast("taxAssessment.taxAssessedValue" as numeric(12, 2)) as tax_assessed_value_usd,
        cast("taxAssessment.taxAssessmentYear" as integer) as tax_assessment_year,
        cast("price.priceChange" as numeric(12, 2)) as price_change_usd,

        -- listing dates
        epoch_ms(cast("listingDateTimeOnZillow" as bigint)) as listed_at,
        epoch_ms(cast("price.changedDate" as bigint)) as price_changed_at,
        cast(daysOnZillow as integer) as days_on_zillow,

        -- listing channel types
        coalesce(cast("listing.listingSubType.isFSBO" as boolean), false) as is_fsbo,
        coalesce(cast("listing.listingSubType.isFSBA" as boolean), false) as is_fsba,
        coalesce(cast("listing.listingSubType.isBankOwned" as boolean), false) as is_bank_owned,
        cast("propertyDisplayRules.mls.brokerName" as varchar) as broker_name,

        -- marketing quality and features from listing
        coalesce(cast(hasFloorPlan as boolean), false) as has_floor_plan,
        coalesce(cast("media.hasVRModel" as boolean), false) as has_vr_model,
        coalesce(cast("listing.listingSubType.isOpenHouse" as boolean), false) as has_open_house,
        cast(isFeatured as boolean) as is_featured,

        -- photos
        cast("media.propertyPhotoLinks.mediumSizeLink" as varchar) as primary_photo_url,
        cast("hdpView.hdpUrl" as varchar) as zillow_detail_url

    from source
    where zpid is not null
    and "price.value" is not null and "price.value" > 0
      and listingDateTimeOnZillow is not null
)

select * from renamed