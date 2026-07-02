{{ config(materialized = 'view') }}

/*
    Monthly milk-per-cow yield (lb/head) at state × month grain, plus flagged
    US-total rows. Published only for the 24 major milk-producing states + US
    — this is the series the productivity ranking benchmarks, and the monthly
    input to the rolling-12-month per-cow metric (the public-aggregate analog
    of a Rolling Herd Average).
*/

with raw as (
    select * from {{ ref('nass_milk_per_cow_monthly') }}
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
        {{ parse_nass_value('value') }}                              as milk_per_cow_lb,

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
