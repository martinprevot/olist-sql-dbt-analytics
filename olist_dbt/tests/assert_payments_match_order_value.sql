-- Amount paid should equal items + freight. A handful of orders differ
-- (vouchers, rounding, installment fees); fail if more than 1 % do.
with check_orders as (
    select abs(amount_paid - order_value) > 1 as mismatch
    from {{ ref('fct_orders') }}
    where amount_paid is not null and order_value is not null
)
select avg(mismatch::int) as mismatch_rate
from check_orders
having avg(mismatch::int) > 0.01
