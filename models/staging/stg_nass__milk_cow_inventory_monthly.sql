{{ config(materialized = 'view') }}

/*
    Average milk-cow inventory during the month (head) at state × month grain,
    plus flagged US-total rows. Sourced from the INVENTORY, AVG series — the
    Milk Production report's monthly cow numbers — not the semi-annual
    point-in-time cattle survey (see seeds/_seeds.yml and data/README.md for
    the distinction). Quarterly rollup rows for non-major states are dropped
    by the month filter.
*/

with raw as (
    select * from {{ ref('nass_milk_cow_inventory_monthly') }}
),

renamed as (
    select
        -- Grain
        year,
        {{ nass_period_to_month_num('reference_period_desc') }}      as month_num,
        make_date(year, {{ nass_period_to_month_num('reference_period_desc') }}, 1)
                                                                     as month_date,

        -- Geography
        state_name,
        state_alpha,
        state_fips,
        state_alpha = 'US'                                           as is_us_total,
        state_alpha = 'OT'                                           as is_other_states,

        -- Measure
        {{ parse_nass_value('value') }}                              as milk_cow_head,

        -- Provenance
        short_desc,
        unit_desc
    from raw
),

monthly_only as (
    select * from renamed
    where month_num is not null
)

select * from monthly_only
