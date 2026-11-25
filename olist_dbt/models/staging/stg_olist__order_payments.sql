select
    order_id,
    payment_sequential::int            as payment_seq,
    payment_type,
    payment_installments::int          as installments,
    payment_value::numeric(10, 2)      as payment_value
from {{ source('olist', 'order_payments') }}
