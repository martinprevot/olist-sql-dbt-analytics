{{ config(indexes=[{'columns': ['order_id'], 'unique': true}, {'columns': ['customer_unique_id']}]) }}

with orders as (
    select o.*, c.customer_unique_id, c.state as customer_state
    from {{ ref('stg_olist__orders') }} o
    join {{ ref('stg_olist__customers') }} c using (customer_id)
),

enriched as (
    select
        o.order_id,
        o.customer_unique_id,
        o.customer_state,
        o.order_status,
        o.purchased_at,
        o.purchased_at::date                                    as purchase_date,
        date_trunc('month', o.purchased_at)::date               as purchase_month,
        o.approved_at,
        o.shipped_at,
        o.delivered_at,
        o.estimated_delivery_at,

        i.item_count,
        i.seller_count,
        i.items_value,
        i.freight_value,
        i.items_value + i.freight_value                         as order_value,
        p.amount_paid,
        p.main_payment_type,
        p.max_installments,
        p.used_voucher,
        r.review_score,
        r.has_comment                                           as review_has_comment,

        -- Delivery performance (delivered orders only)
        extract(epoch from o.delivered_at - o.purchased_at) / 86400.0          as delivery_days,
        extract(epoch from o.estimated_delivery_at - o.purchased_at) / 86400.0 as promised_days,
        o.delivered_at::date - o.estimated_delivery_at::date                   as days_vs_estimate,
        o.delivered_at::date > o.estimated_delivery_at::date                   as is_late,

        -- Customer journey
        row_number() over (partition by o.customer_unique_id order by o.purchased_at, o.order_id) as customer_order_seq
    from orders o
    left join {{ ref('int_order_items_aggregated') }}    i using (order_id)
    left join {{ ref('int_order_payments_aggregated') }} p using (order_id)
    left join {{ ref('stg_olist__order_reviews') }}      r using (order_id)
)

select
    *,
    customer_order_seq = 1 as is_first_order,
    order_status = 'delivered' and delivered_at is not null as is_delivered
from enriched
