-- Delivery promise vs reality, and its effect on customer satisfaction.
with delivered as (
    select *
    from {{ ref('fct_orders') }}
    where is_delivered
      and purchased_at >= '{{ var("analysis_start") }}'
      and purchased_at <  '{{ var("analysis_end") }}'
)

select
    coalesce(customer_state, 'TOTAL')                                        as customer_state,
    case
        when grouping(delay_bucket) = 1 then 'ALL'
        else delay_bucket
    end                                                                      as delay_bucket,
    count(*)                                                                 as orders,
    round(avg(delivery_days)::numeric, 1)                                    as avg_delivery_days,
    round(avg(promised_days)::numeric, 1)                                    as avg_promised_days,
    round(avg(is_late::int)::numeric, 4)                                     as late_rate,
    round(avg(review_score)::numeric, 2)                                     as avg_review_score,
    round(avg((review_score <= 2)::int)::numeric, 4)                         as bad_review_rate
from (
    select
        *,
        case
            when days_vs_estimate <= -10 then '1. 10+ jours d''avance'
            when days_vs_estimate <= 0   then '2. À l''heure (0-9 j d''avance)'
            when days_vs_estimate <= 3   then '3. 1-3 jours de retard'
            when days_vs_estimate <= 7   then '4. 4-7 jours de retard'
            else                              '5. 8+ jours de retard'
        end as delay_bucket
    from delivered
) d
group by grouping sets ((customer_state), (delay_bucket), ())
