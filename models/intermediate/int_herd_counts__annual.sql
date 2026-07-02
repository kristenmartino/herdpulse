{{ config(materialized = 'table') }}

/*
    Licensed herd counts joined to annual average cow inventory at state ×
    year grain, deriving cows-per-herd. Herd counts exist for ~48 states
    (+ US, + OTHER STATES); cow inventory only for the 24 major states + US —
    so cows_per_herd is NULL outside the majors, and the consolidation mart
    says so rather than pretending coverage it doesn't have.
*/

with herds as (
    select * from {{ ref('stg_nass__licensed_herds_annual') }}
),

milk_annual as (
    select * from {{ ref('int_state_milk__annual') }}
),

joined as (
    select
        -- Grain
        h.state_alpha,
        h.state_name,
        h.state_fips,
        h.year,
        h.is_us_total,
        h.is_other_states,

        -- Measures
        h.licensed_herds,
        m.avg_milk_cow_head,
        m.avg_milk_cow_head / nullif(h.licensed_herds, 0)            as cows_per_herd
    from herds h
    left join milk_annual m
        on  h.state_alpha = m.state_alpha
        and h.year        = m.year
)

select * from joined
