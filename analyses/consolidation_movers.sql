/*
    Ad-hoc: which states consolidated fastest? Herd counts and index for the
    latest complete herd-count year vs the 2015 baseline, steepest decline
    first. Compiled (not materialized) — run via `dbt compile` and paste, or
    query the mart directly.
*/

with consolidation as (
    select * from {{ ref('mart_herd_consolidation') }}
),

latest_year as (
    select max(year) as year
    from consolidation
    where licensed_herds is not null
),

movers as (
    select
        c.state_alpha,
        c.state_name,
        c.year,
        c.licensed_herds,
        c.cows_per_herd,
        c.herds_index_2015
    from consolidation c
    inner join latest_year l
        on c.year = l.year
    where not c.is_us_total
      and not c.is_other_states
)

select * from movers
order by herds_index_2015 asc
