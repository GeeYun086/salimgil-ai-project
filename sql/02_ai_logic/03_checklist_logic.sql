USE DATABASE HACKATHON_DB;
USE SCHEMA HACKATHON_DM;

// 체크리스트 추천 쿼리 (fallback, llm 대신 sql에서 후보 정해지도록 수정 적용)
WITH base AS (
    SELECT *
    FROM VW_LLM_PROFILE_INPUT
    WHERE REGION_NAME = '서초구'
    ORDER BY YEAR_MONTH DESC
    LIMIT 1
),
classification_raw AS (
    SELECT
        AI_COMPLETE(
            model => 'claude-sonnet-4-5',
            prompt => CONCAT(
                '너는 개인화 이사 도우미 AI다. ',
                '반드시 JSON으로만 답해라. ',
                'household_type은 [1인가구형, 신혼/예비부부형, 육아가구형, 일반가족형] 중 하나다. ',
                'budget_tier는 [BASIC, MID, PREMIUM] 중 하나다. ',
                'reason은 한 문장으로 작성해라. ',
                '지역명: ', COALESCE((SELECT REGION_NAME FROM base), '정보없음'), ', ',
                '평균가구소득: ', COALESCE(TO_VARCHAR((SELECT AVG_HOUSEHOLD_INCOME FROM base)), '0'), ', ',
                '평균자산: ', COALESCE(TO_VARCHAR((SELECT AVG_ASSET_AMOUNT FROM base)), '0'), ', ',
                '영유아비율: ', COALESCE(TO_VARCHAR((SELECT AGE_UNDER5_PER_FEMALE_20TO40 FROM base)), '0'), ', ',
                '가전가구소비: ', COALESCE(TO_VARCHAR((SELECT ELECTRONICS_FURNITURE_SALES FROM base)), '0'), ', ',
                '식품소비: ', COALESCE(TO_VARCHAR((SELECT FOOD_SALES FROM base)), '0')
            ),
            model_parameters => {'temperature': 0},
            response_format => {
                'type': 'json',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'household_type': {'type': 'string'},
                        'budget_tier': {'type': 'string'},
                        'reason': {'type': 'string'}
                    },
                    'required': ['household_type', 'budget_tier', 'reason']
                }
            },
            return_error_details => TRUE
        ) AS AI_RESULT
),
classification AS (
    SELECT
        AI_RESULT:value:household_type::STRING AS HOUSEHOLD_TYPE,
        AI_RESULT:value:budget_tier::STRING AS BUDGET_TIER,
        AI_RESULT:value:reason::STRING AS CLASSIFICATION_REASON
    FROM classification_raw
),
strict_candidates AS (
    SELECT
        RULE_ID, ITEM_NAME, PRIORITY, ITEM_CATEGORY, IS_RENTAL_RELATED
    FROM VW_CHECKLIST_RULE_STRICT
    WHERE HOUSEHOLD_TYPE = (SELECT HOUSEHOLD_TYPE FROM classification)
      AND BUDGET_TIER = (SELECT BUDGET_TIER FROM classification)
),
fallback_candidates AS (
    SELECT
        RULE_ID, ITEM_NAME, PRIORITY, ITEM_CATEGORY, IS_RENTAL_RELATED
    FROM VW_CHECKLIST_RULE_STRICT
    WHERE HOUSEHOLD_TYPE = (SELECT HOUSEHOLD_TYPE FROM classification)
),
selected_candidates AS (
    SELECT * FROM strict_candidates
    UNION ALL
    SELECT * FROM fallback_candidates
    WHERE NOT EXISTS (SELECT 1 FROM strict_candidates)
)
SELECT
    (SELECT HOUSEHOLD_TYPE FROM classification) AS HOUSEHOLD_TYPE,
    (SELECT BUDGET_TIER FROM classification) AS BUDGET_TIER,
    (SELECT CLASSIFICATION_REASON FROM classification) AS CLASSIFICATION_REASON,
    ARRAY_AGG(
        OBJECT_CONSTRUCT(
            'item_name', ITEM_NAME,
            'priority', PRIORITY,
            'category', ITEM_CATEGORY,
            'is_rental_related', IS_RENTAL_RELATED
        )
    ) WITHIN GROUP (ORDER BY PRIORITY, RULE_ID) AS CHECKLIST_JSON
FROM selected_candidates;