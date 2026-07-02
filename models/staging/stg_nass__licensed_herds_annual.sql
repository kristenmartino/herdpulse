{{ config(materialized = 'view') }}

/*
    Licensed dairy herds at state × year grain, plus flagged US-total and
    OTHER STATES rows. Annual series (reference period 'YEAR'), published
    2003–present; this pull starts at 2015 to match the monthly series. The
    long structural decline in this count — while cows-per-herd rises — is
    the consolidation story mart_herd_consolidation tells.
*/

with raw as (
    select * from {{ ref('nass_licensed_herds_annual') }}
),

renamed as (
    select
        -- Grain
        year,

        -- Geography
        state_name,
        state_alpha,
        state_fips,
        state_alpha = 'US'                                           as is_us_total,
        state_alpha = 'OT'                                           as is_other_states,

        -- Measure
        {{ parse_nass_value('value') }}                              as licensed_herds,

        -- Provenance
        short_desc,
        unit_desc
    from raw
    where reference_period_desc = 'YEAR'
)

select * from renamed
