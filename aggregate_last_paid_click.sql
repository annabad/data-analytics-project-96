--Витрина для расчета расходов на рекламу по модели атрибуции Last Paid Click
with tab1 as (
    select
        s.visitor_id, visit_date, source, medium, campaign, content,
        lead_id, amount, created_at, closing_reason, learning_format, status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
	where s.medium <> 'organic'
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
where rn = 1 and date(visit_date) <= coalesce(created_at, '9999-12-12')
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
),

ads_tab as (
select
    date(campaign_date) as campaign_date,
    utm_source,
    utm_medium,
    utm_campaign,
    sum(daily_spent) as total_cost
from ya_ads
group by 1, 2, 3, 4
union
select
    date(campaign_date) as campaign_date,
    utm_source,
    utm_medium,
    utm_campaign,
    sum(daily_spent) as total_cost
from vk_ads
group by 1, 2, 3, 4
order by 1
),

aggregate_lpc as (
select
    date(visit_date) as visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    count(lpc.visitor_id) as visitors_count,
    count(lpc.visitor_id) filter (
    	where lpc.visit_date < lpc.created_at
    ) as leads_count,
    count(lpc.closing_reason) filter (
        where lpc.status_id = 142
    ) as purchases_count,
    sum(lpc.amount) as revenue
from last_paid_click as lpc
group by 1, 2, 3, 4
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
inner join ads_tab as ads
on
    agr.utm_source = ads.utm_source and agr.utm_medium = ads.utm_medium
    and agr.utm_campaign = ads.utm_campaign
    and agr.visit_date = ads.campaign_date
order by
revenue desc nulls last, visit_date asc, visitors_count desc,
utm_source asc, utm_medium asc, utm_campaign asc
limit 15;