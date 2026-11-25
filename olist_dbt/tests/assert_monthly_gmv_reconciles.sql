-- The KPI mart must reconcile with the fact table to the cent.
with mart as (select sum(gmv) as gmv from {{ ref('mart_monthly_kpis') }}),
fact as (
    select sum(order_value) as gmv
    from {{ ref('fct_orders') }}
    where order_status not in ('canceled', 'unavailable')
      and purchased_at >= '{{ var("analysis_start") }}'
      and purchased_at <  '{{ var("analysis_end") }}'
)
select mart.gmv, fact.gmv from mart, fact where abs(mart.gmv - fact.gmv) > 0.01
