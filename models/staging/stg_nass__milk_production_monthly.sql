{{ config(materialized = 'view') }}

/*
    Monthly milk production at state × month grain, plus the US-total rows
    (flagged, kept for the KPI strip and the national-reconciliation test).
    NASS publishes true monthly values for the 24 major milk-producing states
    + US; the remaining states arrive only as quarterly rollups
    ('JAN THRU MAR', …) and are dropped here — nass_period_to_month_num
    returns NULL for them, which is the filter.
*/

with raw as (
    select * from {{ ref('nass_milk_production_monthly') }}
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

        -- Measure (verbatim text → double; non-numeric → NULL, never zero)
        {{ parse_nass_value('value') }}                              as milk_production_lb,

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
