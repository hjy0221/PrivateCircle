# PrivateCircle Product Rationale

[日本語](https://github.com/hjy0221/PrivateCircle/blob/main/docs/product-rationale.md#%E6%97%A5%E6%9C%AC%E8%AA%9E) · [English](https://github.com/hjy0221/PrivateCircle/blob/main/docs/product-rationale.md#english) · [한국어](https://github.com/hjy0221/PrivateCircle/blob/main/docs/product-rationale.md#%ED%95%9C%EA%B5%AD%EC%96%B4)

## 日本語

## プロダクトの視点

多くの SNS は、友人との近況共有を超え、おすすめコンテンツ、広告、インフルエンサーの消費の場へ広がっています。その中で、親しい人と予定を決め、実際に会い、一緒に過ごしたことを分かち合う経験が後回しになりがちです。PrivateCircle は、より多くの投稿を見せるのではなく、実際に知っている人と会い、あとから経験を分かち合える関係の基本体験を取り戻すことから始まります。

**友人を眺めるための SNS ではなく、友人と実際に会い、関係を築くための SNS。** 公開的な自己表現より、相互に同意した小さな関係を優先します。

## 出発点と仮説

親しい友人との関係で必要なのは、投稿を見続けることより、次の予定を決め、実際に会い、その瞬間をまた見返すことです。予定はメッセンジャーに散らばり、都合合わせは繰り返され、写真も個別のアルバムや会話に残りやすくなります。

親しい人だけの小さな空間で、`グループ → 予定 → 会う → 写真と瞬間 → 思い出` をつなげれば、アプリを見る時間より一緒に過ごす実際の時間を増やせる、というのが製品仮説です。予定の会話、位置共有、写真送信、アルバム整理を「集まり」という一つの文脈にまとめます。

## 設計方針

- 友人とグループを起点にし、知らない人への公開より実際の関係を優先する
- 個人の公開プロフィールより、目的と親密さに合う小さなグループを重視する
- 投稿ではなく、参加者、候補日時、確定場所を持つ予定を中核にする
- 到着状況や共同写真を、同意に基づき同じ集まりにつなげる
- フォロワー数、いいね数、人気ランキングを関係の成果として見せない
- 活動を公開フィードへ自動表示せず、共有範囲を明確にする
- SwiftUI と Apple HIG に沿った iOS 体験を提供する

## 利用の流れ

1. 友人と目的別のグループを作ります。
2. グループで集まりを作り、候補日時と場所を調整します。
3. 当日、互いの出発・到着状態を確認します。
4. 写真や短い瞬間を集まりに共有します。
5. 集まり単位の思い出として後から見返します。

## 意図的にしないこと

おすすめが決める公開フィード、フォロワー・いいねの競争、インフルエンサー中心の広告フィード、同意のない位置・活動追跡、滞在時間や反応数を関係の健全さの指標とする設計は扱いません。

## 成功指標

予定を作成して共通の日時を決めるまでの時間とメッセージ往復が減るか、アプリで決めた予定が実際の出会いにつながるか、参加者の写真が一つの記録として集まるか、あとから思い出を見返すかを確認します。公開反応や滞在時間を増やすための指標ではありません。

## 現在の実装範囲

Firebase のメール・パスワード認証、Firestore による複数グループ、メール招待、選択グループでの共同予定、候補時間の回答とリアルタイム同期、作成者による予定確定を実装しています。参加者だけが Meetup と availability にアクセスでき、作成者だけが候補を確定できます。当日は参加者が自分で到着状態を共有し、位置を追跡しません。

2026-09-28 時点で、Firebase プロジェクト `uri-sai-a8c73` の Firestore Rules をローカル `firestore.rules` と一致させてデプロイ済みです。ローカルの Rules テスト7件と iOS Simulator Debug ビルドは通過しています。実際の A/B アカウントフロー、友人データ連携、写真アップロード、自動思い出、通知、アカウント削除は今後の実装対象です。

## English

## Product perspective

Most social networks have expanded beyond keeping up with friends into places for consuming recommended content, advertising, and influencer posts. In that shift, making plans with people close to us, meeting them, and sharing what happened can become secondary. PrivateCircle begins by restoring the basic experience of relationships: helping people who actually know each other meet and revisit the moments they shared.

**It is not a social network for watching friends; it is a social network for meeting friends and building relationships.** It prioritizes small, mutually agreed relationships over public self-expression.

## Starting point and hypothesis

For close friends, the frequent need is less about continuously viewing posts and more about choosing the next time to meet, meeting in person, and later revisiting the occasion. Plans scatter across messenger conversations, availability matching becomes repetitive, and shared photos remain in individual albums or chat rooms.

The product hypothesis is that connecting `group → plan → meet → photos and moments → memories` in a small private space can increase the time people spend together in real life rather than the time they spend viewing the app. It brings schedule conversations, location sharing, photo delivery, and album organization into the single context of a meetup.

## Design choices

- Begin with real friends and groups, not exposure to an unknown audience.
- Prioritize small spaces organized around a purpose and level of closeness over public profiles.
- Treat a meetup, with participants, candidate times, and a confirmed place, as the primary object rather than a content post.
- Connect the before and after of a meeting through consent-based arrival status and shared photos.
- Do not turn follower or like counts into a relationship scoreboard.
- Keep activity private by default instead of automatically publishing it to a public feed.
- Follow SwiftUI and Apple HIG conventions for familiar, accessible iOS interactions.

## Core journey

1. Create several groups with friends for different purposes.
2. Create a meetup in a group and coordinate candidate times and places.
3. Check each participant's self-reported departure or arrival status on the day.
4. Share photos and short moments with the meetup.
5. Revisit the shared moments as memories grouped by meetup.

## What it intentionally avoids

The product does not include algorithmically selected public feeds, follower and like competition, influencer-led reach or advertising feeds, tracking a friend's location or activity without consent, or treating time spent, posting volume, and reactions as measures of relationship health.

## Success criteria

It evaluates whether the time and repeated messages needed to schedule a meetup decrease; whether plans made in the app lead to actual meetings; whether participants collect their photos into one meetup record; and whether they revisit memories later. These are hypotheses for assessing usefulness to relationships, not measures intended to increase public engagement or screen time.

## Current implementation scope

The app currently includes Firebase email/password authentication, Firestore-based multi-group creation and email invitations, shared meetups with selected group members, candidate-time responses with real-time synchronization, and organizer confirmation. Only participants can access a meetup and its availability, and only the organizer can confirm candidates. Participants self-report arrival status on the confirmed meetup day; their location is not tracked.

As of 2026-09-28, Firestore Rules for Firebase project `uri-sai-a8c73` were deployed and verified to match the local `firestore.rules`; seven local Rules tests and an iOS Simulator Debug build passed. Live A/B-account flows, friend-data integration, photo upload, automatic memories, notifications, and account deletion remain to be implemented.

## 한국어

## 제품 관점

현재 대부분의 SNS는 친구와 소식을 나누는 기능을 넘어 추천 콘텐츠, 광고, 유명 인플루언서의 콘텐츠를 소비하는 공간으로 확장되고 있습니다. 그 과정에서 가까운 사람과 약속하고 함께한 일을 나누는 경험은 상대적으로 뒤로 밀릴 수 있습니다. 우리 사이는 더 많은 게시물을 보게 만드는 대신, 실제로 아는 사람과 만나고 함께한 일을 나중에 다시 나눌 수 있도록 관계의 기본 경험을 되살리는 데서 출발합니다.

**친구를 구경하기 위한 SNS가 아니라, 친구와 실제로 만나고 관계를 쌓기 위한 SNS.** 공개적인 자기표현보다 상호 동의한 작은 관계를 우선합니다.

## 출발점

많은 소셜 앱은 더 많은 노출과 반응을 얻는 일을 중심에 둡니다. 하지만 가까운 친구와의 관계에서 자주 필요한 일은 친구의 게시물을 계속 보는 것보다 다음 만남을 정하고, 실제로 만나고, 함께한 순간을 다시 꺼내 보는 일입니다.

약속은 메신저 대화에 흩어지고, 가능한 시간을 맞추는 과정은 반복됩니다. 함께 찍은 사진도 각자의 앨범이나 대화방에 남아 함께 만든 기억으로 이어지기 어렵습니다.

## 제품 가설

친한 사람끼리 쓰는 작은 공간 안에서 `그룹 → 약속 → 만남 → 사진과 순간 → 추억`을 연결하면, 앱을 보는 시간이 아니라 실제로 함께 보내는 시간이 늘어날 수 있습니다.

메신저의 일정 대화, 별도 위치 공유, 사진 전송과 앨범 정리에 흩어진 일을 모임이라는 하나의 맥락에 묶습니다. SNS에 올릴 콘텐츠를 만들기 위해 만나는 것이 아니라, 실제 만남에서 생긴 순간이 자연스럽게 기록으로 남는 흐름을 지향합니다.

## 설계 선택

- **친구와 그룹부터**: 불특정 다수에게 공개하기보다 실제 관계를 아는 사람끼리 초대하고 모입니다.
- **관계별 공간**: 개인의 공개 프로필보다 목적과 친밀도에 맞는 작은 그룹 및 함께한 기록을 우선합니다.
- **약속을 핵심 객체로**: 콘텐츠 게시물보다 참여자, 후보 일정, 확정 장소처럼 함께 결정할 정보를 먼저 다룹니다.
- **만남의 전후를 연결**: 일정 핑퐁을 줄이고, 동의 기반의 도착 상태와 공동 사진을 같은 모임에 이어 붙입니다.
- **점수판을 만들지 않기**: 팔로워 수와 좋아요 수를 관계의 성과처럼 보여 주지 않습니다.
- **기억을 함께 남기기**: 모임 중 공유한 사진과 순간을 나중에 다시 찾을 수 있는 추억으로 묶습니다.
- **기본은 비공개**: 개인의 활동을 공개 피드에 자동 노출하지 않고, 그룹 구성원과 공유 범위를 분명히 합니다.
- **익숙한 iOS 경험**: 내비게이션, 시트, 폼, 접근성은 SwiftUI와 Apple HIG를 따릅니다.

## 핵심 사용 흐름

1. 친구와 목적별 그룹을 여러 개 만듭니다.
2. 그룹 안에서 모임을 만들고 가능한 일정과 장소를 맞춥니다.
3. 모임 당일 서로의 출발·도착 상태를 확인합니다.
4. 함께 찍은 사진과 짧은 순간을 모임에 공유합니다.
5. 공유된 순간을 모임 단위 추억으로 다시 찾아봅니다.

## 의도적으로 하지 않을 것

- 추천 알고리즘이 정하는 공개 피드
- 팔로워·좋아요 수 경쟁과 인기 순위
- 인플루언서 중심의 도달 구조와 광고 피드
- 친구의 위치나 활동을 동의 없이 추적하는 기능
- 체류 시간, 게시물 수, 반응 수를 관계의 건강함을 대신하는 성공 지표로 삼는 것

## 성공을 판단하는 기준

- 모임을 만들고 공통 일정을 정하기까지 필요한 시간과 반복 메시지가 줄어드는가
- 앱에서 만든 약속이 실제 만남으로 이어지는가
- 참가자들이 각자 찍은 사진을 한 모임의 기록으로 함께 모으는가
- 시간이 지난 뒤 친구와 함께한 추억을 다시 찾아보는가

이 지표는 공개 반응이나 앱 체류 시간을 늘리는 목적이 아니라, 관계를 돕는 기능이 실제로 유용한지를 확인하기 위한 가설입니다.

## 현재 구현 범위

현재 앱에는 Firebase 이메일·비밀번호 인증, Firestore 기반 다중 그룹 생성·이메일 초대, 선택한 그룹 멤버와의 공동 모임, 후보 시간별 응답 저장 및 실시간 동기화, 작성자 일정 확정이 있습니다. 참가자만 Meetup과 availability에 접근하고 작성자만 후보를 확정하도록 로컬 규칙을 제한했습니다. 확정된 모임 당일에는 참가자가 직접 도착 상태를 공유하며, 위치는 추적하지 않습니다. 관련 Emulator 규칙 테스트 7개와 iOS Simulator Debug 빌드가 통과했습니다.

2026-09-28 운영 확인: Firebase Console 프로젝트는 앱 설정과 같은 `uri-sai-a8c73`입니다. 로컬 Rules 테스트 7개 통과 후 운영 Firestore Rules를 배포했고, 게시된 기본 데이터베이스 Rules가 로컬 `firestore.rules`와 일치함을 검증했습니다. Authentication 사용자는 1명이라 실제 A/B 계정 흐름은 아직 검증하지 못했습니다. Firestore 최상위에서 사용자 컬렉션 외 공유 그룹·Meetup 데이터가 보이지 않아 현재 참가자 reference backfill은 실행하지 않았습니다.

일반 화면에서는 샘플 친구와 추억을 실제 기록처럼 표시하지 않습니다. Debug 캡처 전용 화면만 샘플을 사용합니다. 기존 개인 모임 초안은 만든 사람 계정에만 보이고, 실제 공유 모임과 구분해 표시합니다. 실제 친구 데이터 연결, 사진 업로드, 자동 추억, 알림 및 계정 삭제는 아직 구현 대상입니다. Firebase 프로젝트와 인증·규칙이 이미 구성되어 있어 백엔드 교체보다 기존 기반을 안전하게 완성하는 것을 우선합니다.
