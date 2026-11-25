-- The source has 555 orders with several reviews and some review_ids shared
-- by several orders. We keep one review per order: the most recently answered.
with ranked as (
    select
        review_id,
        order_id,
        review_score::int                        as review_score,
        nullif(trim(review_comment_message), '') as review_comment,
        review_creation_date::timestamp          as review_created_at,
        review_answer_timestamp::timestamp       as review_answered_at,
        row_number() over (
            partition by order_id
            order by review_answer_timestamp::timestamp desc, review_id
        ) as rn
    from {{ source('olist', 'order_reviews') }}
)

select
    review_id,
    order_id,
    review_score,
    review_comment,
    review_comment is not null as has_comment,
    review_created_at,
    review_answered_at
from ranked
where rn = 1
