--Витрина для расчета расходов на рекламу по модели атрибуции Last Paid Click
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
        and date(s.visit_date) <= date(l.created_at)
    where s.medium != 'organic'
),

last_paid_click as (
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
    where rn = 1
    order by
        amount desc nulls last,
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

aggregate_lpc as (
    select
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        date(lpc.visit_date) as visit_date,
        count(lpc.visitor_id) as visitors_count,
        count(lpc.lead_id) as leads_count,
        count(lpc.closing_reason) filter (
            where lpc.status_id = 142
        ) as purchases_count,
        sum(lpc.amount) as revenue
    from last_paid_click as lpc
    group by
        date(lpc.visit_date), lpc.utm_source, lpc.utm_medium, lpc.utm_campaign
    order by revenue desc
),

ads_tab as (
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    union
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    order by date(campaign_date)
)

select
    agr.visit_date,
    agr.visitors_count,
    agr.utm_source,
    agr.utm_medium,
    agr.utm_campaign,
    ads.total_cost,
    agr.leads_count,
    agr.purchases_count,
    agr.revenue
from aggregate_lpc as agr
left join ads_tab as ads
    on
        agr.utm_source = ads.utm_source
        and agr.utm_medium = ads.utm_medium
        and agr.utm_campaign = ads.utm_campaign
        and agr.visit_date = ads.campaign_date
order by
    agr.revenue desc nulls last, agr.visit_date asc, agr.visitors_count desc,
    agr.utm_source asc, agr.utm_medium asc, agr.utm_campaign asc
limit 15;
