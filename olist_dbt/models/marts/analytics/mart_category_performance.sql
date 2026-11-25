-- Category performance with growth between the first 8 months of 2017 and 2018.
with items as (
    select *
    from {{ ref('fct_order_items') }}
    where order_status not in ('canceled', 'unavailable')
      and purchased_at >= '{{ var("analysis_start") }}'
      and purchased_at <  '{{ var("analysis_end") }}'
)

select
    category,
    count(distinct order_id)                                               as orders,
    sum(item_price)                                                        as revenue,
    sum(item_price) / sum(sum(item_price)) over ()                         as revenue_share,
    avg(item_price)                                                        as avg_item_price,
    avg(freight_value / nullif(item_price, 0))                             as avg_freight_ratio,
    avg(review_score)                                                      as avg_review_score,
    sum(item_price) filter (where purchased_at >= '2017-01-01' and purchased_at < '2017-09-01') as revenue_jan_aug_2017,
    sum(item_price) filter (where purchased_at >= '2018-01-01' and purchased_at < '2018-09-01') as revenue_jan_aug_2018,
    {{ safe_divide(
        "sum(item_price) filter (where purchased_at >= '2018-01-01' and purchased_at < '2018-09-01')",
        "sum(item_price) filter (where purchased_at >= '2017-01-01' and purchased_at < '2017-09-01')"
    ) }} - 1                                                               as growth_yoy,
    rank() over (order by sum(item_price) desc)                            as revenue_rank
from items
group by category
