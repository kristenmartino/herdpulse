{{ config(materialized = 'table') }}

/*
    The join backbone: one row per state × month combining the three monthly
    NASS series — production, per-cow yield, and average cow inventory.
    Built from the union of keys across all three inputs (they cover the same
    24 states + US, but a union keeps the grain honest if one series ever
    publishes ahead of the others), then left-joined per measure.
*/

with production as (
    select * from {{ ref('stg_nass__milk_production_monthly') }}
),

per_cow as (
    select * from {{ ref('stg_nass__milk_per_cow_monthly') }}
),

inventory as (
    select * from {{ ref('stg_nass__milk_cow_inventory_monthly') }}
),

month_keys as (
    select state_alpha, state_name, state_fips, month_date, month_num, year, is_us_total
    from production
    union
    select state_alpha, state_name, state_fips, month_date, month_num, year, is_us_total
    from per_cow
    union
    select state_alpha, state_name, state_fips, month_date, month_num, year, is_us_total
    from inventory
),

joined as (
    select
        -- Grain
        k.state_alpha,
        k.state_name,
        k.state_fips,
        k.month_date,
        k.month_num,
        k.year,
        k.is_us_total,

        -- Measures
        p.milk_production_lb,
        c.milk_per_cow_lb,
        i.milk_cow_head
    from month_keys k
    left join production p
        on  k.state_alpha = p.state_alpha
        and k.month_date  = p.month_date
    left join per_cow c
        on  k.state_alpha = c.state_alpha
        and k.month_date  = c.month_date
    left join inventory i
        on  k.state_alpha = i.state_alpha
        and k.month_date  = i.month_date
)

select * from joined
