-- Grain: one row per real customer (customer_unique_id). Location is taken
-- from the customer's most recent order.
with orders as (
    select * from {{ ref('fct_orders') }}
    where order_status not in ('canceled', 'unavailable')
),

last_location as (
    select distinct on (customer_unique_id) customer_unique_id, customer_state
    from orders
    order by customer_unique_id, purchased_at desc
)

select
    o.customer_unique_id,
    l.customer_state                         as state,
    min(o.purchased_at)                      as first_order_at,
    max(o.purchased_at)                      as last_order_at,
    date_trunc('month', min(o.purchased_at))::date as cohort_month,
    count(*)                                 as order_count,
    sum(o.order_value)                       as lifetime_value,
    avg(o.review_score)                      as avg_review_score,
    count(*) > 1                             as is_repeat_customer
from orders o
join last_location l using (customer_unique_id)
group by o.customer_unique_id, l.customer_state
