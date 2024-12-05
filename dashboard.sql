-- Количество пользователей, заходивших на сайт
SELECT count (DISTINCT visitor_id) as visitors_count
FROM sessions;

SELECT date(visit_date),
count (DISTINCT visitor_id) as visitors_count
FROM sessions
GROUP BY 1;

select distinct EXTRACT(week FROM visit_date) AS visit_week,
count (distinct visitor_id) as visitors_count
from sessions
group by 1;


-- Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам
-- по дням
select distinct date(visit_date) as visit_date, 
source, 
count(distinct visitor_id) as uniq_visitors
from sessions
group by 1, 2;

-- по неделям
SELECT distinct EXTRACT(week FROM visit_date) AS visit_week,
source,
count (distinct visitor_id) as uniq_visitors
from sessions
group by 1, 2;

-- за месяц

SELECT distinct EXTRACT(MONTH FROM visit_date) AS month,
source,
count (distinct visitor_id) as uniq_visitors
from sessions
group by 1, 2;

-- Сколько лидов к нам приходят?
select count(distinct lead_id)
from leads;

-- Расчет конверсий по модели аттрибуции Last Paid Click

with tab1 as (
    select
        s.visitor_id, visit_date, source, medium, campaign, content,
        lead_id, amount, created_at, closing_reason, learning_format, status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium <> 'organic'
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
where rn = 1 and visit_date < coalesce(created_at, '9999-12-31')
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
)

, aggregate_lpc as (
select
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    count(distinct lpc.visitor_id) as visitors_count,
    count(lpc.lead_id) as leads_count,
    count(lpc.closing_reason) filter (
        where lpc.status_id = 142
    ) as purchases_count
from last_paid_click as lpc
group by 1, 2, 3
)

select
utm_source as "Источник",
utm_medium,
utm_campaign,
visitors_count as "Кол-во пользователей, заходивших на сайт",
leads_count as "Кол-во лидов",
round(leads_count * 100.0 / visitors_count, 2) as "конверсия из клика в лид, %",
case 
	when leads_count > 0 then round(purchases_count * 100.0 / leads_count, 2)
	else 0
end as "конверсия из лида в оплату, %"
from aggregate_lpc
;
--Расчет конверсий для профессий


with tab1 as (
    select
        s.visitor_id, visit_date, source, medium, campaign, content,
        lead_id, amount, created_at, closing_reason, learning_format, status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium <> 'organic'
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
where rn = 1 and visit_date < coalesce(created_at, '9999-12-31')
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
)

, aggregate_lpc as (
select
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    count(distinct lpc.visitor_id) as visitors_count,
    count(lpc.lead_id) as leads_count,
    count(lpc.closing_reason) filter (
        where lpc.status_id = 142
    ) as purchases_count
from last_paid_click as lpc
group by 1, 2, 3
)

select
utm_campaign,
visitors_count as "Кол-во пользователей, заходивших на сайт",
leads_count as "Кол-во лидов",
round(leads_count * 100.0 / visitors_count, 2) as "конверсия из клика в лид, %",
case 
	when leads_count > 0 then round(purchases_count * 100.0 / leads_count, 2)
	else 0
end as "конверсия из лида в оплату, %"
from aggregate_lpc
where utm_source in ('vk', 'yandex')
;

-- Расчет конверсий по модели аттрибуции Last Paid Click для Yandex

with tab1 as (
    select
        s.visitor_id, visit_date, source, medium, campaign, content,
        lead_id, amount, created_at, closing_reason, learning_format, status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium <> 'organic'
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
where rn = 1 and visit_date < coalesce(created_at, '9999-12-31')
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
)

, aggregate_lpc as (
select
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    count(distinct lpc.visitor_id) as visitors_count,
    count(lpc.lead_id) as leads_count,
    count(lpc.closing_reason) filter (
        where lpc.status_id = 142
    ) as purchases_count
from last_paid_click as lpc
group by 1, 2, 3
)

select
utm_source as "Источник",
sum(visitors_count) as "Кол-во пользователей, заходивших на сайт",
sum(leads_count) as "Кол-во лидов",
sum(purchases_count) as "Кол-во покупок",
round(sum(leads_count) * 100.0 / sum(visitors_count), 2) as "конверсия из клика в лид, %",
case 
	when sum(leads_count) > 0 then round(sum(purchases_count) * 100.0 / sum(leads_count), 2)
	else 0
end as "конверсия из лида в оплату, %"
from aggregate_lpc
where utm_source in ('yandex')
group by 1
;

-- Расчет конверсий по модели аттрибуции Last Paid Click для VK

with tab1 as (
    select
        s.visitor_id, visit_date, source, medium, campaign, content,
        lead_id, amount, created_at, closing_reason, learning_format, status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium <> 'organic'
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
where rn = 1 and visit_date < coalesce(created_at, '9999-12-31')
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
)

, aggregate_lpc as (
select
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    count(distinct lpc.visitor_id) as visitors_count,
    count(lpc.lead_id) as leads_count,
    count(lpc.closing_reason) filter (
        where lpc.status_id = 142
    ) as purchases_count
from last_paid_click as lpc
group by 1, 2, 3
)

select
utm_source as "Источник",
sum(visitors_count) as "Кол-во пользователей, заходивших на сайт",
sum(leads_count) as "Кол-во лидов",
sum(purchases_count) as "Кол-во покупок",
round(sum(leads_count) * 100.0 / sum(visitors_count), 2) as "конверсия из клика в лид, %",
case 
	when sum(leads_count) > 0 then round(sum(purchases_count) * 100.0 / sum(leads_count), 2)
	else 0
end as "конверсия из лида в оплату, %"
from aggregate_lpc
where utm_source in ('vk')
group by 1
;

-- Расчет расходов на рекламу в динамике

with total_ads as (
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
)

select campaign_date,
utm_source,
utm_medium,
utm_campaign,
sum(total_cost) as daily_spent
from total_ads
WHERE utm_source = 'yandex'
group by 1, 2, 3, 4
order by 1;

-- Суммарно потрачено на рекламу в июне

select (select sum(daily_spent)
from ya_ads)
+
(select sum(daily_spent)
from vk_ads)
as total_spent;

-- Расчет метрик
--cpu = total_cost / visitors_count
--cpl = total_cost / leads_count
--cppu = total_cost / purchases_count
--roi = (revenue - total_cost) / total_cost * 100%
-- по источнику

with tab1 as (
    select
        s.visitor_id, visit_date, source, medium, campaign, content,
        lead_id, amount, created_at, closing_reason, learning_format, status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium <> 'organic'
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
where rn = 1 and visit_date < coalesce(created_at, '9999-12-31')
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
    count(distinct lpc.visitor_id) as visitors_count,
    count(lpc.lead_id) as leads_count,
    count(lpc.closing_reason) filter (
        where lpc.status_id = 142
    ) as purchases_count,
    sum(lpc.amount) as revenue
from last_paid_click as lpc
group by 1, 2, 3, 4
),

aggregated_expenses as (
select
agr.visit_date,
agr.utm_source,
agr.utm_medium,
agr.utm_campaign,
agr.visitors_count,
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
)

select 
utm_source, 
round(sum(total_cost) / sum(visitors_count), 2) as cpu,
round(sum(total_cost) / sum(leads_count), 2) as cpl,
round(sum(total_cost) / sum(purchases_count), 2) as cppu,
round((sum(revenue) - sum(total_cost)) * 100.0 / sum(total_cost), 2) as roi
from aggregated_expenses
group by 1
;
-- расчет метрик по source/medium/campaign

with tab1 as (
    select
        s.visitor_id, visit_date, source, medium, campaign, content,
        lead_id, amount, created_at, closing_reason, learning_format, status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium <> 'organic'
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
where rn = 1 and visit_date < coalesce(created_at, '9999-12-31')
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
    count(distinct lpc.visitor_id) as visitors_count,
    count(lpc.lead_id) as leads_count,
    count(lpc.closing_reason) filter (
        where lpc.status_id = 142
    ) as purchases_count,
    sum(lpc.amount) as revenue
from last_paid_click as lpc
group by 1, 2, 3, 4
),

aggregated_expenses as (
select
agr.visit_date,
agr.utm_source,
agr.utm_medium,
agr.utm_campaign,
agr.visitors_count,
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
)

select 
utm_source, 
utm_medium,
utm_campaign,
case when sum(visitors_count) = 0 then 0 else round(sum(total_cost) / sum(visitors_count), 2) end as cpu,
case when sum(leads_count) = 0 then 0 else round(sum(total_cost) / sum(leads_count), 2) end as cpl,
case when sum(purchases_count) = 0 then 0 else round(sum(total_cost) / sum(purchases_count), 2) end as cppu,
case when sum(total_cost) = 0 then 0 else round((sum(revenue) - sum(total_cost)) * 100.0 / sum(total_cost), 2) end as roi
from aggregated_expenses
group by 1, 2, 3
ORDER by 1, roi desc nulls last
;


-- Через какое время после запуска компании маркетинг может анализировать компанию используя ваш дашборд? 
-- Можно посчитать за сколько дней с момента перехода по рекламе закрывается 90% лидов.

with tab1 as (
    select
        s.visitor_id, visit_date, source, medium, campaign, content,
        lead_id, amount, created_at, closing_reason, learning_format, status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads on s.visitor_id = leads.visitor_id
where medium <> 'organic'
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
where rn = 1 and visit_date < coalesce(created_at)
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
)

, days_tab as (
select *,
(created_at - visit_date) as days_till_lead,
ntile(10) over(order by (created_at - visit_date)) 
FROM last_paid_click
where status_id = 142
)

select max(days_till_lead) as days_90percent
from days_tab
where ntile = 9;

-- Есть ли заметная корреляция между запуском рекламной компании и ростом органики?

WITH ads_tab as (
select
    date(campaign_date) as campaign_date,
    utm_source,
    utm_medium,
    utm_campaign
from ya_ads
union
select
    date(campaign_date) as campaign_date,
    utm_source,
    utm_medium,
    utm_campaign
from vk_ads
order by 1
),

campaigns_count as (
select date(campaign_date) as campaign_date, 
count(utm_campaign) as campaigns_cnt
from ads_tab
group by 1
)

SELECT cc.campaign_date, campaigns_cnt, count(distinct visitor_id) as organic_visitors_cnt
FROM sessions s
join campaigns_count cc on date(s.visit_date) = cc.campaign_date and s.medium = 'organic'
group by 1, 2;
