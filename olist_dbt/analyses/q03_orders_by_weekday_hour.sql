-- Q3. When do customers order? (heatmap weekday x hour, for campaign timing)
select
    extract(isodow from purchased_at)::int as iso_weekday,
    extract(hour from purchased_at)::int   as hour,
    count(*)                               as orders
from {{ ref('fct_orders') }}
where purchased_at >= '{{ var("analysis_start") }}' and purchased_at < '{{ var("analysis_end") }}'
group by 1, 2
order by 1, 2
