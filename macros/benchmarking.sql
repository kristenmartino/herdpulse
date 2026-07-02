{# ---------------------------------------------------------------------------
   Peer-benchmarking helpers, ported from medicare-provider-outliers.
   There the peer group is (taxonomy_code × state); here it is the national
   distribution of states within a year. Same statistical spine, new domain.
   Documented in macros/_macros.yml (descriptions, arg lists).
   --------------------------------------------------------------------------- #}


{# zscore: classical z-score, (value - mean) / stddev. Null when stddev is 0. #}
{% macro zscore(value, mean, stddev) %}
    case when {{ stddev }} > 0
         then ({{ value }} - {{ mean }}) / {{ stddev }}
    end
{% endmacro %}


{# modified_zscore: MAD-based z-score, robust to skewed distributions.
   Returns 0.6745 * (value - median) / mad, or NULL when mad is 0.
   Thresholds per Iglewicz & Hoaglin (1993). #}
{% macro modified_zscore(value, median, mad, mad_constant=0.6745) %}
    case when {{ mad }} > 0
         then {{ mad_constant }} * ({{ value }} - {{ median }}) / {{ mad }}
    end
{% endmacro %}


{# is_outlier: true when |score| >= threshold. NULL scores → NULL flag. #}
{% macro is_outlier(score, threshold) %}
    abs({{ score }}) >= {{ threshold }}
{% endmacro %}
