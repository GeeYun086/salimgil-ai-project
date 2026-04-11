USE DATABASE HACKATHON_DB;
USE SCHEMA HACKATHON_DM;

//사용자 입력 기반 분류 로직
WITH user_input AS (
    SELECT
        '{{REGION_NAME}}' AS REGION_NAME,
        '{{HOUSEHOLD_TYPE}}' AS HOUSEHOLD_TYPE,
        '{{BUDGET_TIER}}' AS BUDGET_TIER,
        '{{HAS_CHILD}}' AS HAS_CHILD,
        '{{PRIORITY_FOCUS}}' AS PRIORITY_FOCUS
),
classification AS (
    SELECT
        HOUSEHOLD_TYPE,
        BUDGET_TIER,
        CONCAT(
            '사용자 입력 기준 가구형태는 ',
            HOUSEHOLD_TYPE,
            ', 예산등급은 ',
            BUDGET_TIER,
            ', 자녀 여부는 ',
            CASE WHEN HAS_CHILD = 'Y' THEN '있음' ELSE '없음' END,
            '이며, 지역 ',
            REGION_NAME,
            '의 최근 소비·소득 특성을 함께 반영했습니다.'
        ) AS CLASSIFICATION_REASON
    FROM user_input
)
SELECT *
FROM classification;