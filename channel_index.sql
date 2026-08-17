WITH RankedData AS (
    -- 给观看次数排序，并计算总行数
    SELECT 
        观看次数,
        ROW_NUMBER() OVER (ORDER BY 观看次数) AS rn,
        COUNT(*) OVER () AS total_count
    FROM content_table
    WHERE 观看次数 IS NOT NULL
),
MedianData AS (
    -- 计算中位数
    SELECT AVG(观看次数) AS median_watch
    FROM RankedData
    WHERE rn IN (FLOOR((total_count + 1) / 2), CEIL((total_count + 1) / 2))
),
BaseStats AS (
    -- 统计指标
    SELECT 
        COUNT(视频标题) AS total_video,
        SUM(观看次数) AS total_watch, 
        AVG(观看次数) AS avg_watch,
        MAX(观看次数) AS max_watch,
        MIN(观看次数) AS min_watch,
        AVG(`平均观看百分比 (%)`) AS avg_finish,
        MAX(`平均观看百分比 (%)`) AS max_finish,
        MIN(`平均观看百分比 (%)`) AS min_finish,
        (SELECT SUM(观看次数) FROM (SELECT 观看次数 FROM content_table ORDER BY 观看次数 DESC LIMIT 10) AS t1) / SUM(观看次数) *100 AS top10_ratio
    FROM content_table
)
-- 把所有指标拼在一起展示
SELECT 
    b.total_video,
    b.total_watch,
    b.avg_watch,
    m.median_watch,
    b.max_watch,
    b.min_watch,
    b.avg_finish,
    b.max_finish,
    b.min_finish,
    b.top10_ratio
FROM BaseStats b
CROSS JOIN MedianData m;

-- top10中最小数字
SELECT MIN(观看次数) FROM (SELECT 观看次数 FROM content_table ORDER BY 观看次数 DESC LIMIT 10) t;

-- 1.对比top10和其余43个vid的完播率
SELECT
    CASE WHEN 观看次数 >= 88801 THEN 'Top10' ELSE 'Other' END AS 分组,
    AVG(`平均观看百分比 (%)`) AS 平均完播率,
    COUNT(*) AS 视频数
FROM content_table
GROUP BY 分组;

-- 长尾效应
SELECT MAX(STR_TO_DATE(视频发布时间, '%e-%b-%y')) FROM content_table;

SELECT
    SUM(CASE WHEN 时间 >= '2017-06' THEN 观看次数 ELSE 0 END) AS 停更后观看,
    SUM(观看次数) AS 全部观看,
    SUM(CASE WHEN 时间 >= '2017-06' THEN 观看次数 ELSE 0 END) / SUM(观看次数) * 100 AS 停更后占比
FROM content_totals;

-- 2.找规律
select 视频标题, 观看次数, `平均观看百分比 (%)`, `视频发布时间y-m` from content_table as ct
order by 观看次数 desc limit 10;

-- 分番剧验证
SELECT
    CASE
        WHEN 视频标题 LIKE '%Pripara%' OR 视频标题 LIKE '%Puripara%' THEN 'Pripara系列'
        WHEN 视频标题 LIKE '%Aikatsu%' THEN 'Aikatsu系列'
        ELSE 'Other'
    END AS 番剧系列,
    COUNT(*) AS 视频数,
    AVG(观看次数) AS 平均观看,
    AVG(`平均观看百分比 (%)`) AS 平均完播率
FROM content_table
GROUP BY 番剧系列
ORDER BY 平均观看 DESC;

-- 两个系列发布时间
SELECT
    CASE
        WHEN 视频标题 LIKE '%Pripara%' OR 视频标题 LIKE '%Puripara%' THEN 'Pripara系列'
        WHEN 视频标题 LIKE '%Aikatsu%' THEN 'Aikatsu系列'
        ELSE 'Other'
    END AS 番剧系列,
    MIN(`视频发布时间y-m`) AS 最早发布,
    MAX(`视频发布时间y-m`) AS 最晚发布,
    COUNT(*) AS 视频数
FROM content_table
GROUP BY 番剧系列;

-- 频道地区分析
SELECT
    视频标题,
    观看次数,
    `平均观看百分比 (%)`,
    `视频发布时间y-m`
FROM content_table
WHERE 视频标题 LIKE '%Aikatsu%'
ORDER BY `视频发布时间y-m` ASC;

select `地理位置`,`观看次数`,`观看次数`/(select sum(`观看次数`) from geography_table_data)*100 as `占比（%）`
from geography_table_data
order by `观看次数` desc

SELECT 
    CASE 
        WHEN `观看次数` >= 45160 THEN 'Top10' 
        ELSE 'Other' 
    END AS `地区分类`,
    SUM(`观看次数`) / (SELECT SUM(`观看次数`) FROM geography_table_data) * 100 AS `占比（%）`
FROM geography_table_data
GROUP BY `地区分类`;

-- 分类表
SELECT 
    CASE 
        WHEN `地理位置` NOT IN ('US', 'FR') THEN 'Asia' 
        ELSE 'Other' 
    END AS `地区分类`,
    SUM(`观看次数`) / (SELECT SUM(`观看次数`) FROM geography_table_data) * 100 AS `占比（%）`
FROM geography_table_data
GROUP BY `地区分类`;

-- 国际化传播
SELECT
    CASE WHEN 地理位置 IN ('JP','KR','ID','VN','HK','TW','TH','MY','PH','SG','IN','CN','MO','MN','KH','LA','MM','BN','PK','NP','KZ','KG','AM','AZ','GE')
         THEN '亚洲' ELSE '非亚洲' END AS 大洲分组,
    SUM(观看次数) AS 观看次数,
    SUM(观看次数) / (SELECT SUM(观看次数) FROM geography_table_data WHERE 地理位置 != '总计') * 100 AS 占比
FROM geography_table_data
WHERE 地理位置 != '总计'
GROUP BY 大洲分组;

-- 推流相关分析
select 流量来源,观看次数,观看次数/(select sum(观看次数) from traffic_table)*100 as `占比（%）`
from traffic_table 
order by 观看次数 desc

-- 分类表
SELECT 
    CASE 
        WHEN `流量来源` IN ('推荐视频', '浏览功能') THEN '算法推荐'
        WHEN `流量来源` = 'YouTube 搜索' THEN '主动搜索'
        WHEN `流量来源` = '播放列表' THEN '播放列表'
        ELSE 'Other'
    END AS `流量大类`,
    SUM(`观看次数`) / (SELECT SUM(`观看次数`) FROM traffic_table) * 100 AS `占比（%）`
FROM traffic_table
GROUP BY `流量大类`;
	
	