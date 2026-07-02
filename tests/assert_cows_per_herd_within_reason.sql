/*
    Business rule: cows-per-herd must be positive and plausibly sized.
    The largest-herd states (NM, AZ) run ~2,500–3,500 cows per licensed
    operation; anything at or below zero is a null-division or join error,
    and anything past 5,000 is a unit error, not a dairy.
*/

{% set max_cows_per_herd = 5000 %}

select
    state_alpha,
    year,
    licensed_herds,
    avg_milk_cow_head,
    cows_per_herd
from {{ ref('mart_herd_consolidation') }}
where cows_per_herd is not null
  and (
        cows_per_herd <= 0
     or cows_per_herd > {{ max_cows_per_herd }}
  )
