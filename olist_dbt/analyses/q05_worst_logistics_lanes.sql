-- Q5. Which seller-state -> customer-state lanes concentrate late deliveries?
with lanes as (
    select distinct on (o.order_id)
        o.order_id, s.state as seller_state, o.customer_state, o.is_late, o.delivery_days, o.review_score
    from {{ ref('fct_orders') }} o
    join {{ ref('fct_order_items') }} i using (order_id)
    join {{ ref('dim_sellers') }} s using (seller_id)
    where o.is_delivered
    order by o.order_id, i.order_item_seq
)
select
    seller_state || ' -> ' || customer_state  as lane,
    count(*)                                  as orders,
    round(avg(delivery_days)::numeric, 1)     as avg_delivery_days,
    round(avg(is_late::int)::numeric, 3)      as late_rate,
    round(avg(review_score), 2)               as avg_review,
    sum(is_late::int)                         as late_orders
from lanes
group by 1
having count(*) >= 300
order by late_orders desc
limit 10
