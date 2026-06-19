# 살림길

> **Snowflake AI & Data Hackathon 2026 Korea** 참가작
> 🔗 [해커톤 공식 페이지](https://www.snowflake.com/snowflake-hackathon-2026-korea/)

## 프로젝트 소개

**살림길(Salimgil)**은 Snowflake Cortex AI와 Claude Sonnet을 활용하여 이사를 준비하는 가구에게 **맞춤형 렌탈 추천 및 이사 체크리스트**를 제공하는 AI 에이전트입니다.

사용자의 거주 지역, 가구 유형, 예산, 자녀 유무, 우선순위를 입력하면, 실제 카드 소비 데이터·자산/소득 데이터·부동산 데이터를 기반으로 분석한 결과와 함께 AI가 생성한 개인화된 이사 준비 체크리스트를 제공합니다.

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **가구 프로파일링** | 지역·가구유형·예산·자녀유무·우선순위 기반 사용자 분류 |
| **렌탈 상품 추천** | 수요 점수 + 예산/우선순위/자녀 점수를 합산한 다차원 스코어링으로 상위 5개 렌탈 상품 추천 |
| **AI 이사 체크리스트** | Snowflake `AI_COMPLETE` + `claude-sonnet-4-5` 모델로 단계별 맞춤 체크리스트 생성 |
| **지역 소비/자산 분석** | 실제 카드 매출·자산·소득 데이터를 기반으로 한 지역별 라이프스타일 분석 |
| **Streamlit UI** | Snowflake Native App으로 구동되는 인터랙티브 웹 인터페이스 |

---

## 아키텍처

```
사용자 입력 (Streamlit)
        │
        ▼
  Snowflake SQL Pipeline
  ├── 01. Data Mart (DIM_REGION, STG_CARD_SALES, STG_ASSET_INCOME, STG_RENTAL)
  ├── 02. LLM Input Views (VW_LLM_PROFILE_INPUT, VW_RENTAL_RECOMMENDATION_SCORE)
  ├── 03. 사용자 분류 (가구유형 × 예산 × 자녀유무)
  ├── 04. 렌탈 스코어링 (수요 + 예산 + 우선순위 + 자녀 점수)
  ├── 05. AI 체크리스트 생성 (AI_COMPLETE → claude-sonnet-4-5)
  └── 06. 최종 결과 JSON 반환
        │
        ▼
  Streamlit 대시보드 출력
```

---

## 데이터 소스

모든 원본 데이터는 **Snowflake 클라우드 내부**에 보관되며, 본 저장소에는 데이터를 가공하는 SQL 스크립트와 UI 코드만 포함됩니다.

| 데이터 | 설명 |
|--------|------|
| **SPH** (신한카드 소비 데이터) | 지역별 카드 매출, 업종별 소비 통계 |
| **RichGo** (부동산 데이터) | 지역별 자산·소득 정보 |
| **AJD** (렌탈 계약 데이터) | 렌탈 상품 카테고리별 계약 건수 및 매출 |

대상 지역: **중구**, **성동구**, **강남구** (서울)

---

## 기술 스택

| 레이어 | 기술 |
|--------|------|
| 데이터 플랫폼 | Snowflake (Data Cloud) |
| AI 모델 | Snowflake Cortex `AI_COMPLETE` + `claude-sonnet-4-5` |
| 프론트엔드 | Streamlit (Snowflake Native App) |
| 언어 | Python, SQL |

---

## 프로젝트 구조

```
snowflake-hackathon-salimgil-ai-agent/
├── app/
│   └── streamlit_app.py          # Streamlit UI 메인 앱
└── sql/
    ├── 01_data_mart/
    │   └── hackathon_dm.sql      # 데이터 마트 테이블 및 스테이징 레이어 생성
    ├── 02_ai_logic/
    │   ├── 01_llm_input_views.sql    # LLM 입력용 뷰 생성
    │   ├── 02_classification.sql     # 사용자 분류 로직
    │   ├── 03_checklist_logic.sql    # AI 체크리스트 생성
    │   ├── 04_rental_logic.sql       # 렌탈 스코어링 로직
    │   ├── 05_final_result.sql       # 최종 결과 통합 쿼리
    │   └── 06_trend_queries.sql      # 트렌드 분석 쿼리
    └── exploration/
        ├── ajd_analysis.sql          # 렌탈 데이터 탐색
        ├── richgo_analysis.sql       # 부동산 데이터 탐색
        └── sph_analysis.sql          # 카드 소비 데이터 탐색
```

---

## 렌탈 추천 스코어링 기준

| 점수 항목 | 설명 |
|-----------|------|
| **수요 점수** | 실제 계약 건수·매출 기반 수요 지수 |
| **예산 점수** | BASIC / MID / PREMIUM 예산 구간과 상품 가격 수준 매칭 |
| **우선순위 점수** | 교육/위생 / 편의성 / 인테리어 / 안전/보안 중 선택한 우선순위와 상품 카테고리 매칭 |
| **자녀 점수** | 자녀 유무에 따라 육아 관련 렌탈 상품 가중치 부여 |

총점 80점 이상 → **추천**, 55점 이상 → **검토 가능**, 미만 → **비추천**

---

## AI 체크리스트 생성 구조

Snowflake `AI_COMPLETE`가 `claude-sonnet-4-5` 모델을 호출하여 아래 4단계 이사 체크리스트를 JSON 형식으로 생성합니다.

| 단계 | 내용 |
|------|------|
| **계약 마무리** | 현재 거주지 퇴거 관련 행동 |
| **이사 준비** | 짐 정리 및 이동 준비 |
| **새집 입주** | 입주 직후 처리 사항 |
| **새집 그리기** | 인테리어 및 정착 관련 항목 |

각 항목은 `stage`, `item_name`, `category`, `reason` 필드를 포함합니다.

---

## 실행 방법

### 사전 요구사항
- Snowflake 계정 (Cortex AI 기능 활성화)
- Snowflake Native App 또는 Streamlit in Snowflake 환경

### 설치 순서

1. **데이터 마트 구성**
   ```sql
   -- sql/01_data_mart/hackathon_dm.sql 실행
   ```

2. **AI 로직 뷰 생성**
   ```sql
   -- sql/02_ai_logic/ 내 SQL 파일을 순서대로 실행 (01 → 06)
   ```

3. **Streamlit 앱 배포**
   ```
   Snowflake > Streamlit > Create App > app/streamlit_app.py 업로드
   ```

---

## 팀

**살림길** — [Snowflake AI & Data Hackathon 2026 Korea](https://www.snowflake.com/snowflake-hackathon-2026-korea/) 참가작
