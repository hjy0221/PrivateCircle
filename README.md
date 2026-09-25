# 우리 사이

친구들과 약속을 정하고, 함께한 시간을 추억으로 남기는 프라이빗 관계 중심 iOS 앱입니다.

<p align="left">
  <img src="PrivateCircle/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" alt="우리 사이 앱 아이콘">
</p>

## 기획 이유

친구 관계에서 더 중요한 것은 공개적인 반응을 모으는 일보다 약속을 정하고 실제로 만나 함께한 순간을 기억하는 일이라고 봤습니다. 그래서 우리 사이는 그룹과 모임을 중심에 두고, 팔로워·좋아요 경쟁과 추천 피드를 제품 목표에서 제외합니다.

[기획 배경, 설계 원칙, MVP 범위 읽기](docs/product-rationale.md)

## 앱 화면

아래 화면은 Debug 미리보기에서 샘플 데이터로 캡처했습니다. 그룹 화면도 예시 그룹을 사용하며 Firebase 계정이나 서버 데이터를 변경하지 않습니다.

재캡처할 때는 Debug 스킴의 Launch Arguments에 `--screenshot-preview`와 `--screenshot-tab=home|groups|friends|meetups|memories`를 지정합니다. 그룹 생성 시트는 `--screenshot-group-create`도 추가합니다.

<table>
  <tr>
    <td align="center"><strong>로그인</strong><br><img src="docs/screenshots/login.png" width="180" alt="로그인 화면"></td>
    <td align="center"><strong>홈</strong><br><img src="docs/screenshots/home.png" width="180" alt="홈 화면"></td>
    <td align="center"><strong>그룹</strong><br><img src="docs/screenshots/groups.png" width="180" alt="그룹 목록 화면"></td>
  </tr>
  <tr>
    <td align="center"><strong>그룹 만들기</strong><br><img src="docs/screenshots/group-create.png" width="180" alt="그룹 생성 화면"></td>
    <td align="center"><strong>친구</strong><br><img src="docs/screenshots/friends.png" width="180" alt="친구 목록 화면"></td>
    <td align="center"><strong>모임</strong><br><img src="docs/screenshots/meetups.png" width="180" alt="모임 목록 화면"></td>
  </tr>
  <tr>
    <td align="center"><strong>추억</strong><br><img src="docs/screenshots/memories.png" width="180" alt="추억 화면"></td>
  </tr>
</table>

## 주요 흐름

- 친구와 여러 그룹을 만들고 이메일로 초대
- 모임과 일정을 함께 조율
- 도착 상태를 공유하고 함께한 순간을 추억으로 정리
- 추천 피드, 팔로워 수, 좋아요 수를 중심에 두지 않는 관계 경험

## 기술 구성

- SwiftUI, iOS 17 이상
- Firebase Authentication
- Cloud Firestore

## 현재 구현 범위

Firebase 이메일 인증과 Firestore 그룹 생성·이메일 초대 흐름이 연결되어 있습니다. 홈·친구·모임·추억의 목록은 현재 샘플 데이터이며, 실제 일정 조율·도착 상태·사진 업로드는 다음 MVP 작업입니다.

## 실행

1. `PrivateCircle.xcodeproj`를 Xcode에서 엽니다.
2. `PrivateCircle` 스킴과 iOS 시뮬레이터 또는 연결된 기기를 선택합니다.
3. 빌드 후 실행합니다.

Firebase 기능을 사용하려면 프로젝트에 맞는 `GoogleService-Info.plist`와 Firebase Console 설정이 필요합니다.
