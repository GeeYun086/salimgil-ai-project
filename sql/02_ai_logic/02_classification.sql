USE DATABASE HACKATHON_DB;
USE SCHEMA HACKATHON_DM;

// 분류 쿼리 (household_type, budget_tier, reason을 JSON으로 안정적으로 뽑는 쿼리)
WITH base AS (
    SELECT *
    FROM VW_LLM_PROFILE_INPUT
    WHERE REGION_NAME = '서초구'
    ORDER BY YEAR_MONTH DESC
    LIMIT 1
),
llm_raw AS (
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
                '기준월: ', COALESCE(TO_VARCHAR((SELECT YEAR_MONTH FROM base)), '정보없음'), ', ',
                '평균소득: ', COALESCE(TO_VARCHAR((SELECT AVG_INCOME FROM base)), '0'), ', ',
                '평균가구소득: ', COALESCE(TO_VARCHAR((SELECT AVG_HOUSEHOLD_INCOME FROM base)), '0'), ', ',
                '평균자산: ', COALESCE(TO_VARCHAR((SELECT AVG_ASSET_AMOUNT FROM base)), '0'), ', ',
                '고소득비율: ', COALESCE(TO_VARCHAR((SELECT RATE_HIGHEND FROM base)), '0'), ', ',
                '평균매매가: ', COALESCE(TO_VARCHAR((SELECT AVG_MEME_PRICE_PER_SUPPLY_PYEONG FROM base)), '0'), ', ',
                '평균전세가: ', COALESCE(TO_VARCHAR((SELECT AVG_JEONSE_PRICE_PER_SUPPLY_PYEONG FROM base)), '0'), ', ',
                '영유아비율: ', COALESCE(TO_VARCHAR((SELECT AGE_UNDER5_PER_FEMALE_20TO40 FROM base)), '0'), ', ',
                '식품소비: ', COALESCE(TO_VARCHAR((SELECT FOOD_SALES FROM base)), '0'), ', ',
                '생활서비스소비: ', COALESCE(TO_VARCHAR((SELECT HOME_LIFE_SERVICE_SALES FROM base)), '0'), ', ',
                '가전가구소비: ', COALESCE(TO_VARCHAR((SELECT ELECTRONICS_FURNITURE_SALES FROM base)), '0'), ', ',
                '대형마트소비: ', COALESCE(TO_VARCHAR((SELECT LARGE_DISCOUNT_STORE_SALES FROM base)), '0'), ', ',
                '소매점소비: ', COALESCE(TO_VARCHAR((SELECT SMALL_RETAIL_STORE_SALES FROM base)), '0'), ', ',
                '이커머스소비: ', COALESCE(TO_VARCHAR((SELECT E_COMMERCE_SALES FROM base)), '0')
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
)
SELECT
    AI_RESULT,
    AI_RESULT:value:household_type::STRING AS HOUSEHOLD_TYPE,
    AI_RESULT:value:budget_tier::STRING AS BUDGET_TIER,
    AI_RESULT:value:reason::STRING AS REASON,
    AI_RESULT:error AS ERROR_INFO
FROM llm_raw;