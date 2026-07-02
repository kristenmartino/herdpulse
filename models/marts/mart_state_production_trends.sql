{{ config(materialized = 'table') }}

/*
    Production and per-cow yield trends at state × month grain (US-total rows
    flagged and included for the national KPI strip). Adds year-over-year
    deltas (12-month lag — every state's series is contiguous monthly) and
    trailing-12-month rollups. rolling_12m_milk_per_cow_lb is the
    public-aggregate analog of a Rolling Herd Average: the trailing-year
    per-cow benchmark a dairy manager watches month to month. Rolling metrics
    are NULL until a full 12-month window exists — a partial window is not a
    trailing year.
*/

with monthly as (
    select * from {{ ref('int_state_milk__monthly') }}
),

scored as (
    select
        *,

        -- Year-over-year (same month, prior year)
        lag(milk_production_lb, 12) over state_series                as milk_production_lb_prior_year,
        lag(milk_per_cow_lb, 12)    over state_series                as milk_per_cow_lb_prior_year,

        -- Trailing 12 months
        sum(milk_production_lb)     over trailing_12m                as rolling_12m_production_lb_raw,
        sum(milk_per_cow_lb)        over trailing_12m                as rolling_12m_milk_per_cow_lb_raw,
        count(*)                    over trailing_12m                as months_in_window
    from monthly
    window
        state_series as (partition by state_alpha order by month_date),
        trailing_12m as (partition by state_alpha order by month_date
                         rows between 11 preceding and current row)
),

final as (
    select
        -- Grain
        state_alpha,
        state_name,
        state_fips,
        month_date,
        month_num,
        year,
        is_us_total,

        -- Levels
        milk_production_lb,
        milk_per_cow_lb,
        milk_cow_head,

        -- Year-over-year
        milk_production_lb - milk_production_lb_prior_year           as production_lb_yoy,
        (milk_production_lb - milk_production_lb_prior_year)
            / nullif(milk_production_lb_prior_year, 0)               as production_yoy_pct,
        milk_per_cow_lb - milk_per_cow_lb_prior_year                 as per_cow_lb_yoy,
        (milk_per_cow_lb - milk_per_cow_lb_prior_year)
            / nullif(milk_per_cow_lb_prior_year, 0)                  as per_cow_yoy_pct,

        -- Trailing 12 months (gated on a full window)
        case when months_in_window = 12
             then rolling_12m_production_lb_raw end                  as rolling_12m_production_lb,
        case when months_in_window = 12
             then rolling_12m_milk_per_cow_lb_raw end                as rolling_12m_milk_per_cow_lb
    from scored
)

select * from final
