select
    mql_id,
    first_contact_date::date             as first_contact_date,
    landing_page_id,
    coalesce(nullif(origin, ''), 'unknown') as origin
from {{ source('olist', 'marketing_qualified_leads') }}
