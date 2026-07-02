{# ---------------------------------------------------------------------------
   Custom schema resolution.

   dbt's default generate_schema_name prefixes the target schema onto every
   custom schema (target.schema = "main"  ->  main_staging etc.). This
   project instead uses the per-layer `+schema:` values from dbt_project.yml
   verbatim, so the DuckDB file reads cleanly:

       raw            (NASS seeds)
       staging        (stg_ views)
       intermediate   (int_ tables)
       marts          (mart_ tables)

   Models without an explicit `+schema:` fall back to the target's default
   schema from profiles.yml.
   --------------------------------------------------------------------------- #}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema | trim }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
