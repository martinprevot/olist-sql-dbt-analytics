-- Q4. Beyond lateness, what else is associated with bad reviews?
with delivered as (
    select *,
        case when seller_count > 1 then 'multi-vendeurs' else 'mono-vendeur' end as seller_mix,
        case
            when freight_value / nullif(items_value, 0) < 0.15 then '1. frais de port < 15 %'
            when freight_value / nullif(items_value, 0) < 0.30 then '2. 15-30 %'
            else '3. > 30 %'
        end as freight_ratio_bucket
    from {{ ref('fct_orders') }}
    where is_delivered and review_score is not null
)
select 'lateness' as driver, case when is_late then 'en retard' else 'à l''heure' end as value,
       count(*) as orders, round(avg(review_score), 2) as avg_review, round(avg((review_score <= 2)::int), 3) as bad_review_rate
from delivered group by 1, 2
union all
select 'seller_mix', seller_mix, count(*), round(avg(review_score), 2), round(avg((review_score <= 2)::int), 3)
from delivered group by 1, 2
union all
select 'freight_ratio', freight_ratio_bucket, count(*), round(avg(review_score), 2), round(avg((review_score <= 2)::int), 3)
from delivered group by 1, 2
order by driver, value
