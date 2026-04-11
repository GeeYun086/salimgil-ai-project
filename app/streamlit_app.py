import streamlit as st
import json
import pandas as pd
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(
    page_title="살림길 - 개인화 이사 도우미",
    page_icon="🏠",
    layout="wide",
)

# -----------------------------
# 스타일
# -----------------------------
st.markdown(
    """
    <style>
    .main {
        padding-top: 1rem;
        padding-bottom: 2rem;
    }
    
    .block-container {
        max-width: 1100px;
        padding-top: 1rem;
        padding-left: 2.2rem;
        padding-right: 2.2rem;
        padding-bottom: 2rem;
    }

    .hero-wrap {
        padding: 1.2rem 1.4rem 1rem 1.4rem;
        border-radius: 24px;
        background: linear-gradient(135deg, #f7f9ff 0%, #eef4ff 100%);
        border: 1px solid rgba(60, 90, 200, 0.10);
        margin-bottom: 1rem;
    }

    .hero-title {
        font-size: 2rem;
        font-weight: 800;
        margin-bottom: 0.2rem;
    }

    .hero-sub {
        color: #5f6470;
        font-size: 1rem;
        margin-bottom: 0;
    }

    .summary-card {
        padding: 1rem 1rem;
        border-radius: 18px;
        background: #ffffff;
        border: 1px solid rgba(0,0,0,0.08);
        box-shadow: 0 4px 18px rgba(0,0,0,0.04);
        height: 100%;
        margin-bottom: 0.8rem;
    }

    .summary-label {
        font-size: 0.82rem;
        color: #6b7280;
        margin-bottom: 0.25rem;
    }

    .summary-value {
        font-size: 1.15rem;
        font-weight: 800;
    }

    .reason-card {
        padding: 1rem 1.1rem;
        border-radius: 18px;
        background: #f7f7fb;
        border: 1px solid rgba(0,0,0,0.06);
        margin-bottom: 1rem;
    }

    .block-card {
        padding: 1rem 1rem;
        border-radius: 20px;
        background: #ffffff;
        border: 1px solid rgba(0,0,0,0.08);
        box-shadow: 0 4px 18px rgba(0,0,0,0.04);
        margin-bottom: 1rem;
    }

    .check-item {
        padding: 0.85rem 0.9rem;
        border-radius: 14px;
        background: #f8fafc;
        border: 1px solid rgba(0,0,0,0.05);
        margin-bottom: 0.7rem;
    }

    .check-title {
        font-weight: 700;
        margin-bottom: 0.2rem;
    }

    .check-meta {
        color: #6b7280;
        font-size: 0.82rem;
        margin-bottom: 0.3rem;
    }

    .rental-card {
        padding: 0.95rem 1rem;
        border-radius: 16px;
        background: #ffffff;
        border: 1px solid rgba(0,0,0,0.08);
        box-shadow: 0 4px 14px rgba(0,0,0,0.04);
        margin-bottom: 0.8rem;
    }

    .rental-title {
        font-size: 1rem;
        font-weight: 800;
        margin-bottom: 0.15rem;
    }

    .rental-sub {
        font-size: 0.84rem;
        color: #6b7280;
        margin-bottom: 0.5rem;
    }

    .badge-reco {
        display:inline-block;
        padding: 0.22rem 0.58rem;
        border-radius: 999px;
        font-size: 0.8rem;
        font-weight: 700;
        background: #e9f8ee;
        color: #127a35;
        border: 1px solid #b9e8c7;
    }

    .badge-consider {
        display:inline-block;
        padding: 0.22rem 0.58rem;
        border-radius: 999px;
        font-size: 0.8rem;
        font-weight: 700;
        background: #fff7e8;
        color: #9a6500;
        border: 1px solid #f1d18f;
    }

    .badge-hold {
        display:inline-block;
        padding: 0.22rem 0.58rem;
        border-radius: 999px;
        font-size: 0.8rem;
        font-weight: 700;
        background: #f1f3f5;
        color: #5c6770;
        border: 1px solid #d9dee3;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

# -----------------------------
# 헤더
# -----------------------------
st.markdown(
    """
    <div class="hero-wrap">
        <div class="hero-title">🏠 살림길</div>
        <p class="hero-sub">
            서울시 3개 구(서초구, 영등포구, 중구)의 지역 데이터와 사용자 조건을 함께 반영해 이사 준비 전략, 개인화 체크리스트,
            렌탈 추천을 한 번에 분석해주는 이사 도우미
        </p>
    </div>
    """,
    unsafe_allow_html=True,
)

# -----------------------------
# 세션 상태
# -----------------------------
if "final_result" not in st.session_state:
    st.session_state.final_result = None
if "rental_df" not in st.session_state:
    st.session_state.rental_df = None
if "profile_df" not in st.session_state:
    st.session_state.profile_df = None
if "trend_profile_df" not in st.session_state:
    st.session_state.trend_profile_df = None
if "trend_rental_df" not in st.session_state:
    st.session_state.trend_rental_df = None

# -----------------------------
# 입력 영역
# -----------------------------
st.markdown("### 입력 조건")

region = st.selectbox(
        "이사 지역",
        ["선택하세요", "서초구", "영등포구", "중구"]
    )

household_type = st.selectbox(
        "가구형태",
        ["선택하세요", "1인가구형", "신혼/예비부부형", "육아가구형", "일반가족형"]
    )

budget_tier = st.selectbox(
        "예산등급",
        ["선택하세요", "BASIC", "MID", "PREMIUM"]
    )

if household_type == "1인가구형":
        has_child = st.selectbox(
            "자녀 여부",
            ["N"],
            disabled=True
        )
else:
        has_child = st.selectbox(
            "자녀 여부",
            ["선택하세요", "Y", "N"]
        )

priority_focus = st.selectbox(
        "우선순위",
        ["선택하세요", "비용절감", "편의성", "위생/건강", "육아/가족"]
    )

btn_left, btn_right = st.columns([8, 1])

with btn_right:
    run_btn = st.button("분석하기", use_container_width=True)

is_input_complete = (
    region != "선택하세요"
    and household_type != "선택하세요"
    and budget_tier != "선택하세요"
    and priority_focus != "선택하세요"
    and has_child != "선택하세요"
)

if not is_input_complete:
    st.session_state.final_result = None
    st.session_state.rental_df = None
    st.session_state.profile_df = None
    st.session_state.trend_profile_df = None
    st.session_state.trend_rental_df = None

if run_btn:
    if not is_input_complete:
        st.session_state.final_result = None
        st.session_state.rental_df = None
        st.session_state.profile_df = None
        st.session_state.trend_profile_df = None
        st.session_state.trend_rental_df = None
        st.warning("모든 입력 조건을 선택해 주세요.")
        st.stop()

# -----------------------------
# 쿼리 실행
# -----------------------------
if run_btn:
    query = f"""
    WITH user_input AS (
        SELECT
            '{region}' AS REGION_NAME,
            '{household_type}' AS HOUSEHOLD_TYPE,
            '{budget_tier}' AS BUDGET_TIER,
            '{has_child}' AS HAS_CHILD,
            '{priority_focus}' AS PRIORITY_FOCUS
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
                '\\n'
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
                    COALESCE((SELECT RENTAL_CANDIDATES FROM rental_candidates), '없음'), '. ',

                    '체크리스트 작성 규칙: ',
                    '1) 필수 행동 중심으로 작성해라. ',
                    '2) 사용자의 우선순위에 맞게 이유를 다르게 써라. ',
                    '3) 렌탈 추천 결과가 있으면 체크리스트에 자연스럽게 반영해라. ',
                    '4) 행정/생활/가전/안전 같은 category를 적절히 사용해라. ',
                    '5) 너무 추상적인 항목은 금지한다. ',

                    '출력 예시는 다음 형식이어야 한다: ',
                    '{{"checklist":[{{"stage":"지금 바로","item_name":"...","category":"...","reason":"..."}}]}}'
                ),
                model_parameters => {{'temperature': 0.2}},
                response_format => {{
                    'type': 'json',
                    'schema': {{
                        'type': 'object',
                        'properties': {{
                            'checklist': {{
                                'type': 'array',
                                'items': {{
                                    'type': 'object',
                                    'properties': {{
                                        'stage': {{'type': 'string'}},
                                        'item_name': {{'type': 'string'}},
                                        'category': {{'type': 'string'}},
                                        'reason': {{'type': 'string'}}
                                    }},
                                    'required': ['stage', 'item_name', 'category', 'reason']
                                }}
                            }}
                        }},
                        'required': ['checklist']
                    }}
                }},
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
    """

    profile_query = f"""
    SELECT
        REGION_NAME,
        YEAR_MONTH,
        AVG_HOUSEHOLD_INCOME,
        AVG_ASSET_AMOUNT,
        FOOD_SALES,
        HOME_LIFE_SERVICE_SALES,
        ELECTRONICS_FURNITURE_SALES,
        E_COMMERCE_SALES
    FROM VW_LLM_PROFILE_INPUT
    WHERE REGION_NAME = '{region}'
    ORDER BY YEAR_MONTH DESC
    LIMIT 1
    """

    profile_trend_query = f"""
    SELECT
        YEAR_MONTH,
        FOOD_SALES,
        HOME_LIFE_SERVICE_SALES,
        ELECTRONICS_FURNITURE_SALES,
        E_COMMERCE_SALES
    FROM VW_LLM_PROFILE_INPUT
    WHERE REGION_NAME = '{region}'
    ORDER BY YEAR_MONTH DESC
    LIMIT 6
    """

    rental_trend_query = f"""
    WITH top_categories AS (
        SELECT RENTAL_SUB_CATEGORY
        FROM VW_RENTAL_RECOMMENDATION_SCORE
        WHERE REGION_NAME = '{region}'
          AND YEAR_MONTH = (
              SELECT MAX(YEAR_MONTH)
              FROM VW_RENTAL_RECOMMENDATION_SCORE
              WHERE REGION_NAME = '{region}'
          )
        ORDER BY CONTRACT_COUNT DESC
        LIMIT 3
    )
    SELECT
        YEAR_MONTH,
        RENTAL_SUB_CATEGORY,
        CONTRACT_COUNT,
        AVG_NET_SALES
    FROM VW_RENTAL_RECOMMENDATION_SCORE
    WHERE REGION_NAME = '{region}'
      AND RENTAL_SUB_CATEGORY IN (SELECT RENTAL_SUB_CATEGORY FROM top_categories)
    ORDER BY YEAR_MONTH DESC, RENTAL_SUB_CATEGORY
    LIMIT 18
    """

    result = session.sql(query).collect()
    profile_result = session.sql(profile_query).collect()
    profile_trend_result = session.sql(profile_trend_query).collect()
    rental_trend_result = session.sql(rental_trend_query).collect()

    if result:
        final_result = result[0]["FINAL_RESULT"]
        if isinstance(final_result, str):
            final_result = json.loads(final_result)
        st.session_state.final_result = final_result

    if profile_result:
        profile_df = pd.DataFrame([dict(profile_result[0].as_dict())])
        st.session_state.profile_df = profile_df

    if profile_trend_result:
        trend_profile_df = pd.DataFrame([row.as_dict() for row in profile_trend_result])
        trend_profile_df = trend_profile_df.sort_values("YEAR_MONTH")
        st.session_state.trend_profile_df = trend_profile_df

    if rental_trend_result:
        trend_rental_df = pd.DataFrame([row.as_dict() for row in rental_trend_result])
        trend_rental_df = trend_rental_df.sort_values("YEAR_MONTH")
        st.session_state.trend_rental_df = trend_rental_df

    if st.session_state.final_result is not None:
        rental_df = pd.DataFrame(st.session_state.final_result["rental_recommendations"])
        st.session_state.rental_df = rental_df

# -----------------------------
# 결과 렌더링
# -----------------------------
if st.session_state.final_result is None:
    st.info("위 입력 조건을 선택한 뒤 분석하기를 눌러주세요.")
else:
    final_result = st.session_state.final_result
    rental_df = st.session_state.rental_df
    profile_df = st.session_state.profile_df
    trend_profile_df = st.session_state.trend_profile_df
    trend_rental_df = st.session_state.trend_rental_df

    # 요약 카드
    s1, s2, s3 = st.columns(3)
    with s1:
        st.markdown(
            f"""
            <div class="summary-card">
                <div class="summary-label">가구유형</div>
                <div class="summary-value">{final_result["household_type"]}</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with s2:
        st.markdown(
            f"""
            <div class="summary-card">
                <div class="summary-label">예산등급</div>
                <div class="summary-value">{final_result["budget_tier"]}</div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with s3:
        st.markdown(
            f"""
            <div class="summary-card">
                <div class="summary-label">추천 렌탈 수</div>
                <div class="summary-value">{len(final_result["rental_recommendations"])}개</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown(
        f"""
        <div class="reason-card">
            <b>분석 기준</b><br><br>
            {final_result["classification_reason"]}
        </div>
        """,
        unsafe_allow_html=True,
    )

    # 체크리스트 / 렌탈추천
    st.markdown("### 이사 체크리스트")

    stage_order = ["지금 바로", "이사 전", "입주 직후", "선택 항목"]
    checklist_by_stage = {stage: [] for stage in stage_order}
    
    for item in final_result["checklist"]:
        stage = item.get("stage", "선택 항목")
        if stage not in checklist_by_stage:
            stage = "선택 항목"
        checklist_by_stage[stage].append(item)
    
    for stage in stage_order:
        if checklist_by_stage[stage]:
            st.markdown(f"#### {stage}")
            for item in checklist_by_stage[stage]:
                st.markdown(
                    f"""
                    <div class="check-item">
                        <div class="check-title">{item['item_name']}</div>
                        <div class="check-meta">{item['category']}</div>
                        <div>{item['reason']}</div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )
    
    st.markdown("### 렌탈 추천")
    
    for _, item in rental_df.iterrows():
        if item["recommendation_level"] == "추천":
            badge = '<span class="badge-reco">추천</span>'
        elif item["recommendation_level"] == "고려 가능":
            badge = '<span class="badge-consider">고려 가능</span>'
        else:
            badge = '<span class="badge-hold">보류</span>'
    
        st.markdown(
            f"""
            <div class="rental-card">
                <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;">
                    <div class="rental-title">{item['sub_category']}</div>
                    <div>{badge}</div>
                </div>
                <div class="rental-sub">{item['main_category']}</div>
                <div>참고 가격 지표: {int(item['reference_price']):,}</div>
                <div>지역 계약 수: {int(item['contract_count']):,}</div>
                <div style="margin-top:0.45rem;">총 추천 점수: <b>{int(item['final_score'])}</b></div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown("### 추천 점수 분석")
    c1, c2 = st.columns(2)

    with c1:
        st.markdown("**추천 점수 비교**")
        score_df = rental_df[["sub_category", "final_score"]].copy().set_index("sub_category")
        st.bar_chart(score_df)

    with c2:
        st.markdown("**점수 구성요소 비교**")
        component_df = rental_df[
            ["sub_category", "demand_score", "budget_score", "priority_score", "child_score"]
        ].copy().set_index("sub_category")
        st.bar_chart(component_df)

    c3, c4 = st.columns(2)

    with c3:
        st.markdown("**렌탈 수요(계약 수)**")
        demand_df = rental_df[["sub_category", "contract_count"]].copy().set_index("sub_category")
        st.bar_chart(demand_df)

    with c4:
        st.markdown("**참고 가격 지표 비교**")
        price_df = rental_df[["sub_category", "reference_price"]].copy().set_index("sub_category")
        st.bar_chart(price_df)

    if profile_df is not None and not profile_df.empty:
        st.markdown("### 지역 소비 패턴 분석")

        p1, p2 = st.columns(2)
        with p1:
            st.metric("평균가구소득", f"{int(profile_df['AVG_HOUSEHOLD_INCOME'].iloc[0]):,}")
        with p2:
            st.metric("평균자산", f"{int(profile_df['AVG_ASSET_AMOUNT'].iloc[0]):,}")

        profile_chart_df = pd.DataFrame(
            {
                "category": ["식품", "생활서비스", "가전가구", "이커머스"],
                "value": [
                    float(profile_df["FOOD_SALES"].iloc[0]),
                    float(profile_df["HOME_LIFE_SERVICE_SALES"].iloc[0]),
                    float(profile_df["ELECTRONICS_FURNITURE_SALES"].iloc[0]),
                    float(profile_df["E_COMMERCE_SALES"].iloc[0]),
                ],
            }
        ).set_index("category")

        st.bar_chart(profile_chart_df)

    # -----------------------------
    # 최근 6개월 추이
    # -----------------------------
    if trend_rental_df is not None and not trend_rental_df.empty:
        st.markdown("### 최근 6개월 렌탈 수요 추이")
        st.caption("최근 몇 개월 동안 상위 렌탈 카테고리의 계약 수가 어떻게 변했는지 보여줍니다.")

        rental_contract_pivot = trend_rental_df.pivot(
            index="YEAR_MONTH",
            columns="RENTAL_SUB_CATEGORY",
            values="CONTRACT_COUNT"
        ).fillna(0)
        st.line_chart(rental_contract_pivot)

        st.markdown("### 최근 6개월 렌탈 가격 추이")
        st.caption("최근 몇 개월 동안 주요 렌탈 카테고리의 참고 가격 지표 변화를 보여줍니다.")

        rental_price_pivot = trend_rental_df.pivot(
            index="YEAR_MONTH",
            columns="RENTAL_SUB_CATEGORY",
            values="AVG_NET_SALES"
        ).fillna(0)
        st.line_chart(rental_price_pivot)

    if trend_profile_df is not None and not trend_profile_df.empty:
        st.markdown("### 최근 6개월 지역 소비 패턴 추이")
        st.caption("최근 몇 개월 기준 이 지역의 소비 카테고리 변화 흐름입니다.")

        trend_profile_chart_df = trend_profile_df.set_index("YEAR_MONTH")[
            ["FOOD_SALES", "HOME_LIFE_SERVICE_SALES", "ELECTRONICS_FURNITURE_SALES", "E_COMMERCE_SALES"]
        ]
        st.line_chart(trend_profile_chart_df)