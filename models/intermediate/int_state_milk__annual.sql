{{ config(materialized = 'table') }}

/*
    Annual rollup of the monthly backbone: one row per state × year.
    annual_milk_per_cow_lb is the sum of the twelve monthly lb/head values —
    the standard annual per-cow figure. is_complete_year guards the partial
    current year (the ranking mart and the national benchmark only consume
    complete years, so a five-month year can never masquerade as a low-yield
    one).
*/

with monthly as (
    select * from {{ ref('int_state_milk__monthly') }}
),

annual as (
    select
        -- Grain
        state_alpha,
        state_name,
        state_fips,
        year,
        is_us_total,

        -- Measures
        sum(milk_production_lb)                                      as annual_production_lb,
        sum(milk_per_cow_lb)                                         as annual_milk_per_cow_lb,
        avg(milk_cow_head)                                           as avg_milk_cow_head,

        -- Coverage
        count(*)                                                     as months_reported,
        count(*) = 12                                                as is_complete_year
    from monthly
    group by state_alpha, state_name, state_fips, year, is_us_total
)

select * from annual
