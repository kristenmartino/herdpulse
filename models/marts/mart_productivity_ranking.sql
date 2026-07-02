{{ config(materialized = 'table') }}

/*
    Per-cow productivity ranking at state × year grain: each state's annual
    milk-per-cow scored against the national distribution of states for that
    year. This is the peer-benchmarking methodology carried over from
    medicare-provider-outliers — classical z-score (mean/stddev) plus
    MAD-based modified z-score (0.6745 × (x − median) / MAD), the latter
    robust to skew — with the peer group swapped from (taxonomy × state)
    provider cells to the national set of published states.

    Complete years and real states only: the partial current year and the
    US-total rows are excluded upstream of scoring (a five-month year is not
    a low-yield year; a national total is not its own peer).
*/

{% set z_threshold = 2.0 %}

with annual as (
    select * from {{ ref('int_state_milk__annual') }}
),

benchmark as (
    select * from {{ ref('int_productivity__national_benchmark') }}
),

eligible as (
    select * from annual
    where not is_us_total
      and is_complete_year
      and annual_milk_per_cow_lb is not null
),

scored as (
    select
        -- Grain
        e.state_alpha,
        e.state_name,
        e.state_fips,
        e.year,

        -- Levels
        e.annual_milk_per_cow_lb,
        e.annual_production_lb,
        e.avg_milk_cow_head,

        -- National distribution context
        b.n_states,
        b.mean_milk_per_cow_lb,
        b.stddev_milk_per_cow_lb,
        b.median_milk_per_cow_lb,
        b.mad_milk_per_cow_lb,

        -- Scores vs the national distribution
        {{ zscore('e.annual_milk_per_cow_lb', 'b.mean_milk_per_cow_lb', 'b.stddev_milk_per_cow_lb') }}
                                                                     as per_cow_zscore,
        {{ modified_zscore('e.annual_milk_per_cow_lb', 'b.median_milk_per_cow_lb', 'b.mad_milk_per_cow_lb') }}
                                                                     as per_cow_modified_zscore,

        -- Rank / percentile within the year
        rank() over (partition by e.year
                     order by e.annual_milk_per_cow_lb desc)         as productivity_rank,
        percent_rank() over (partition by e.year
                             order by e.annual_milk_per_cow_lb)      as per_cow_percentile
    from eligible e
    inner join benchmark b
        on e.year = b.year
),

flagged as (
    select
        *,
        {{ is_outlier('per_cow_zscore', z_threshold) }}              as is_productivity_outlier
    from scored
)

select * from flagged
