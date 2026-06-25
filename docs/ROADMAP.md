# Selova Roadmap

Last updated: 2026-06-25

## ロードマップ原則

各フェーズで「なぜ今、学習者に必要か？」を確認します。

## Phase 0: 会社型開発基盤

Status: Done

Goal:

- 今後の作業を、仕様・設計・実装・QA・レビュー・リリースに分けて進められるようにする。

Work:

- `AGENTS.md` にエージェント役割を定義する。
- product spec、roadmap、tasks、decision log を作る。
- ビルド/テスト入口を確認する。
- 現在の Xcode 命名境界を守る。

なぜ必要か:

- なぜ個人開発/ローカル repo でも、実装前に会社型プロセスが必要なのか？

Exit criteria:

- 次のエージェントが、編集前にプロダクト方向・ビルド経路・未決事項を理解できる。
- `test_sim` と `build_sim` の baseline が記録されている。

## Phase 1: 初回リリース範囲の固定

Status: Provisional scope defined

Goal:

- 最初の公開/テスト配布で必ず届ける価値を決める。

Must scope:

- ホームからの続き再開。
- ライブラリでのフォルダ/動画管理。
- ローカル/YouTube/Vimeo 動画追加。
- 学習フィード再生と進捗保存。
- 既存テストと Debug build が通る状態の維持。

Should scope:

- 基本ノート。
- 通知設定。
- 集中の記録。

Later scope:

- Live Activity を主役にした復帰導線。
- 高度な分析 dashboard を使った改善。
- クラウド同期、アカウント、AI チューター。

なぜ必要か:

- なぜ各機能が、初回利用の学習者に価値を出すため必須なのか？

Exit criteria:

- PM が初回リリース範囲を accepted に変更する。
- Designer が主要学習ループの違和感を洗い出す。
- QA が手動回帰チェックリストを実行する。

## Phase 2: 信頼性と学習フロー QA

Status: Next

Goal:

- 中核の学習ループを壊れにくくする。

Focus:

- 動画追加。
- 動画を見つける。
- 再生を開始する。
- フォルダ内でスワイプする。
- 再生位置を保存して再開する。
- 動画を完了する。
- ホームの表示が更新される。

なぜ必要か:

- なぜ学習者が、最初の利用後も Selova に学習素材を預けてよいと思えるのか？

Exit criteria:

- 純粋ロジックには自動テストがある。
- エンドツーエンドの学習ループはシミュレータで確認されている。
- 既知バグに owner、重要度、リリース判断がある。

## Phase 3: リリース準備

Status: Todo

Goal:

- TestFlight / App Store に出せる状態へ整える。

Focus:

- 署名と bundle ID 確認。
- アプリアイコンと表示名。
- プライバシー説明と分析イベント説明。
- スクリーンショットとリリースノート。
- 最終回帰テスト。

なぜ必要か:

- なぜこの build は実ユーザーに出しても正直で安全と言えるのか？

Exit criteria:

- Release Manager が go/no-go を記録する。
- QA が対象デバイス/シミュレータで sign-off する。
- Reviewer が release diff を承認する。

## Phase 4: 学習効果の改善

Status: Later

Goal:

- 実利用やフィードバックをもとに、学習完了と理解を改善する。

Candidate work:

- 集中し直す候補の精度改善。
- 通知と Live Activity の復帰導線改善。
- ノートとタイムスタンプ復習の改善。
- ホームの動機づけ表現の調整。
- クラウド同期やアカウントが本当に必要か検討。

なぜ必要か:

- なぜこの変更は、複雑さではなく学習完了/理解を増やすのか？

Exit criteria:

- 判断が分析、ユーザーフィードバック、または明示的な開発者判断に基づいている。
