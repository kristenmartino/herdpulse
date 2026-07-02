/*
    Reconciliation is a test, not a hope: for every month, the sum of the
    published state-level production must land inside a stated band of the
    US total. The 24 major milk-producing states NASS publishes monthly are
    ~95–96% of national production (OTHER STATES has no monthly rows), so the
    honest assertion is a coverage band, not equality: sum(states) within
    [90%, 100%] of the US total. Drift outside that band means a broken join,
    a dropped state, or double-counted national rows.
*/

{% set coverage_floor = 0.90 %}
{% set coverage_ceiling = 1.00 %}

with monthly as (
    select * from {{ ref('int_state_milk__monthly') }}
),

state_sums as (
    select
        month_date,
        sum(milk_production_lb)                                      as states_production_lb
    from monthly
    where not is_us_total
      and milk_production_lb is not null
    group by month_date
),

us_totals as (
    select
        month_date,
        milk_production_lb                                           as us_production_lb
    from monthly
    where is_us_total
      and milk_production_lb is not null
),

compared as (
    select
        s.month_date,
        s.states_production_lb,
        u.us_production_lb,
        s.states_production_lb / u.us_production_lb                  as coverage_ratio
    from state_sums s
    inner join us_totals u
        on s.month_date = u.month_date
)

select * from compared
where coverage_ratio < {{ coverage_floor }}
   or coverage_ratio > {{ coverage_ceiling }}
