-- Grain: one row per listing per extraction run, across both loader versions.

select *, 'api_v2' as source_system
from {{ ref('stg_zillow__listing_snapshots') }}

{% if var('include_legacy', true) %}
union all by name

select *, 'legacy' as source_system
from {{ ref('stg_zillow__legacy_listing_snapshots') }}
{% endif %}
