# 캄스 엄마표 영어미술놀이 라이브러리

네이버 블로그 `그냥하는 캄스영어`의 **엄마표 영어미술놀이** 카테고리를 검색하고 탐색할 수 있는 정적 웹 앱입니다.

- 운영 사이트: <https://kamsartenglish.vercel.app>
- GitHub: <https://github.com/ljskt2000-stack/kamsARTenglish>

## 포함된 기능

- 제목·준비물·영어 표현 통합 검색
- 연령·놀이 유형·계절 필터
- 최신순·오래된순·가나다순 정렬
- 카드형 목록과 상세 모달
- 네이버 원본 게시물 연결
- 모바일·태블릿·PC 반응형 레이아웃
- GitHub Pages 배포 가능

카테고리의 전체 144개 게시물 중 사용자가 제외하도록 지정한 게시물 `224374497783`을 빼고 **143개**가 포함되어 있습니다.

## 로컬 실행

JSON 데이터를 `fetch`로 읽으므로 HTML 파일을 직접 더블클릭하지 말고 간단한 웹 서버로 실행합니다.

```powershell
python -m http.server 4173
```

브라우저에서 `http://localhost:4173`을 엽니다.

## GitHub Pages 배포

1. 이 폴더의 파일을 GitHub 저장소 기본 브랜치에 올립니다.
2. 저장소의 **Settings → Pages**로 이동합니다.
3. **Deploy from a branch**를 선택합니다.
4. 배포 브랜치와 루트 폴더 `/ (root)`를 선택해 저장합니다.

별도의 빌드 명령이나 환경변수는 필요하지 않습니다.

## 데이터 갱신

Windows PowerShell에서 다음 명령을 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\crawl.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\download-thumbnails.ps1
```

첫 번째 스크립트는 대상 카테고리 번호 `3`만 읽고 제외 게시물을 제거한 다음 `data/posts.json`을 갱신합니다. 두 번째 스크립트는 네이버 직접 연결 차단에 대비해 대표 이미지를 최적화된 로컬 썸네일로 저장합니다. 확인할 수 없는 상세 필드는 빈 값으로 유지합니다.

## 주요 파일

- `index.html`: 앱 마크업
- `styles.css`: 캄스 브랜드 디자인과 반응형 스타일
- `app.js`: 검색·필터·상세 보기 로직
- `data/posts.json`: 앱 전체 데이터
- `data/posts.sample.json`: 정밀 검증 샘플
- `scripts/crawl.ps1`: 데이터 갱신 스크립트
- `scripts/download-thumbnails.ps1`: 대표 이미지 로컬 저장·최적화 스크립트
- `data/crawl-report.md`: 수집 검증 보고서

## 데이터 및 이미지 안내

제목, 게시일, 대표 이미지, 요약 및 구조화 정보는 공개 원문에서 확인 가능한 범위만 사용합니다. 앱은 GitHub Pages에서도 안정적으로 표시되도록 로컬 썸네일을 사용하고, 원본 대표 이미지 URL은 `sourceThumbnail`에 보존합니다. 각 콘텐츠의 원문과 권리는 원저작자에게 있습니다.
