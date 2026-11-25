-- RFM segmentation. With 97 % one-time buyers, frequency is almost binary,
-- so it is used as a flag (1 vs 2+ orders) instead of a quintile.
{% set snapshot_date = var("analysis_end") %}

with base as (
    select
        customer_unique_id,
        state,
        '{{ snapshot_date }}'::date - last_order_at::date as recency_days,
        order_count                                       as frequency,
        lifetime_value                                    as monetary
    from {{ ref('dim_customers') }}
    where first_order_at < '{{ snapshot_date }}'
),

scored as (
    select
        *,
        6 - ntile(5) over (order by recency_days)  as r_score,   -- 5 = most recent
        ntile(5) over (order by monetary)          as m_score,   -- 5 = highest spend
        case when frequency > 1 then 2 else 1 end  as f_flag
    from base
)

select
    *,
    case
        when f_flag = 2 and r_score >= 4                   then 'Champions'
        when f_flag = 2                                    then 'Fidèles à réactiver'
        when r_score >= 4 and m_score >= 4                 then 'Nouveaux gros paniers'
        when r_score >= 4                                  then 'Nouveaux clients'
        when r_score <= 2 and m_score >= 4                 then 'Gros paniers perdus'
        when r_score <= 2                                  then 'Perdus'
        else 'À surveiller'
    end as segment
from scored
