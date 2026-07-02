{{ config(materialized = 'table') }}

/*
    National benchmark distribution for per-cow productivity: one row per
    year, computed over the real states only (US-total rows excluded) and
    complete years only. This is the peer-group-statistics analog from
    medicare-provider-outliers — there the peer set was (taxonomy × state),
    here it is the published major milk-producing states within a year.

    MAD is computed two-pass (group median via window, then the median of
    absolute deviations) — same shape as the Medicare peer-stats model.
*/

with annual as (
    select * from {{ ref('int_state_milk__annual') }}
),

states_only as (
    select * from annual
    where not is_us_total
      and is_complete_year
      and annual_milk_per_cow_lb is not null
),

with_year_medians as (
    select
        *,
        median(annual_milk_per_cow_lb) over (partition by year)      as year_median_per_cow_lb
    from states_only
),

benchmark as (
    select
        -- Grain
        year,

        -- Peer-set coverage
        count(*)                                                     as n_states,

        -- National distribution of annual per-cow yield
        avg(annual_milk_per_cow_lb)                                  as mean_milk_per_cow_lb,
        stddev(annual_milk_per_cow_lb)                               as stddev_milk_per_cow_lb,
        median(annual_milk_per_cow_lb)                               as median_milk_per_cow_lb,
        median(abs(annual_milk_per_cow_lb - year_median_per_cow_lb)) as mad_milk_per_cow_lb
    from with_year_medians
    group by year
)

select * from benchmark
