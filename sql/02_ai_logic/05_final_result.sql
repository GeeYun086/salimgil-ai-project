USE DATABASE HACKATHON_DB;
USE SCHEMA HACKATHON_DM;

//사용자 입력 기반 최종 결과 로직
WITH user_input AS (
    SELECT
        '{{REGION_NAME}}' AS REGION_NAME,
        '{{HOUSEHOLD_TYPE}}' AS HOUSEHOLD_TYPE,
        '{{BUDGET_TIER}}' AS BUDGET_TIER,
        '{{HAS_CHILD}}' AS HAS_CHILD,
        '{{PRIORITY_FOCUS}}' AS PRIORITY_FOCUS
),
base AS (
    SELECT *
    FROM VW_LLM_PROFILE_INPUT
    WHERE REGION_NAME = (SELECT REGION_NAME FROM user_input)
    ORDER BY YEAR_MONTH DESC
    LIMIT 1
),
classification AS (
    SELECT
        (SELECT HOUSEHOLD_TYPE FROM user_input) AS HOUSEHOLD_TYPE,
        (SELECT BUDGET_TIER FROM user_input) AS BUDGET_TIER,
        CONCAT(
            '사용자 입력 기준 가구형태는 ',
            (SELECT HOUSEHOLD_TYPE FROM user_input),
            ', 예산등급은 ',
            (SELECT BUDGET_TIER FROM user_input),
            ', 자녀 여부는 ',
            CASE WHEN (SELECT HAS_CHILD FROM user_input) = 'Y' THEN '있음' ELSE '없음' END,
            '이며, 지역 ',
            (SELECT REGION_NAME FROM user_input),
            '의 최근 소비·소득 특성을 함께 반영했습니다.'
        ) AS CLASSIFICATION_REASON
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
),
rental_candidates AS (
    SELECT
        LISTAGG(
            CONCAT(
                RENTAL_SUB_CATEGORY,
                ' / 대분류:', RENTAL_MAIN_CATEGORY,
                ' / 추천단계:', RECOMMENDATION_LEVEL,
                ' / 최종점수:', FINAL_SCORE,
                ' / 계약수:', CONTRACT_COUNT,
                ' / 참고가격:', AVG_NET_SALES
            ),
            '\n'
        ) AS RENTAL_CANDIDATES
    FROM rental_top
),
rental_json AS (
    SELECT
        ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'main_category', RENTAL_MAIN_CATEGORY,
                'sub_category', RENTAL_SUB_CATEGORY,
                'reference_price', AVG_NET_SALES,
                'contract_count', CONTRACT_COUNT,
                'demand_score', DEMAND_SCORE,
                'budget_score', BUDGET_SCORE,
                'priority_score', PRIORITY_SCORE,
                'child_score', CHILD_SCORE,
                'final_score', FINAL_SCORE,
                'recommendation_level', RECOMMENDATION_LEVEL
            )
        ) WITHIN GROUP (ORDER BY FINAL_SCORE DESC, CONTRACT_COUNT DESC) AS RENTAL_RECOMMENDATIONS
    FROM rental_top
),

checklist_raw AS (
    SELECT
        AI_COMPLETE(
            model => 'claude-sonnet-4-5',
            prompt => CONCAT(
                '너는 개인화 이사 준비 도우미 AI다. ',
                '반드시 JSON으로만 답해라. ',
                '체크리스트는 사용자의 실제 행동 계획이 되도록 구체적으로 작성해라. ',
                '절대 너무 일반적인 표현만 반복하지 마라. ',
                '반드시 다음 4개 stage만 사용해라: 지금 바로, 이사 전, 입주 직후, 선택 항목. ',
                '각 항목은 stage, item_name, category, reason을 포함해야 한다. ',
                '최대 10개 항목만 생성해라. ',
                '사용자 입력과 지역 데이터 분석 결과, 렌탈 추천 분석 결과를 함께 반영해라. ',

                '사용자 조건: ',
                '지역=', COALESCE((SELECT REGION_NAME FROM user_input), '정보없음'), ', ',
                '가구형태=', COALESCE((SELECT HOUSEHOLD_TYPE FROM user_input), '정보없음'), ', ',
                '예산등급=', COALESCE((SELECT BUDGET_TIER FROM user_input), '정보없음'), ', ',
                '자녀여부=', COALESCE((SELECT HAS_CHILD FROM user_input), '정보없음'), ', ',
                '우선순위=', COALESCE((SELECT PRIORITY_FOCUS FROM user_input), '정보없음'), '. ',

                '지역 분석 데이터: ',
                '평균가구소득=', COALESCE(TO_VARCHAR((SELECT AVG_HOUSEHOLD_INCOME FROM base)), '0'), ', ',
                '평균자산=', COALESCE(TO_VARCHAR((SELECT AVG_ASSET_AMOUNT FROM base)), '0'), ', ',
                '식품소비=', COALESCE(TO_VARCHAR((SELECT FOOD_SALES FROM base)), '0'), ', ',
                '생활서비스소비=', COALESCE(TO_VARCHAR((SELECT HOME_LIFE_SERVICE_SALES FROM base)), '0'), ', ',
                '가전가구소비=', COALESCE(TO_VARCHAR((SELECT ELECTRONICS_FURNITURE_SALES FROM base)), '0'), ', ',
                '이커머스소비=', COALESCE(TO_VARCHAR((SELECT E_COMMERCE_SALES FROM base)), '0'), '. ',

                '렌탈 분석 결과: ',
                COALESCE((SELECT RENTAL_CANDIDATES FROM rental_candidates), '없음'), '. '
            ),
            model_parameters => {'temperature': 0.2},
            response_format => {
                'type': 'json',
                'schema': {
                    'type': 'object',
                    'properties': {
                        'checklist': {
                            'type': 'array',
                            'items': {
                                'type': 'object',
                                'properties': {
                                    'stage': {'type': 'string'},
                                    'item_name': {'type': 'string'},
                                    'category': {'type': 'string'},
                                    'reason': {'type': 'string'}
                                },
                                'required': ['stage', 'item_name', 'category', 'reason']
                            }
                        }
                    },
                    'required': ['checklist']
                }
            },
            return_error_details => TRUE
        ) AS AI_RESULT
),
checklist_json AS (
    SELECT
        AI_RESULT:value:checklist AS CHECKLIST
    FROM checklist_raw
)

SELECT
    OBJECT_CONSTRUCT(
        'household_type', (SELECT HOUSEHOLD_TYPE FROM classification),
        'budget_tier', (SELECT BUDGET_TIER FROM classification),
        'classification_reason', (SELECT CLASSIFICATION_REASON FROM classification),
        'checklist', (SELECT CHECKLIST FROM checklist_json),
        'rental_recommendations', (SELECT RENTAL_RECOMMENDATIONS FROM rental_json)
    ) AS FINAL_RESULT;