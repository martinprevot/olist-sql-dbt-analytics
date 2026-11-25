with products as (
    select * from {{ source('olist', 'products') }}
),

translation as (
    select product_category_name, product_category_name_english
    from {{ source('olist', 'category_translation') }}
)

select
    p.product_id,
    coalesce(p.product_category_name, 'unknown') as category_pt,
    -- Two categories are missing from Olist's translation file.
    coalesce(
        t.product_category_name_english,
        case p.product_category_name
            when 'pc_gamer' then 'pc_gamer'
            when 'portateis_cozinha_e_preparadores_de_alimentos' then 'kitchen_portables_and_food_preparers'
        end,
        'unknown'
    )                                         as category,
    p.product_name_lenght::int                as name_length,          -- sic: typo in source
    p.product_description_lenght::int         as description_length,   -- sic: typo in source
    p.product_photos_qty::int                 as photos_qty,
    p.product_weight_g::numeric               as weight_g,
    p.product_length_cm::numeric * p.product_height_cm::numeric * p.product_width_cm::numeric
                                              as volume_cm3
from products p
left join translation t using (product_category_name)
