-- customer_id is generated per order by Olist; customer_unique_id is the
-- real person. Every customer analysis must use customer_unique_id.
select
    customer_id,
    customer_unique_id,
    lpad(customer_zip_code_prefix, 5, '0')  as zip_prefix,
    initcap(customer_city)                  as city,
    upper(customer_state)                   as state
from {{ source('olist', 'customers') }}
