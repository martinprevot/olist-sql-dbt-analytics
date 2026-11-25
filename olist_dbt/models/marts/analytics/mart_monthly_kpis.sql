-- Monthly business KPIs with month-over-month growth and rolling averages.
with monthly as (
    select
        purchase_month                                             as month,
        count(*)                                                   as orders,
        count(distinct customer_unique_id)                         as active_customers,
        count(*) filter (where is_first_order)                     as new_customers,
        sum(order_value)                                           as gmv,
        avg(order_value)                                           as avg_order_value,
        avg(review_score)                                          as avg_review_score,
        avg(is_late::int) filter (where is_delivered)              as late_delivery_rate,
        avg(delivery_days) filter (where is_delivered)             as avg_delivery_days
    from {{ ref('fct_orders') }}
    where order_status not in ('canceled', 'unavailable')
      and purchased_at >= '{{ var("analysis_start") }}'
      and purchased_at <  '{{ var("analysis_end") }}'
    group by 1
)

select
    *,
    {{ safe_divide('gmv - lag(gmv) over (order by month)', 'lag(gmv) over (order by month)') }} as gmv_mom_growth,
    avg(gmv) over (order by month rows between 2 preceding and current row)                  as gmv_rolling_3m,
    sum(gmv) over (order by month)                                                            as gmv_cumulative,
    {{ safe_divide('new_customers', 'active_customers') }}                                    as new_customer_share
from monthly
order by month
