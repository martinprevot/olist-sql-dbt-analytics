-- Monthly acquisition cohorts: share of each cohort that orders again
-- N months after its first purchase.
with customer_months as (
    select distinct
        o.customer_unique_id,
        c.cohort_month,
        o.purchase_month
    from {{ ref('fct_orders') }} o
    join {{ ref('dim_customers') }} c using (customer_unique_id)
    where o.order_status not in ('canceled', 'unavailable')
),

cohort_size as (
    select cohort_month, count(distinct customer_unique_id) as cohort_customers
    from customer_months
    group by 1
),

activity as (
    select
        cohort_month,
        ((extract(year from age(purchase_month, cohort_month)) * 12)
          + extract(month from age(purchase_month, cohort_month)))::int as months_since_first,
        count(distinct customer_unique_id) as active_customers
    from customer_months
    group by 1, 2
)

select
    a.cohort_month,
    s.cohort_customers,
    a.months_since_first,
    a.active_customers,
    {{ safe_divide('a.active_customers', 's.cohort_customers') }} as retention_rate
from activity a
join cohort_size s using (cohort_month)
where a.cohort_month >= '{{ var("analysis_start") }}'
  and a.cohort_month <  '{{ var("analysis_end") }}'
order by 1, 3
