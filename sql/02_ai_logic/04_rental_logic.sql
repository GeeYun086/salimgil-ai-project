USE DATABASE HACKATHON_DB;
USE SCHEMA HACKATHON_DM;

//렌탈 점수 계산 로직
WITH user_input AS (
    SELECT
        '{{REGION_NAME}}' AS REGION_NAME,
        '{{HOUSEHOLD_TYPE}}' AS HOUSEHOLD_TYPE,
        '{{BUDGET_TIER}}' AS BUDGET_TIER,
        '{{HAS_CHILD}}' AS HAS_CHILD,
        '{{PRIORITY_FOCUS}}' AS PRIORITY_FOCUS
),
rental_base AS (
    SELECT *
    FROM VW_RENTAL_RECOMMENDATION_SCORE
    WHERE REGION_NAME = (SELECT REGION_NAME FROM user_input)
      AND YEAR_MONTH = (
          SELECT MAX(YEAR_MONTH)
          FROM VW_RENTAL_RECOMMENDATION_SCORE
          WHERE REGION_NAME = (SELECT REGION_NAME FROM user_input)
      )
),
rental_scored AS (
    SELECT
        b.*,

        CASE
            WHEN (SELECT BUDGET_TIER FROM user_input) = 'BASIC' AND PRICE_LEVEL = 'LOW' THEN 30
            WHEN (SELECT BUDGET_TIER FROM user_input) = 'BASIC' AND PRICE_LEVEL = 'MID' THEN 15
            WHEN (SELECT BUDGET_TIER FROM user_input) = 'BASIC' AND PRICE_LEVEL = 'HIGH' THEN 5

            WHEN (SELECT BUDGET_TIER FROM user_input) = 'MID' AND PRICE_LEVEL = 'LOW' THEN 20
            WHEN (SELECT BUDGET_TIER FROM user_input) = 'MID' AND PRICE_LEVEL = 'MID' THEN 30
            WHEN (SELECT BUDGET_TIER FROM user_input) = 'MID' AND PRICE_LEVEL = 'HIGH' THEN 15

            WHEN (SELECT BUDGET_TIER FROM user_input) = 'PREMIUM' AND PRICE_LEVEL = 'LOW' THEN 10
            WHEN (SELECT BUDGET_TIER FROM user_input) = 'PREMIUM' AND PRICE_LEVEL = 'MID' THEN 20
            WHEN (SELECT BUDGET_TIER FROM user_input) = 'PREMIUM' AND PRICE_LEVEL = 'HIGH' THEN 30
            ELSE 0
        END AS BUDGET_SCORE,

        CASE
            WHEN (SELECT PRIORITY_FOCUS FROM user_input) = '위생/건강'
                 AND RENTAL_SUB_CATEGORY IN ('정수기', '공기청정기', '비데') THEN 30
            WHEN (SELECT PRIORITY_FOCUS FROM user_input) = '편의성'
                 AND RENTAL_SUB_CATEGORY IN ('세탁기', '스타일러', '건조기') THEN 30
            WHEN (SELECT PRIORITY_FOCUS FROM user_input) = '비용절감'
                 AND RENTAL_SUB_CATEGORY IN ('정수기', '비데') THEN 20
            WHEN (SELECT PRIORITY_FOCUS FROM user_input) = '육아/가족'
                 AND RENTAL_SUB_CATEGORY IN ('정수기', '공기청정기', '세탁기') THEN 30
            ELSE 5
        END AS PRIORITY_SCORE,

        CASE
            WHEN (SELECT HAS_CHILD FROM user_input) = 'Y'
                 AND RENTAL_SUB_CATEGORY IN ('정수기', '공기청정기', '세탁기') THEN 20
            WHEN (SELECT HAS_CHILD FROM user_input) = 'N'
                 AND RENTAL_SUB_CATEGORY IN ('비데', '공기청정기', '정수기') THEN 10
            ELSE 0
        END AS CHILD_SCORE
    FROM rental_base b
),
rental_final AS (
    SELECT
        *,
        DEMAND_SCORE + BUDGET_SCORE + PRIORITY_SCORE + CHILD_SCORE AS FINAL_SCORE,
        CASE
            WHEN DEMAND_SCORE + BUDGET_SCORE + PRIORITY_SCORE + CHILD_SCORE >= 80 THEN '추천'
            WHEN DEMAND_SCORE + BUDGET_SCORE + PRIORITY_SCORE + CHILD_SCORE >= 55 THEN '고려 가능'
            ELSE '보류'
        END AS RECOMMENDATION_LEVEL
    FROM rental_scored
),
rental_top AS (
    SELECT *
    FROM rental_final
    ORDER BY FINAL_SCORE DESC, CONTRACT_COUNT DESC
    LIMIT 5
)
SELECT
    RENTAL_MAIN_CATEGORY,
    RENTAL_SUB_CATEGORY,
    CONTRACT_COUNT,
    AVG_NET_SALES,
    DEMAND_SCORE,
    BUDGET_SCORE,
    PRIORITY_SCORE,
    CHILD_SCORE,
    FINAL_SCORE,
    RECOMMENDATION_LEVEL
FROM rental_top
ORDER BY FINAL_SCORE DESC, CONTRACT_COUNT DESC;