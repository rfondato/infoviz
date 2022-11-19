COPY (
  SELECT 
    datetrunc('month', timestamp) as month, 
    participantId :: INT as participantId, 
    MAX(apartmentId):: INT as apartmentId, 
    MAX(jobId):: INT as jobId, 
    AVG(availableBalance) monthlyAvgBalance, 
    AVG(dailyFoodBudget) * 30 as monthlyFoodBudget, 
    AVG(weeklyExtraBudget) * 4 as monthlyExtraBudget 
  FROM 
    (
      SELECT 
        strptime(timestamp, '%Y-%m-%dT%H:%M:%SZ') as timestamp, 
        participantId, 
        apartmentId, 
        availableBalance, 
        jobId, 
        dailyFoodBudget, 
        weeklyExtraBudget 
      FROM 
        './Datasets/Activity Logs/*.parquet'
    ) 
  GROUP BY 
    1, 
    2 
  ORDER BY 
    1, 
    2 ASC
) TO 'participant_logs_summary.csv' (HEADER, DELIMITER ',');


-----------------------------

COPY (
  SELECT 
    datetrunc('month', timestamp) as month, 
    AVG(availableBalance) monthlyAvgBalance, 
    AVG(dailyFoodBudget) * 30 as monthlyFoodBudget, 
    AVG(weeklyExtraBudget) * 4 as monthlyExtraBudget 
  FROM 
    (
      SELECT 
        strptime(timestamp, '%Y-%m-%dT%H:%M:%SZ') as timestamp, 
        availableBalance, 
        dailyFoodBudget, 
        weeklyExtraBudget 
      FROM 
        './Datasets/Activity Logs/*.parquet'
    ) 
  GROUP BY 
    1 
  ORDER BY 
    1 ASC
) TO 'monthly_summary.csv' (HEADER, DELIMITER ',');

---------------------------------

CREATE TEMP TABLE clusters AS 
SELECT 
  DISTINCT participantId, 
  Cluster 
FROM 
  'participant_clusters.csv' 
WHERE 
  Cluster is not null;
  
CREATE TEMP TABLE t1 AS 
SELECT 
  strptime(timestamp, '%Y-%m-%dT%H:%M:%SZ') as timestamp, 
  participantId :: INT as participantId, 
  regexp_replace(
    currentLocation, '^[^\d\-]*(-?\d+\.?\d*)\s+(-?\d+\.?\d*)[^\d]*$', 
    '\1'
  ):: INT as loc_x, 
  regexp_replace(
    currentLocation, '^[^\d\-]*(-?\d+\.?\d*)\s+(-?\d+\.?\d*)[^\d]*$', 
    '\2'
  ):: INT as loc_y, 
  availableBalance 
FROM 
  './Datasets/Activity Logs/*.parquet' 
WHERE 
  regexp_matches(
    currentLocation, '^[^\d\-]*(-?\d+\.?\d*)\s+(-?\d+\.?\d*)[^\d]*$'
  ) USING SAMPLE 10 %;
  
CREATE TEMP TABLE details AS 
SELECT 
  t.timestamp, 
  t.participantId, 
  t.loc_x, 
  t.loc_y, 
  t.availableBalance, 
  c.Cluster 
FROM 
  t1 t 
  INNER JOIN clusters c ON (
    t.participantId = c.participantId
  );
CREATE TEMP TABLE monthly_sum AS 
SELECT 
  datetrunc('month', timestamp) as month, 
  loc_x, 
  loc_y, 
  AVG(availableBalance) as money, 
  MODE(Cluster) as cluster 
FROM 
  details 
GROUP BY 
  1, 
  2, 
  3;
  
CREATE TEMP TABLE part_size AS 
SELECT 
  datetrunc('month', timestamp) as month, 
  loc_x / 10 :: INT as loc_x, 
  loc_y / 10 :: INT as loc_y, 
  COUNT(DISTINCT participantId) as part_count 
FROM 
  t1 
GROUP BY 
  1, 
  2, 
  3;
  
CREATE TEMP TABLE final_Table AS 
SELECT 
  m.month, 
  m.loc_x, 
  m.loc_y, 
  AVG(m.money) as money, 
  MODE(m.Cluster) as cluster, 
  SUM(part_count) as part_count 
FROM 
  monthly_sum m 
  INNER JOIN part_size p ON (
    m.month = p.month 
    AND (m.loc_x / 10 :: INT) = p.loc_x 
    AND (m.loc_y / 10 :: INT) = p.loc_y
  ) 
GROUP BY 
  m.month, 
  m.loc_x, 
  m.loc_y;
  
COPY (
  SELECT 
    * 
  from 
    final_Table
) TO 'monthly_map2.csv' (HEADER, DELIMITER ',');


--------------- SEGUNDA PARTE -----------------------

CREATE TEMP TABLE logs AS 
SELECT 
  * 
FROM 
  './ActivityLogs/*.parquet';
  
CREATE TEMP TABLE participants AS 
SELECT 
  * 
FROM 
  './Attributes/Participants.csv';
  
CREATE TEMP TABLE buildings AS 
SELECT 
  * 
FROM 
  './Attributes/Buildings.csv';
  
CREATE TEMP TABLE pubs AS 
SELECT 
  * 
FROM 
  './Attributes/Pubs.csv';
  
CREATE TEMP TABLE schools AS 
SELECT 
  * 
FROM 
  './Attributes/Schools.csv';
  
CREATE TEMP TABLE restaurants AS 
SELECT 
  * 
FROM 
  './Attributes/Restaurants.csv';
  
CREATE TEMP TABLE apartments AS 
SELECT 
  * 
FROM 
  './Attributes/Apartments.csv';
  
CREATE TEMP TABLE checkin AS 
SELECT 
  * 
FROM 
  './Journals/CheckinJournal.csv';
  
CREATE TEMP TABLE financial AS 
SELECT 
  * 
FROM 
  './Journals/FinancialJournal.csv';
  
CREATE TEMP TABLE logs2 AS 
select 
  distinct array_slice(timestamp, 1, 10) as date, 
  array_slice(timestamp, 12, 13) as hour, 
  array_slice(timestamp, 15, 16) as minute, 
  currentMode, 
  hungerStatus, 
  sleepStatus, 
  participantID 
from 
  logs;
  
CREATE TEMP TABLE participants2 AS 
select 
  participantID, 
  case when age < 13 then 'Children (0-12 years)' when age between 13 
  and 18 then 'Teenagers (13-18 years)' when age between 19 
  and 29 then 'Young Adults (19-29 years)' when age between 30 
  and 39 then 'Adults (30-39 years)' when age between 40 
  and 49 then 'Middle-Age Adults (40-49 years)' when age between 50 
  and 64 then 'Late Adults (50-64 years)' else 'Old Adults (>=65 years)' end as age_group, 
  educationLevel, 
  interestGroup, 
  case when joviality < 0.25 then 'Very Sad (0-0.24 joviality)' when joviality >= 0.25 
  and joviality < 0.5 then 'Sad (0.25-0.49 joviality)' when joviality >= 0.5 
  and joviality < 0.75 then 'Content (0.5-0.74 joviality)' else 'Happy (0.75 <= joviality)' end as happiness_level 
from 
  participants;
  
CREATE TEMP TABLE financial2 AS 
select 
  datepart('hour', timestamp) as hour, 
  age_group, 
  happiness_level, 
  educationLevel, 
  interestGroup, 
  category, 
  sum(amount)/(
    count(
      distinct make_date(
        datepart('year', timestamp), 
        datepart('month', timestamp), 
        datepart('day', timestamp)
      )
    )* count(
      distinct financial.participantID
    )
  ) as daily_amount 
from 
  financial 
  left join participants2 on financial.participantID = participants2.participantID 
group by 
  1, 
  2, 
  3, 
  4, 
  5, 
  6;
  
CREATE TEMP TABLE financial3 AS 
select 
  datepart('month', timestamp) as month, 
  age_group, 
  happiness_level, 
  educationLevel, 
  interestGroup, 
  category, 
  sum(amount)/(
    count(
      distinct make_date(
        datepart('year', timestamp), 
        datepart('month', timestamp), 
        datepart('day', timestamp)
      )
    )* count(
      distinct financial.participantID
    )
  ) as daily_amount 
from 
  financial 
  left join participants2 on financial.participantID = participants2.participantID 
group by 
  1, 
  2, 
  3, 
  4, 
  5, 
  6;
  
CREATE TEMP TABLE checkin2 AS 
select 
  datepart('hour', timestamp) as hour, 
  age_group, 
  happiness_level, 
  educationLevel, 
  interestGroup, 
  venueType, 
  count(*)/(
    count(
      distinct make_date(
        datepart('year', timestamp), 
        datepart('month', timestamp), 
        datepart('day', timestamp)
      )
    )* count(distinct checkin.participantID)
  ) as daily_count 
from 
  checkin 
  left join participants2 on checkin.participantID = participants2.participantID 
group by 
  1, 
  2, 
  3, 
  4, 
  5, 
  6;
  
CREATE TEMP TABLE checkin3 AS 
select 
  datepart('month', timestamp) as month, 
  age_group, 
  happiness_level, 
  educationLevel, 
  interestGroup, 
  venueType, 
  count(*)/(
    count(
      distinct make_date(
        datepart('year', timestamp), 
        datepart('month', timestamp), 
        datepart('day', timestamp)
      )
    )* count(distinct checkin.participantID)
  ) as daily_count 
from 
  checkin 
  left join participants2 on checkin.participantID = participants2.participantID 
group by 
  1, 
  2, 
  3, 
  4, 
  5, 
  6;
  
COPY (
  select 
    * 
  from 
    financial2
) TO 'financial_hour.csv' (HEADER, DELIMITER ',');
COPY (
  select 
    * 
  from 
    financial3
) TO 'financial_month.csv' (HEADER, DELIMITER ',');
COPY (
  select 
    * 
  from 
    checkin2
) TO 'checkin_hour.csv' (HEADER, DELIMITER ',');
COPY (
  select 
    * 
  from 
    checkin3
) TO 'checkin_month.csv' (HEADER, DELIMITER ',');
