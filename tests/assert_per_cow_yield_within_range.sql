/*
    Business rule: monthly per-cow yield must stay inside a physically sane
    band. US annual per-cow averages ~24,000 lb (≈2,000 lb/month); the band
    below allows the seasonal spread from Southeast summer heat-stress lows
    to upper-Midwest spring-flush highs. A value outside it is a parsing or
    unit error, not a cow.
*/

{% set min_monthly_per_cow_lb = 1200 %}
{% set max_monthly_per_cow_lb = 2600 %}

select
    state_alpha,
    month_date,
    milk_per_cow_lb
from {{ ref('mart_state_production_trends') }}
where milk_per_cow_lb is not null
  and (
        milk_per_cow_lb < {{ min_monthly_per_cow_lb }}
     or milk_per_cow_lb > {{ max_monthly_per_cow_lb }}
  )
