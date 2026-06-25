# Selova Tasks

Last updated: 2026-06-25

Status keys: `Todo`, `Doing`, `Blocked`, `Done`.

## 完了済み

| Status | Owner | Task | Result |
| --- | --- | --- | --- |
| Done | CTO | 会社型エージェント運用 docs を作る | `AGENTS.md`, `docs/PRODUCT_SPEC.md`, `docs/ROADMAP.md`, `docs/TASKS.md`, `docs/DECISIONS.md` を作成 |
| Done | iOS Engineer | XcodeBuildMCP session defaults を確認する | active profile `live`: project `FocusVideoApp.xcodeproj`, scheme `FocusVideoApp`, simulator `iPhone 17`, bundle `com.Itaru.Selova` |
| Done | QA | 既存テストを選定 simulator で実行する | XcodeBuildMCP `test_sim`: 14 passed / 0 failed |
| Done | iOS Engineer | scheme `FocusVideoApp` で Debug build を確認する | XcodeBuildMCP `build_sim`: succeeded, warnings 0 / errors 0 |
| Done | PM | 初回リリースのプロダクト約束を仮固定する | 「保存した学習動画を、フォルダごとに続きから再開し、1本ずつ最後まで見やすくする」 |
| Done | PM | 既存機能を must / should / later に分類する | `docs/PRODUCT_SPEC.md` に反映 |

## 次にやること

| Status | Owner | Task | Why Needed Question | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| Todo | Designer | 主要学習ループの UX を図式化する | なぜ保存済み動画から学習開始までが迷わないのか？ | Home -> Add Video -> Library -> Study Feed -> Home update の画面遷移が説明できる |
| Todo | Designer | 離脱摩擦と通知 UX をレビューする | なぜ圧ではなく復帰支援になっているのか？ | 戻る操作、通知文言、設定導線の改善候補が出ている |
| Todo | QA | 手動回帰チェックリストを実行する | なぜ中核ループを保証できるチェックなのか？ | 下の Manual QA Checklist の must 項目が pass/fail 記録済み |
| Todo | Reviewer | 初回リリース範囲をリスク観点でレビューする | なぜ各機能が学習フローを壊しうるのか？ | must/should/later の境界に反対意見または承認がある |
| Todo | Release Manager | リリース準備チェックリストを実行する | なぜ実ユーザーへ出せる状態か？ | 下の Release Checklist に owner と status が入っている |

## 初回リリース Scope

### Must

| Area | Scope | Why |
| --- | --- | --- |
| Home | 続きから見やすい動画、今日の集中時間、成長表示 | 学習者が次に何を見ればよいか迷わないため |
| Library | フォルダ/動画管理、検索、並び替え、移動、削除 | 保存した動画を後から見つけて再開するため |
| Add Video | ローカル、YouTube、Vimeo の追加 | 学習素材を Selova に入れられないと価値が始まらないため |
| Study Feed | 全画面再生、フォルダ内スワイプ、再生位置保存 | 1本ずつ続きから見て完了しやすくするため |
| Progress | 集中時間、完了状態、attention event 保存 | Home の再開/復習候補を支えるため |
| QA | `test_sim` と `build_sim` を通す | 実装前 baseline とリリース前確認の基準にするため |

### Should

| Area | Scope | Why |
| --- | --- | --- |
| Notes | タイムスタンプ付きノート | 動画内の理解ポイントへ戻りやすくするため |
| Notifications | 離脱後のローカル通知と設定 | 学習再開を助けるが、初回価値の中心ではないため |
| Focus Insights | 集中の記録 | 学習継続の手応えを見せるため |

### Later

| Area | Scope | Why |
| --- | --- | --- |
| Live Activity | 復帰導線の主役化 | 魅力はあるが、まずアプリ内の学習ループ安定が先のため |
| Analytics Dashboard | 分析にもとづく改善運用 | 初回リリース後の改善判断で価値が高いため |
| Cloud/Account | 同期、ログイン | 初回のローカル学習価値には必須でないため |
| AI | 要約、チューター、自動生成 | プロダクトの約束が広がりすぎるため |

## Manual QA Checklist

### Must Pass

| Status | Area | Scenario | Expected |
| --- | --- | --- | --- |
| Todo | Launch | 新規起動する | Home が表示され、クラッシュしない |
| Todo | Add Video | フォルダがない状態で動画追加を開く | フォルダ作成が必要だと分かる |
| Todo | Library | フォルダを作成する | 同階層重複名を防ぎ、一覧に表示される |
| Todo | Add Video | ローカル動画を追加する | 保存先フォルダを選び、Library に保存される |
| Todo | Add Video | YouTube URL を追加する | タイトル取得または手入力で保存できる |
| Todo | Add Video | Vimeo URL を追加する | タイトル取得または手入力で保存できる |
| Todo | Study Feed | Library から動画を開く | 全画面再生画面が開く |
| Todo | Study Feed | 同じフォルダに未完了動画が複数ある状態でスワイプする | フォルダ内の未完了動画に切り替わる |
| Todo | Progress | 再生後に閉じて再度開く | 再生位置が復元される |
| Todo | Completion | 動画完了後に Home を見る | 完了/集中情報が破綻しない |

### Should Pass

| Status | Area | Scenario | Expected |
| --- | --- | --- | --- |
| Todo | Notes | Study Feed でノートを開く | タイムスタンプ付きメモを作れる |
| Todo | Search | Library で動画/フォルダ検索する | 対象だけが表示される |
| Todo | Move | 動画を別フォルダへ移動する | 移動先で再生できる |
| Todo | Settings | 通知設定を開く | 権限状態と上限が理解できる |
| Todo | Focus Insights | Home の集中記録を開く | タブバーが邪魔せず記録を見られる |

## Release Checklist

| Status | Owner | Check | Expected |
| --- | --- | --- | --- |
| Todo | Release Manager | App display name | `Selova` と表示される |
| Todo | Release Manager | Bundle ID | app `com.Itaru.Selova`, Live Activity `com.Itaru.Selova.LiveActivity` |
| Todo | Release Manager | Deployment target | iOS `26.5` が意図した設定か確認されている |
| Todo | Release Manager | App icon | Light/Dark/Tinted icon が揃っている |
| Todo | Release Manager | Privacy | 分析/通知/動画データの説明が用意されている |
| Todo | Release Manager | Screenshots | Home, Library, Add Video, Study Feed, Settings が撮影済み |
| Todo | QA | Final tests | `test_sim` と `build_sim` が release 前に再実行済み |
| Todo | Reviewer | Release diff review | must scope に関係ない危険な変更がない |

## Feature Question Bank

機能実装前に使う問い:

- Home: なぜ次の学習行動が明確になるのか？
- Library: なぜ整理が学習開始を遅らせないのか？
- Add Video: なぜこの動画ソース/メタデータが初回リリースに必要なのか？
- Study Feed: なぜこの操作が集中または完了率を上げるのか？
- Notes: なぜアプリ内かつタイムスタンプ付きで必要なのか？
- Notifications: なぜこの通知は親切で、しつこくないのか？
- Live Activity: なぜアプリ外に復帰導線を出す必要があるのか？
- Analytics: なぜこのイベントがプロダクト判断に必要なのか？

