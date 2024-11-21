--Витрина для модели атрибуции Last Paid Click
with tab as (
    select
        *,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium <> 'organic'
)

select
visitor_id,
visit_date,
source as utm_source,
medium as utm_medium,
campaign as utm_campaign,
lead_id,
created_at,
amount,
closing_reason,
status_id
from tab
where rn = 1 and visit_date < coalesce(created_at, '2023-07-01')
order by
amount desc nulls last, visit_date asc, utm_source asc, utm_medium asc, utm_campaign asc;
