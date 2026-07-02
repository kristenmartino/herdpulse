{# ---------------------------------------------------------------------------
   NASS Quick Stats parsing helpers, used by every staging model.
   Documented in macros/_macros.yml.
   --------------------------------------------------------------------------- #}


{# nass_period_to_month_num: maps a Quick Stats monthly reference_period_desc
   (JAN..DEC) to 1..12. Non-month periods — quarterly rollups like
   'JAN THRU MAR', or 'YEAR' — return NULL, which is also how staging filters
   to true monthly grain (where ... is not null). #}
{% macro nass_period_to_month_num(period_col) %}
    case {{ period_col }}
        when 'JAN' then 1
        when 'FEB' then 2
        when 'MAR' then 3
        when 'APR' then 4
        when 'MAY' then 5
        when 'JUN' then 6
        when 'JUL' then 7
        when 'AUG' then 8
        when 'SEP' then 9
        when 'OCT' then 10
        when 'NOV' then 11
        when 'DEC' then 12
    end
{% endmacro %}


{# parse_nass_value: NASS formats numbers with commas ("19,087,000,000") and
   uses codes like (D)/(NA)/(Z) for suppressed or unavailable cells. Strip the
   commas and try_cast — anything non-numeric becomes NULL, never zero. #}
{% macro parse_nass_value(value_col) %}
    try_cast(replace({{ value_col }}, ',', '') as double)
{% endmacro %}
