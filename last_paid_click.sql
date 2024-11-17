--Витрина для модели атрибуции Last Paid Click
with last_visits_leads as (
    select
        s.visitor_id,
        max(s.visit_date) as last_visit
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.medium != 'organic'
    group by 1
)

select
    s.visitor_id,-- уникальный человек на сайте
    s.visit_date, --время визита
    s.source as utm_source,--метки c учетом модели атрибуции
    s.medium as utm_medium,--метки c учетом модели атрибуции
    s.campaign as utm_campaign,--метки c учетом модели атрибуции
    l.lead_id,--идентификатор лида, если пользователь сконвертился в лид после(во время) визита
    l.created_at,-- время создания лида,
    l.amount,--сумма лида (в деньгах)
    l.closing_reason, --причина закрытия
    l.status_id --код причины закрытия
from sessions as s
inner join
    last_visits_leads as lvl
--находим в таблице sessions последние визиты лидов
    on s.visitor_id = lvl.visitor_id and s.visit_date = lvl.last_visit
inner join
    leads as l
--находим в таблице sessions последние визиты, которые состоялись до даты создания лида
    on s.visitor_id = l.visitor_id and s.visit_date < l.created_at
where s.medium <> 'organic'
order by
    amount desc nulls last, visit_date asc, utm_source asc, utm_medium asc, utm_campaign asc;
