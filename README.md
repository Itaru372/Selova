# Selova

集中支援型 iOS アプリ。

TikTok のスクロール体験を学習動画に応用し、短いセッションで継続学習を促進します。

## 主な機能
- フルスクリーン学習フィード（縦スワイプでページ遷移）
- 動画の再生位置や視聴時間の保存（中断・再開対応）
- フォルダによるライブラリ管理
- ローカル動画再生（AVKit）および外部動画のサポート
- 視聴セッション（StudySession）の記録

## 技術スタック
- Swift / SwiftUI
- SwiftData（モデル: `FolderItem`, `VideoItem`, `StudySession`）
- AVKit（動画再生）

## 主なモデル
- FolderItem: フォルダ階層と動画のグループ化
- VideoItem: 動画メタデータ（タイトル、URL、再生位置、サムネイル等）
- StudySession: 視聴セッションの記録（開始時刻、継続時間）

## ビルドと実行
1. Xcode 15 以上で開く（SwiftData を使用しているため iOS 17 / macOS 14 以降が必要な場合があります）
2. `FocusVideoApp.xcodeproj` を Xcode で開く
3. ターゲットの署名設定を行い、実機またはシミュレータでビルド・実行

### ローカル動画について
ローカル再生はアプリの Documents ディレクトリ内のファイル名を `VideoItem.urlString` に設定して利用します。

## 貢献
Issue / PR を歓迎します。

## 作者
岡崎格
