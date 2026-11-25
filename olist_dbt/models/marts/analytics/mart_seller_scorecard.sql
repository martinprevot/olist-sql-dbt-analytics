-- Seller scorecard: volume, quality and ranking, for account management.
with seller_orders as (
    select
        i.seller_id,
        i.order_id,
        sum(i.item_price) as seller_revenue,
        max(o.review_score) as review_score,
        bool_or(o.is_late) as is_late
    from {{ ref('fct_order_items') }} i
    join {{ ref('fct_orders') }} o using (order_id)
    where o.order_status not in ('canceled', 'unavailable')
      and o.purchased_at >= '{{ var("analysis_start") }}'
      and o.purchased_at <  '{{ var("analysis_end") }}'
    group by 1, 2
),

agg as (
    select
        seller_id,
        count(*)                       as orders,
        sum(seller_revenue)            as revenue,
        avg(review_score)              as avg_review_score,
        avg(is_late::int)              as late_rate,
        avg((review_score <= 2)::int)  as bad_review_rate
    from seller_orders
    group by seller_id
)

select
    a.*,
    s.state,
    s.acquired_via_marketing,
    dense_rank() over (order by a.revenue desc)                   as revenue_rank,
    sum(a.revenue) over (order by a.revenue desc
                         rows between unbounded preceding and current row)
      / sum(a.revenue) over ()                                     as cumulative_revenue_share,
    case
        when a.orders < 10 then 'Trop peu de volume'
        when a.avg_review_score >= 4.2 and a.late_rate <= 0.08 then 'Excellent'
        when a.avg_review_score < 3.5 or a.late_rate > 0.15   then 'À risque'
        else 'Standard'
    end                                                            as tier
from agg a
join {{ ref('dim_sellers') }} s using (seller_id)
