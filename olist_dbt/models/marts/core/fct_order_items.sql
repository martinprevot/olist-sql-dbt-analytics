select
    i.order_id,
    i.order_item_seq,
    i.product_id,
    i.seller_id,
    o.customer_unique_id,
    o.order_status,
    o.purchased_at,
    o.purchase_month,
    p.category,
    i.item_price,
    i.freight_value,
    o.review_score,
    o.is_late
from {{ ref('stg_olist__order_items') }} i
join {{ ref('fct_orders') }} o using (order_id)
left join {{ ref('stg_olist__products') }} p using (product_id)
