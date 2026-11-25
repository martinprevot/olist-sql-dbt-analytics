-- Q1. How concentrated is revenue? Share of sellers needed to reach 50 % / 80 % of revenue.
with ranked as (
    select
        seller_id,
        revenue,
        row_number() over (order by revenue desc)                         as seller_rank,
        count(*) over ()                                                   as n_sellers,
        sum(revenue) over (order by revenue desc) / sum(revenue) over ()   as cum_share
    from {{ ref('mart_seller_scorecard') }}
)
select
    threshold,
    min(seller_rank)                                     as sellers_needed,
    round(min(seller_rank)::numeric / max(n_sellers), 4) as share_of_sellers
from ranked
cross join (values (0.5), (0.8), (0.95)) as t(threshold)
where cum_share >= threshold
group by threshold
order by threshold
