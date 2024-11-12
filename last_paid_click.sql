with last_visits_leads as (
    select
        s.visitor_id,
        max(s.visit_date) as last_visit
    from sessions as s
    inner join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.medium != 'organic'
    group by 1
)

select
    s.visitor_id,
    s.visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
from sessions as s
inner join
    last_visits_leads as lvl
    on s.visitor_id = lvl.visitor_id and s.visit_date = lvl.last_visit
inner join
    leads as l
    on s.visitor_id = l.visitor_id and s.visit_date < l.created_at
order by
    amount desc nulls last, visit_date asc, utm_source asc, utm_medium asc, utm_campaign asc;
