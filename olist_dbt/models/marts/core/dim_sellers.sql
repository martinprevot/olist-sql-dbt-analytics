select
    s.seller_id,
    s.city,
    s.state,
    d.mql_id is not null       as acquired_via_marketing,
    m.origin                   as acquisition_origin,
    d.won_at                   as acquisition_won_at,
    d.business_segment
from {{ ref('stg_olist__sellers') }} s
left join {{ ref('stg_olist__closed_deals') }} d using (seller_id)
left join {{ ref('stg_olist__marketing_qualified_leads') }} m using (mql_id)
