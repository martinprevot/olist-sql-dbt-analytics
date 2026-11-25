select
    mql_id,
    seller_id,
    won_date::timestamp                          as won_at,
    coalesce(nullif(business_segment, ''), 'unknown') as business_segment,
    coalesce(nullif(lead_type, ''), 'unknown')        as lead_type,
    coalesce(nullif(business_type, ''), 'unknown')    as business_type,
    nullif(declared_monthly_revenue, '')::numeric     as declared_monthly_revenue
from {{ source('olist', 'closed_deals') }}
