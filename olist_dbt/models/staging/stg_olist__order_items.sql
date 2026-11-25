select
    order_id,
    order_item_id::int                as order_item_seq,
    product_id,
    seller_id,
    shipping_limit_date::timestamp    as shipping_limit_at,
    price::numeric(10, 2)             as item_price,
    freight_value::numeric(10, 2)     as freight_value
from {{ source('olist', 'order_items') }}
