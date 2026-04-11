USE DATABASE HACKATHON_DB;
USE SCHEMA HACKATHON_DM;

// 렌탈가전 추천 쿼리 (분류 결과 + 지역/월의 상위 렌탈 후보를 이용해 추천을 생성)
// 수정사항:
// 1) expected_price → reference_price
// 2) 프롬프트에도 “월 렌탈료가 아니라 참고 가격 지표”라고 명시
// 3) 후보 3개만 사용
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
rental_pool AS (
    SELECT
        RENTAL_MAIN_CATEGORY,
        RENTAL_SUB_CATEGORY,
        AVG_NET_SALES,
        AVG_POLICY_AMOUNT,
        RN
    FROM VW_LLM_RENTAL_CANDIDATES
    WHERE REGION_ID = (SELECT REGION_ID FROM base)
      AND YEAR_MONTH = (SELECT YEAR_MONTH FROM base)
      AND RN <= 3
),
rental_candidates AS (
    SELECT
        COALESCE(
            LISTAGG(
                CONCAT(
                    COALESCE(RENTAL_MAIN_CATEGORY, ''), ' / ',
                    COALESCE(RENTAL_SUB_CATEGORY, ''), ' / 평균계약금액지표:',
                    COALESCE(TO_VARCHAR(AVG_NET_SALES), '0'), ' / 정책금액:',
                    COALESCE(TO_VARCHAR(AVG_POLICY_AMOUNT), '0')
                ),
                '\n'
            ),
            '렌탈 후보 없음'
        ) AS RENTAL_CANDIDATES
    FROM rental_pool
),
recommend_raw AS (
    SELECT
        AI_COMPLETE(
            model => 'claude-sonnet-4-5',
            prompt => CONCAT(
                '너는 렌탈가전 추천 AI다. ',
                '반드시 JSON으로만 답해라. ',
                '아래 렌탈 후보 중에서만 최대 3개를 추천해라. ',
                '반드시 후보에 없는 제품은 만들지 마라. ',
                'reference_price는 월 렌탈료가 아니라 평균 계약 금액 기반 참고 지표다. ',
                '각 항목마다 main_category, sub_category, reason, reference_price를 작성해라. ',
                '분류 결과 household_type: ', COALESCE((SELECT HOUSEHOLD_TYPE FROM classification), '정보없음'), ', ',
                'budget_tier: ', COALESCE((SELECT BUDGET_TIER FROM classification), '정보없음'), '. ',
                '분류 사유: ', COALESCE((SELECT CLASSIFICATION_REASON FROM classification), '정보없음'), '. ',
                '렌탈 후보: ',
                COALESCE((SELECT RENTAL_CANDIDATES FROM rental_candidates), '후보 없음')
            ),
            model_parameters => {'temperature': 0},
            response_format => {
                'type': 'json',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'rental_recommendations': {
                            'type': 'array',
                            'items': {
                                'type': 'object',
                                'properties': {
                                    'main_category': {'type': 'string'},
                                    'sub_category': {'type': 'string'},
                                    'reason': {'type': 'string'},
                                    'reference_price': {'type': 'number'}
                                },
                                'required': ['main_category', 'sub_category', 'reason', 'reference_price']
                            }
                        }
                    },
                    'required': ['rental_recommendations']
                }
            },
            return_error_details => TRUE
        ) AS AI_RESULT
)
SELECT
    (SELECT HOUSEHOLD_TYPE FROM classification) AS HOUSEHOLD_TYPE,
    (SELECT BUDGET_TIER FROM classification) AS BUDGET_TIER,
    AI_RESULT:value:rental_recommendations AS RENTAL_JSON,
    AI_RESULT:error AS ERROR_INFO
FROM recommend_raw;