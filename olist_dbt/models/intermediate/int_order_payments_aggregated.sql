with payments as (
    select
        *,
        -- The payment type carrying the largest amount is the "main" one.
        row_number() over (partition by order_id order by payment_value desc, payment_seq) as rn
    from {{ ref('stg_olist__order_payments') }}
)

select
    order_id,
    sum(payment_value)                                 as amount_paid,
    count(*)                                           as payment_count,
    max(installments)                                  as max_installments,
    max(payment_type) filter (where rn = 1)            as main_payment_type,
    bool_or(payment_type = 'voucher')                  as used_voucher
from payments
group by order_id
