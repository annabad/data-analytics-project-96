--Витрина для расчета расходов на рекламу по модели атрибуции Last Paid Click
with last_visits_leads as (
    select
        s.visitor_id,
        max(s.visit_date) as last_visit
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.medium <> 'organic'
    group by 1
),

last_paid_click as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.content as utm_content,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s 
    join last_visits_leads as lvl
        on
            lvl.visitor_id = s.visitor_id  and lvl.last_visit = s.visit_date
    join leads l
        on
            s.visitor_id = l.visitor_id and s.visit_date < l.created_at
    where s.medium <> 'organic'
),

ads_tab as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent,
        campaign_date
    from ya_ads
    union
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent,
        campaign_date
    from vk_ads
),

tab as (
    select
        lpc.visit_date,
        lpc.visitor_id,
        lpc.lead_id,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        ad.daily_spent,
        count(lpc.closing_reason) filter (
            where lpc.status_id = 142
        ) as purchases_count,
        sum(lpc.amount) as revenue --деньги с успешно закрытых лидов
    from last_paid_click as lpc
    inner join ads_tab as ad
        on
            lpc.utm_source = ad.utm_source and lpc.utm_medium = ad.utm_medium
            and lpc.utm_campaign = ad.utm_campaign 
            and lpc.utm_content = ad.utm_content
            and to_char(lpc.visit_date, 'YYYY-MM-DD')
            = to_char(ad.campaign_date, 'YYYY-MM-DD')
    group by 1, 2, 3, 4, 5, 6, 7
)

select
    to_char(visit_date, 'YYYY-MM-DD') as visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    count(visitor_id) as visitors_count,
    sum(daily_spent) as total_cost,
    count(lead_id) as leads_count, 
    sum(purchases_count) as purchases_count,
    sum(revenue) as revenue
from tab
group by 1, 2, 3, 4
order by
    revenue desc nulls last, visit_date asc, visitors_count desc, 
    utm_source asc, utm_medium asc, utm_campaign asc;