# On-Voice Git Convention Guide

이 문서는 **On-Voice(청각장애인을 위한 목소리 크기 및 발음 교정 서비스)** 프로젝트의  
Git 브랜치, 커밋, Pull Request(업로드) 규칙을 정의합니다.

## 1. Branch Naming Convention

모든 작업 브랜치는 `main`에서 분기하고, 아래 구조를 사용합니다.

> **`type/scope/description`**

### Branch Type

| Type | 설명 |
| :--- | :--- |
| `feat` | 사용자 기능 추가 |
| `fix` | 버그 수정 |
| `refactor` | 동작 변경 없는 구조 개선 |
| `test` | 테스트 코드 추가/수정 |
| `docs` | 문서 작성/수정 |
| `chore` | 빌드, 설정, 의존성 등 운영성 작업 |

### Branch Scope

| Scope | 설명 |
| :--- | :--- |
| `fe` | 앱 UI/UX |
| `be` | API/서버 로직 |
| `ai` | 음성 분석/모델 추론 |
| `audio` | 녹음, 볼륨 처리, 신호 처리 |
| `accessibility` | 접근성 기능(시각/청각 보조 UX) |
| `infra` | 배포, CI/CD, 환경설정 |
| `common` | 공통 모듈 |

### Description 규칙

- 소문자 + 하이픈(`-`) 사용
- 작업 의도를 짧고 명확하게 작성
- 이슈가 있으면 끝에 이슈 번호를 붙여도 됨 (`...-123`)

### 예시

```bash
git switch -c feat/audio/add-realtime-volume-feedback
git switch -c feat/accessibility/add-vibration-alert-for-low-volume
git switch -c fix/ai/fix-phoneme-score-normalization
git switch -c docs/common/update-contribution-guide
```

## 2. Commit Message Convention

Conventional Commits 형식을 사용합니다.

> **`<type>(<scope>): <subject>`**

### 작성 규칙

- `type`: 브랜치 타입과 동일한 의미 사용 (`feat`, `fix`, ...)
- `scope`: 변경 영역 (`audio`, `ai`, `be`, `fe` 등)
- `subject`:
  - 50자 이내 권장
  - 명령형 현재 시제 사용 (예: `Add`, `Fix`, `Improve`)
  - 첫 글자 대문자, 마침표 생략

### Body (선택)

- 무엇을/왜 바꿨는지 작성
- 한 줄 72자 이내 권장
- 의료적 효능을 단정하는 표현은 피하고, 기능적 사실만 기록

### Footer (선택)

- 이슈 연결: `Closes #45`, `Refs #52`
- 호환성 깨짐이 있으면 `BREAKING CHANGE:` 명시

### 예시

```text
feat(audio): Add real-time volume level feedback bar
```

```text
fix(ai): Correct phoneme scoring weight for final consonants

Adjust weighting logic to reduce over-penalty on 받침 errors.
Refs #87
```

## 3. GitHub 업로드(Pull Request) Convention

## PR 제목

커밋 헤더와 동일한 패턴 사용:

> **`<type>(<scope>): <subject>`**

예: `feat(accessibility): Add haptic cue when pronunciation score drops`

## PR 본문 템플릿

```markdown
## 변경 내용
- 핵심 변경 1
- 핵심 변경 2

## 배경/목적
- 왜 이 변경이 필요한지

## 테스트
- [ ] 단위 테스트 통과
- [ ] 수동 테스트 완료 (기기/OS 명시)
- [ ] 회귀 영향 확인

## 접근성/서비스 품질 체크
- [ ] 피드백(진동/시각화/텍스트)이 명확함
- [ ] 음량/발음 점수 로직 변경 시 기준 문서 반영
- [ ] 청각장애 사용자 관점에서 안내 문구 검토

## 이슈
- Closes #이슈번호
```

## 리뷰/머지 규칙

- 추후 관련 템플릿 추가 예정
- 자기 자신 PR 셀프 머지 금지 (최소 1명 승인 후 머지)
- CI 실패 시 머지 금지
- 기능 PR은 가능하면 300라인 내로 분할
- `main` 직접 푸시 금지 (PR 통해서만 반영)

## 4. 태그/릴리즈 규칙

- 버전 태그는 Semantic Versioning(`vMAJOR.MINOR.PATCH`) 사용
- 사용자 경험에 영향 있는 변경은 릴리즈 노트에 반드시 기록
  - 예: 점수 계산식 조정, 피드백 방식 변경, 접근성 UX 변경

## 5. 금지 사항

- 민감 정보(API Key, 토큰, 개인정보, 원본 음성 파일) 커밋 금지
- 테스트하지 않은 핵심 로직(음량/발음 점수) 머지 금지
- "작동함", "수정" 같은 의미 없는 커밋 메시지 금지
