select
    seller_id,
    lpad(seller_zip_code_prefix, 5, '0')  as zip_prefix,
    initcap(seller_city)                  as city,
    upper(seller_state)                   as state
from {{ source('olist', 'sellers') }}
