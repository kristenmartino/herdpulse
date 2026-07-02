{{ config(materialized = 'table') }}

/*
    The structural-consolidation story at state × year grain: licensed dairy
    herds (falling), cows-per-herd (rising), year-over-year change, and an
    index against each state's first observed year (2015 = 100 for every
    series in this pull). US-total and OTHER STATES rows are flagged and
    included — the national herd-count decline is the headline KPI.
*/

with herd_counts as (
    select * from {{ ref('int_herd_counts__annual') }}
),

scored as (
    select
        *,
        lag(licensed_herds) over state_series                        as licensed_herds_prior_year,
        lag(cows_per_herd)  over state_series                        as cows_per_herd_prior_year,
        first_value(licensed_herds) over state_series                as licensed_herds_baseline
    from herd_counts
    window state_series as (partition by state_alpha order by year)
),

final as (
    select
        -- Grain
        state_alpha,
        state_name,
        state_fips,
        year,
        is_us_total,
        is_other_states,

        -- Levels
        licensed_herds,
        avg_milk_cow_head,
        cows_per_herd,

        -- Year-over-year
        licensed_herds - licensed_herds_prior_year                   as licensed_herds_yoy,
        (licensed_herds - licensed_herds_prior_year)
            / nullif(licensed_herds_prior_year, 0)                   as licensed_herds_yoy_pct,
        (cows_per_herd - cows_per_herd_prior_year)
            / nullif(cows_per_herd_prior_year, 0)                    as cows_per_herd_yoy_pct,

        -- Consolidation index (first observed year = 100)
        100.0 * licensed_herds
            / nullif(licensed_herds_baseline, 0)                     as herds_index_2015
    from scored
)

select * from final
