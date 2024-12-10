--Витрина для модели атрибуции Last Paid Click
with tab1 as (
    select
        s.visitor_id,
        s.visit_date,
        s.source,
        s.medium,
        s.campaign,
        l.lead_id,
        l.amount,
        l.created_at,
        l.closing_reason,
        l.learning_format,
        l.status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads as l on s.visitor_id = l.visitor_id
    where s.medium <> 'organic'
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
from tab1
where rn = 1 and date(visit_date) <= date(created_at)
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc;