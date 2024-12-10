-- Количество пользователей, заходивших на сайт
SELECT count(DISTINCT visitor_id) AS visitors_count
FROM sessions;

SELECT
    date(visit_date) AS visit_date,
    count(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY date(visit_date);

SELECT 
    extract(WEEK FROM visit_date) AS visit_week,
    count(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY extract(WEEK FROM visit_date);


-- Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам
-- по дням
SELECT
    date(visit_date) AS visit_date,
    source,
    count(DISTINCT visitor_id) AS uniq_visitors
FROM sessions
GROUP BY date(visit_date), source;

-- по неделям
SELECT 
    extract(WEEK FROM visit_date) AS visit_week,
    source,
    count(DISTINCT visitor_id) AS uniq_visitors
FROM sessions
GROUP BY extract(WEEK FROM visit_date), source;

-- за месяц

SELECT
    extract(MONTH FROM visit_date) AS visit_month,
    source,
    count(DISTINCT visitor_id) AS uniq_visitors
FROM sessions
GROUP BY extract(MONTH FROM visit_date), source;

-- Сколько лидов к нам приходят?
SELECT count(DISTINCT lead_id)
FROM leads;

-- Расчет конверсий по модели аттрибуции Last Paid Click

WITH tab1 AS (
    SELECT
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
        OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC)
        AS rn
    FROM sessions AS s
    LEFT JOIN leads AS l ON s.visitor_id = l.visitor_id
    WHERE s.medium != 'organic'
),

last_paid_click as (
    SELECT
        visitor_id,
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    FROM tab1
    WHERE rn = 1 and date(visit_date) <= date(created_at)
    ORDER BY
        amount DESC NULLS LAST,
        visit_date ASC,
        utm_source ASC,
        utm_medium ASC,
        utm_campaign ASC
),

aggregate_lpc AS (
    SELECT
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        date(lpc.visit_date) AS visit_date,
        count(lpc.visitor_id) AS visitors_count,
        count(lpc.lead_id) FILTER (
            WHERE lpc.visit_date <= lpc.created_at
        ) AS leads_count,
        count(lpc.closing_reason) FILTER (
            WHERE lpc.status_id = 142
        ) AS purchases_count,
        sum(lpc.amount) as revenue
    FROM last_paid_click as lpc
    GROUP BY
        date(lpc.visit_date), lpc.utm_source, lpc.utm_medium, lpc.utm_campaign
    ORDER BY revenue DESC
)

SELECT 
    utm_source AS source,
    sum(visitors_count) AS visitors_count,
    sum(leads_count) AS leads_count,
    round(sum(leads_count) * 100.0 / sum(visitors_count), 2)
    AS vonversion_from_click_to_lead,
    CASE
        WHEN sum(leads_count) > 0
            THEN round(sum(purchases_count) * 100.0 / sum(leads_count), 2)
        ELSE 0
    END AS conversion_from_lead_to_payment
FROM aggregate_lpc
GROUP BY utm_source;

-- Расчет расходов на рекламу в динамике

WITH total_ads AS (
    SELECT
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    FROM ya_ads
    GROUP BY
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    UNION
    SELECT
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    FROM vk_ads
    GROUP BY
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    ORDER BY campaign_date
)

SELECT
    campaign_date,
    utm_source,
    utm_medium,
    utm_campaign,
    sum(total_cost) as daily_spent
FROM total_ads
GROUP BY
    campaign_date,
    utm_source,
    utm_medium,
    utm_campaign
ORDER BY campaign_date;


-- Расчет метрик по источнику
--cpu = total_cost / visitors_count
--cpl = total_cost / leads_count
--cppu = total_cost / purchases_count
--roi = (revenue - total_cost) / total_cost * 100%

WITH tab1 AS (
    SELECT
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
        OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC)
        AS rn
    FROM sessions AS s
    LEFT JOIN leads AS l on s.visitor_id = l.visitor_id
    WHERE s.medium != 'organic'
),

last_paid_click as (
    SELECT
        visitor_id,
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    FROM tab1
    WHERE rn = 1 and date(visit_date) <= date(created_at)
    ORDER BY
        amount DESC NULLS LAST,
        visit_date ASC,
        utm_source ASC,
        utm_medium ASC,
        utm_campaign ASC
),

aggregate_lpc AS (
    SELECT
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        date(lpc.visit_date) AS visit_date,
        count(lpc.visitor_id) AS visitors_count,
        count(lpc.lead_id) FILTER (
            WHERE lpc.visit_date <= lpc.created_at
        ) AS leads_count,
        count(lpc.closing_reason) FILTER (
            WHERE lpc.status_id = 142
        ) AS purchases_count,
        sum(lpc.amount) as revenue
    FROM last_paid_click as lpc
    GROUP BY
        date(lpc.visit_date), lpc.utm_source, lpc.utm_medium, lpc.utm_campaign
    ORDER BY revenue DESC
),

ads_tab AS (
    SELECT
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    FROM ya_ads
    GROUP BY
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
UNION
    SELECT
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    FROM vk_ads
    GROUP BY
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    ORDER BY campaign_date
),

aggregated_expenses AS (
    SELECT
        agr.visit_date,
        agr.utm_source,
        agr.utm_medium,
        agr.utm_campaign,
        agr.visitors_count,
        ads.total_cost,
        agr.leads_count,
        agr.purchases_count,
        agr.revenue
    FROM aggregate_lpc AS agr
    INNER JOIN ads_tab AS ads
        ON
            agr.utm_source = ads.utm_source AND agr.utm_medium = ads.utm_medium
            AND agr.utm_campaign = ads.utm_campaign
            AND agr.visit_date = ads.campaign_date
    ORDER BY
        agr.revenue DESC NULLS LAST, agr.visit_date ASC, agr.visitors_count DESC,
        agr.utm_source ASC, agr.utm_medium ASC, agr.utm_campaign ASC
)

SELECT
    utm_source,
    round(sum(total_cost) / sum(visitors_count), 2) AS cpu,
    round(sum(total_cost) / sum(leads_count), 2) AS cpl,
    round(sum(total_cost) / sum(purchases_count), 2) AS cppu,
    round((sum(revenue) - sum(total_cost)) * 100.0 / sum(total_cost), 2) AS roi
FROM aggregated_expenses
GROUP BY utm_source;


-- Через какое время после запуска компании маркетинг может 
-- анализировать компанию, используя ваш дашборд? 
-- (за сколько дней с момента перехода по рекламе закрывается 90% лидов)

WITH tab1 AS (
    SELECT
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
        OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC)
        AS rn
    FROM sessions AS s
    LEFT JOIN leads AS l on s.visitor_id = l.visitor_id
    WHERE s.medium != 'organic'
),

last_paid_click as (
    SELECT
        visitor_id,
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    FROM tab1
    WHERE rn = 1 and date(visit_date) <= date(created_at)
    ORDER BY
        amount DESC NULLS LAST,
        visit_date ASC,
        utm_source ASC,
        utm_medium ASC,
        utm_campaign ASC
),

days_tab AS (
    SELECT
        *,
        (created_at - visit_date) AS days_till_lead,
        ntile(10) OVER (ORDER BY (created_at - visit_date)) AS ntl
    FROM last_paid_click
    WHERE status_id = 142
)

SELECT max(days_till_lead) as days_90_percent_leads_closed
FROM days_tab
WHERE ntl = 9;


-- Есть ли заметная корреляция между запуском рекламной компании
-- и ростом органики?

WITH ads_tab AS (
    SELECT
        date(campaign_date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    FROM ya_ads
    UNION
    SELECT
        date(campaign_date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    FROM vk_ads
    ORDER BY campaign_date
),

campaigns_count AS (
    SELECT
        date(campaign_date) AS campaign_date,
        count(utm_campaign) AS campaigns_cnt
    FROM ads_tab
    GROUP BY date(campaign_date)
)

SELECT
    cc.campaign_date,
    cc.campaigns_cnt,
    count(DISTINCT s.visitor_id) AS organic_visitors_cnt
FROM sessions AS s
JOIN campaigns_count AS cc
    ON
        date(s.visit_date) = cc.campaign_date AND s.medium = 'organic'
GROUP BY
	cc.campaign_date,
    cc.campaigns_cnt;

