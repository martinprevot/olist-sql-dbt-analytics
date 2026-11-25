-- B2B funnel: marketing-qualified leads (sellers contacted via landing
-- pages) -> signed deals -> sellers who actually sold on the marketplace.
-- Caveat: deals run until Nov. 2018 but orders stop in Oct. 2018, so the
-- activation rate of recent deals is understated.
with leads as (
    select m.mql_id, m.origin, m.first_contact_date, d.seller_id, d.won_at
    from {{ ref('stg_olist__marketing_qualified_leads') }} m
    left join {{ ref('stg_olist__closed_deals') }} d using (mql_id)
),

seller_sales as (
    select seller_id, sum(item_price) as revenue, count(distinct order_id) as orders
    from {{ ref('fct_order_items') }}
    where order_status not in ('canceled', 'unavailable')
    group by seller_id
)

select
    case when grouping(l.origin) = 1 then 'TOTAL' else l.origin end as origin,
    count(*)                                                          as mqls,
    count(l.won_at)                                                   as deals_won,
    {{ safe_divide('count(l.won_at)', 'count(*)') }}                  as mql_to_deal_rate,
    percentile_cont(0.5) within group (
        order by l.won_at::date - l.first_contact_date
    ) filter (where l.won_at is not null)                             as median_days_to_close,
    count(s.seller_id)                                                as active_sellers,
    {{ safe_divide('count(s.seller_id)', 'count(l.won_at)') }}        as deal_activation_rate,
    coalesce(sum(s.revenue), 0)                                       as revenue_from_won_sellers
from leads l
left join seller_sales s using (seller_id)
group by rollup (l.origin)
order by mqls desc
