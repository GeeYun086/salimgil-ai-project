USE DATABASE HACKATHON_DB;
USE SCHEMA HACKATHON_DM;

//체크리스트 추천 로직
//기존 룰 테이블 기반 추천 대신, 사용자 입력 + 지역 분석 + 렌탈 분석 결과를 넣고 LLM이 체크리스트를 생성하는 최종 버전
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
rental_candidates AS (
    SELECT
        LISTAGG(
            CONCAT(
                RENTAL_SUB_CATEGORY,
                ' / 대분류:', RENTAL_MAIN_CATEGORY,
                ' / 계약수:', CONTRACT_COUNT,
                ' / 참고가격:', AVG_NET_SALES
            ),
            '\n'
        ) AS RENTAL_CANDIDATES
    FROM VW_RENTAL_RECOMMENDATION_SCORE
    WHERE REGION_NAME = (SELECT REGION_NAME FROM user_input)
      AND YEAR_MONTH = (
          SELECT MAX(YEAR_MONTH)
          FROM VW_RENTAL_RECOMMENDATION_SCORE
          WHERE REGION_NAME = (SELECT REGION_NAME FROM user_input)
      )
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
                COALESCE((SELECT RENTAL_CANDIDATES FROM rental_candidates), '없음'), '. ',

                '출력 예시는 다음 형식이어야 한다: ',
                '{"checklist":[{"stage":"지금 바로","item_name":"...","category":"...","reason":"..."}]}'
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
)
SELECT
    AI_RESULT:value:checklist AS CHECKLIST_JSON,
    AI_RESULT:error AS ERROR_INFO
FROM checklist_raw;