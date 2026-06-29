# Selova Decisions

Last updated: 2026-06-28

Decision states: `Provisional`, `Accepted`, `Revisit`.

## D-001: 会社型エージェント役割を使う

State: Provisional

Decision:

- PM、Designer、iOS Engineer、QA、Reviewer、Release Manager の役割で計画・実装・確認を進める。
- CTO / Development Lead が順序と責任範囲を調整する。

Reason:

- ユーザーが会社型エージェント体制での開発を希望しているため。

Revisit when:

- 小さな変更に対してプロセスが重くなりすぎたとき。

## D-002: 仕様先行で、いきなり実装しない

State: Provisional

Decision:

- 新機能は、現在のコード調査、ビルド/テスト入口確認、関連 docs 更新をしてから実装する。

Reason:

- リポジトリには Xcode target、Live Activity、SwiftData、通知、分析など複数の境界がある。文脈なしの実装は壊しやすい。

Revisit when:

- 明確な受け入れ条件がある小さな bug fix の場合。

## D-003: 公開名は Selova、内部 Xcode 名は FocusVideoApp のまま扱う

State: Provisional

Decision:

- ユーザー向けのプロダクト名は `Selova`。
- `FocusVideoApp.xcodeproj`、scheme `FocusVideoApp`、target `FocusVideoApp`、test import `FocusVideoApp` は、専用の移行タスクがない限り維持する。

Reason:

- 現在の Xcode project / scheme / module / test が `FocusVideoApp` に依存している。
- 表示名と主要 bundle ID は `Selova` 側に揃っている。

Revisit when:

- 内部名の全面移行に見合う理由と検証時間があるとき。

## D-004: ビルド経路は Xcode project と shared scheme を使う

State: Provisional

Decision:

- `FocusVideoApp.xcodeproj` と scheme `FocusVideoApp` で build/test する。
- 実行確認は XcodeBuildMCP または Xcode を優先する。
- CLI の参考経路は `xcodebuild` + iOS Simulator destination とする。

Reason:

- shared scheme に app と `FocusVideoAppTests` が含まれている。
- `.xcodebuildmcp/config.yaml` に project、scheme、Debug configuration、`iPhone 17` simulator profile が記録されている。

Revisit when:

- workspace 化、Swift Package 化、または scheme 分割を行ったとき。

## D-005: 初回リリース範囲を仮固定する

State: Provisional

Decision:

- 初回リリースの約束を「保存した学習動画を、フォルダごとに続きから再開し、1本ずつ最後まで見やすくする」と仮固定する。
- Must: ホーム、ライブラリ、動画追加、学習フィード、進捗保存、基本 QA。
- Should: 基本ノート、通知設定、集中の記録。
- Later: Live Activity 主役化、高度な分析 dashboard、クラウド同期、アカウント、AI チューター。

Reason:

- 初回リリースでは、追加した動画を迷わず再開し、見終えることが最重要のユーザー価値になるため。

Revisit when:

- ユーザーが別の初回リリース約束を明示したとき。

## D-006: 各機能に学習者中心の「なぜ」を残す

State: Provisional

Decision:

- 各機能は、受け入れ前に「なぜ学習者に必要か？」を見える形で残す。

Reason:

- Selova は動機づけ UI、通知、分析、整理機能が増えやすい。学習への効果で絞り込む必要がある。

Revisit when:

- 実利用データと安定した機能戦略ができたとき。

## D-007: デフォルトは CTO が受け、自動で役割を切り替える

State: Provisional

Decision:

- ユーザーが毎回「PMとして」「Designerとして」などを入力しなくてもよい運用にする。
- Codex はデフォルトで CTO 兼 開発統括として依頼を受け、内容に応じて PM / Designer / iOS Engineer / QA / Reviewer / Release Manager を内部的に選ぶ。
- ユーザーが役割を明示した場合だけ、その役割を優先する。

Reason:

- 毎回役割名を入力する運用は摩擦が大きい。CTO が自動ルーティングする方が、会社型体制を保ちながら日常的に使いやすい。

Revisit when:

- 自動判断が重すぎる、またはユーザーが明示的な役割指定運用へ戻したいとき。

## D-008: 多言語対応は日本語既定・英語追加から始める

State: Provisional

Decision:

- `developmentRegion = ja` を維持し、日本語を既定言語として扱う。
- 初回の追加言語は英語にする。
- SwiftUI の自然言語キーと String Catalog を使い、内部 target / scheme / bundle ID は変更しない。

Reason:

- 既存文言は日本語で設計されているため、日本語の低圧な学習支援トーンを基準にしたまま海外端末でも最低限読める状態にする。
- target 名や bundle 名の変更を伴わず、学習ループの既存実装に影響を出しにくい。

Why Needed Question:

- なぜ学習者に必要か？: 端末言語が英語のユーザーでも、動画追加・再開・通知・エラーの意味が分かり、学習を止めにくくするため。

Revisit when:

- 英語以外の対応言語を追加するとき。
- App Store metadata やスクリーンショットを多言語で用意するとき。
- 英語訳を実ユーザーまたはネイティブレビューで調整するとき。

## Open Questions

- 最初に重視するユーザー層は誰か？
- 通知と Live Activity は初回リリースに含めるか？
- 分析を有効にする前に、ユーザーへどのプライバシー文言を見せるか？
- iOS `26.5` deployment target は現在のリリース計画として意図したものか？
- 古い config と active profile の bundle ID 差分は整理すべきか？

## Verification Log

### V-001: Baseline test and build

Date: 2026-06-25

Result:

- XcodeBuildMCP `session_show_defaults`: active profile `live` confirmed.
- XcodeBuildMCP `test_sim`: succeeded, 14 passed / 0 failed.
- XcodeBuildMCP `build_sim`: succeeded, warnings 0 / errors 0.

Reason:

- 機能実装前に、現在の baseline が壊れていないことを確認するため。
