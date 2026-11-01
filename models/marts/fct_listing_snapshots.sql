-- Grain: one row per listing per extraction run (periodic snapshot fact).
-- Incremental: each run only processes snapshots newer than what is already loaded.

{{ config(
    materialized='incremental',
    unique_key='listing_snapshot_sk',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns'
) }}

select
    listing_snapshot_sk,
    listing_id,
    zip_code,
    source_system,
    cast(extracted_at as date)                                          as snapshot_date,
    cast(listed_at as date)                                             as listed_date,
    extracted_at                                                        as snapshot_at,
    price_usd,
    price_per_sqft,
    zestimate_usd,
    round((price_usd - zestimate_usd) / nullif(zestimate_usd, 0), 4)    as valuation_gap_pct,
    rent_zestimate_usd,
    round(price_usd / nullif(rent_zestimate_usd * 12, 0), 2)            as price_to_rent_ratio,
    tax_assessed_value_usd,
    price_change_usd,
    coalesce(price_change_usd < 0, false)                               as is_price_cut_reported,
    observed_price_change_usd,
    is_observed_price_cut,
    price_changed_at,
    days_on_zillow,
    extract(year from extracted_at) - year_built_clean                  as property_age_years,
    is_fsbo,
    is_fsba,
    is_bank_owned,
    has_open_house,
    is_featured,
    broker_name
from {{ ref('int_listing_price_history') }}
{% if is_incremental() %}
where extracted_at > (select max(snapshot_at) from {{ this }})
{% endif %}
