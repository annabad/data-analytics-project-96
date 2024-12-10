-- Количество пользователей, заходивших на сайт
SELECT count(DISTINCT visitor_id) AS visitors_count
FROM sessions;

SELECT
    date(visit_date),
    count(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY date(visit_date);

SELECT DISTINCT
    extract(WEEK FROM visit_date) AS visit_week,
    count(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY extract(WEEK FROM visit_date);


-- Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам
-- по дням
SELECT DISTINCT
    date(visit_date) AS visit_date,
    source,
    count(DISTINCT visitor_id) AS uniq_visitors
FROM sessions
GROUP BY date(visit_date), source;

-- по неделям
SELECT DISTINCT
    extract(WEEK FROM visit_date) AS visit_week,
    source,
    count(DISTINCT visitor_id) AS uniq_visitors
FROM sessions
GROUP BY extract(WEEK FROM visit_date), source;

-- за месяц

SELECT DISTINCT
    extract(MONTH FROM visit_date) AS month,
    source,
    count(DISTINCT visitor_id) AS uniq_visitors
FROM sessions
GROUP BY extract(MONTH FROM visit_date), source;

-- Сколько лидов к нам приходят?
SELECT count(DISTINCT lead_id)
FROM leads;

-- Расчет конверсий по модели аттрибуции Last Paid Click

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
    where rn = 1 and date(visit_date) <= date(created_at)
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
        count(lpc.lead_id) filter (
            where lpc.visit_date <= lpc.created_at
        ) as leads_count,
        count(lpc.closing_reason) filter (
            where lpc.status_id = 142
        ) as purchases_count,
        sum(lpc.amount) as revenue
    from last_paid_click as lpc
    group by
        date(lpc.visit_date), lpc.utm_source, lpc.utm_medium, lpc.utm_campaign
    order by revenue desc
)

select utm_source as source,
    sum(visitors_count) as visitors_count,
    sum(leads_count) as leads_count,
    round(sum(leads_count) * 100.0 / sum(visitors_count), 2)
    as vonversion_from_click_to_lead,
    case
        when sum(leads_count) > 0 
        then round(sum(purchases_count) * 100.0 / sum(leads_count), 2)
        else 0
    end as Conversion_from_lead_to_payment
from aggregate_lpc
group by utm_source;

-- Расчет расходов на рекламу в динамике

with total_ads as (
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
    order by campaign_date
)

select
    campaign_date,
    utm_source,
    utm_medium,
    utm_campaign,
    sum(total_cost) as daily_spent
from total_ads
group by
    campaign_date,
    utm_source,
    utm_medium,
    utm_campaign
order by campaign_date;


-- Расчет метрик по источнику
--cpu = total_cost / visitors_count
--cpl = total_cost / leads_count
--cppu = total_cost / purchases_count
--roi = (revenue - total_cost) / total_cost * 100%

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
    where rn = 1 and date(visit_date) <= date(created_at)
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
        count(lpc.lead_id) filter (
            where lpc.visit_date <= lpc.created_at
        ) as leads_count,
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
    order by campaign_date
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
group by utm_source;


-- Через какое время после запуска компании маркетинг может анализировать компанию используя ваш дашборд? 
-- Можно посчитать за сколько дней с момента перехода по рекламе закрывается 90% лидов.

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
    where rn = 1 and date(visit_date) <= date(created_at)
    order by
        amount desc nulls last,
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

days_tab as (
    select
        *,
        (created_at - visit_date) as days_till_lead,
        ntile(10) over (order by (created_at - visit_date)) as ntl
    from last_paid_click
    where status_id = 142
)

select max(days_till_lead) as days_90_percent_leads_closed
from days_tab
where ntl = 9;


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
    select
        date(campaign_date) as campaign_date, 
        count(utm_campaign) as campaigns_cnt
    from ads_tab
    group by 1
)

select
    cc.campaign_date,
    cc.campaigns_cnt,
    count(distinct s.visitor_id) as organic_visitors_cnt
from sessions s
join campaigns_count cc
    on
        date(s.visit_date) = cc.campaign_date and s.medium = 'organic'
group by
	cc.campaign_date,
    cc.campaigns_cnt;