{% test dbt_utils_free_unique(model, column_names) %}
select {{ column_names | join(', ') }}, count(*) c from {{ model }}
group by {{ column_names | join(', ') }} having count(*) > 1
{% endtest %}
