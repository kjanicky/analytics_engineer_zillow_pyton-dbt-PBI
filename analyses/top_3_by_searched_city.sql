with ranking as (select l.city, fct.listing_id ,p.street_address, p.living_area_sqft,
dense_rank() over(partition by l.city order by fct.price_usd desc) as rank_in_city

from fct_listings fct
left join dim_properties p
on p.listing_id = fct.listing_id
left join dim_locations l
on l.zip_code = fct.zip_code)

select * from ranking where rank_in_city <=3