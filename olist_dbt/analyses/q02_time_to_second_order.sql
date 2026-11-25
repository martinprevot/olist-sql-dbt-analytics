-- Q2. For repeat customers, how long until the second order?
with seq as (
    select
        customer_unique_id,
        purchased_at,
        lead(purchased_at) over (partition by customer_unique_id order by purchased_at) as next_purchase_at,
        customer_order_seq
    from {{ ref('fct_orders') }}
    where order_status not in ('canceled', 'unavailable')
)
select
    count(*)                                                                         as repeat_customers,
    round(avg(extract(epoch from next_purchase_at - purchased_at) / 86400)::numeric, 1) as avg_days,
    percentile_cont(0.5) within group (order by next_purchase_at::date - purchased_at::date) as median_days,
    round(avg((next_purchase_at::date = purchased_at::date)::int)::numeric, 3)        as share_same_day,
    round(avg((next_purchase_at::date - purchased_at::date <= 30)::int)::numeric, 3)  as share_within_30_days
from seq
where customer_order_seq = 1 and next_purchase_at is not null
