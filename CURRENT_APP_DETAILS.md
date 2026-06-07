# Selova アプリ詳細

このメモは、**現在の Selova の実装状態**をざっくり把握できるようにまとめたものです。  
README の説明よりも、いまのコードに寄せて整理しています。

## 1. アプリの目的

Selova は、学習動画を短いセッションで見続けやすくするための iOS アプリです。  
TikTok のような「すぐ開いて、すぐ再生して、次の行動につながる」体験を学習向けに置き換えています。

主なねらいは次の通りです。

- 動画を見始めるまでの摩擦を下げる
- 視聴の続きから再開しやすくする
- フォルダで学習動画を整理する
- 視聴実績を XP とレベルに変換して、継続を促す

## 2. 画面構成

現状のメイン画面は 2 タブ構成です。

- ホーム
- ライブラリ

設定はホームからシートで開きます。  
動画再生はフルスクリーンの Study Feed で行います。

### 2-1. ホーム

ホームは、初回利用か継続利用かで見え方が変わります。

#### 初回利用

- アプリ名の表示
- 「動画を追加する」CTA
- 右上にヘルプと設定のボタン

#### 継続利用

- 今日の学習時間
- 昨日との差分メッセージ
- 連続学習日数
- レベル進捗バー
- 成長状態に応じたイラスト
- おすすめ動画の一覧
- 動画追加 CTA

ホームは `StudySession` と `VideoItem` を集計して、今日の学習量とおすすめを出しています。

### 2-2. ライブラリ

ライブラリは、フォルダと動画をまとめて管理する画面です。

- フォルダ一覧
- 動画一覧
- 検索
- 並び替え
- フォルダ作成
- フォルダ編集
- フォルダ削除
- 動画の移動
- 動画削除

フォルダは階層構造を持てます。  
各フォルダ内にサブフォルダと動画を置けます。

### 2-3. 動画追加シート

動画追加はホームまたはフォルダ詳細から開けます。  
対応ソースは次の 3 種です。

- ローカル動画
- YouTube
- Vimeo

ローカル動画は写真ライブラリまたはファイルピッカーから取り込みます。  
YouTube / Vimeo は URL を入力し、oEmbed からタイトルやサムネイルを取得します。

### 2-4. 学習フィード

Study Feed は動画を全画面で再生する画面です。  
縦スワイプのフィード風 UI を持ち、再生中は通常のタブ UI を隠します。

- ローカル動画は `AVPlayerViewController`
- YouTube / Vimeo は `WKWebView` で埋め込み再生
- 再生完了時に完了画面を表示
- 戻る操作に摩擦を持たせる
- 視聴時間と再生位置を保存する

### 2-5. 設定

設定画面では、離脱後の通知まわりを管理します。

- 離脱後の通知のオン / オフ
- 1 日の通知セット上限
- 通知許可状態の確認
- 通知拒否時に設定アプリへ誘導

## 3. データモデル

SwiftData を使っています。  
起動時に次のモデルを `ModelContainer` に登録しています。

- `FolderItem`
- `VideoItem`
- `StudySession`

### 3-1. FolderItem

フォルダ階層を表します。

- `id`
- `name`
- `createdAt`
- `children`
- `parent`
- `videos`

特徴:

- 親子関係を持てる
- 削除時は子フォルダと動画が連鎖削除される
- 同階層で同名フォルダは作れない

### 3-2. VideoItem

動画のメタデータです。

- `id`
- `title`
- `urlString`
- `typeRawValue`
- `createdAt`
- `duration`
- `watchedDuration`
- `lastWatchedAt`
- `lastPlaybackTime`
- `completionCount`
- `thumbnailData`
- `folder`

`VideoType` は次の 3 種です。

- `youtube`
- `vimeo`
- `local`

特徴:

- 最後の再生位置を保存
- 視聴完了回数を保存
- サムネイルを保存
- フォルダに所属できる

### 3-3. StudySession

学習セッションの履歴です。

- `id`
- `startTime`
- `duration`

ホームではこの履歴を集計して、今日の学習時間や継続日数を出しています。

## 4. 学習フロー

現在の基本フローは次の通りです。

1. ホームで動画を追加する
2. 保存先フォルダを選ぶ
3. 必要なら「今すぐ再生」を選ぶ
4. Study Feed で視聴する
5. 再生位置と視聴時間が保存される
6. ホームで XP とレベルが更新される

### 4-1. 追加後の挙動

動画を追加すると、保存完了後に「今すぐ再生 / あとで見る」の確認が出ます。  
「今すぐ再生」を選ぶと、いったんシートを閉じてから `activeVideo` に動画が入り、フルスクリーン再生に移ります。

### 4-2. 再生中の保存

Study Feed では、視聴中の位置と状態を随時保存します。

- ローカル動画: `AVPlayer` の現在位置を保存
- YouTube / Vimeo: WebView 側の進捗を保存
- 完了時: `lastPlaybackTime` を動画の長さに合わせ、`completionCount` を加算
- 離脱時: `StudySession` を 1 件追加

### 4-3. 通知

動画モードを 20 秒以上見たあとにアプリを閉じると、通知が予約されます。  
通知は 3 段階です。

- 即時
- 5 分後
- 10 分後

ただし、通知許可が必要です。  
また、1 日にセットできる回数には上限があります。

## 5. XP とレベル

ホームの成長表示は `StudyGrowth` で計算しています。

### XP の加点

- 1 分視聴ごとに 10 XP
- 連続学習 1 日ごとに 40 XP
- 動画完了 1 本ごとに 50 XP

### レベル進行

- XP が増えるとレベルが上がる
- 必要 XP はレベルが上がるほど増える
- レベルに応じて成長アセットが変わる

### 表示要素

- 今日の学習分数
- 前日との差分
- 連続学習日数
- 現在レベル
- 現在レベル内の XP 進捗

## 6. おすすめロジック

ホームのおすすめ一覧は `StudyProgress.recommendationScore` で並べ替えています。  
主な評価要素は次の通りです。

- 進捗が途中か、ほぼ完了か
- 最終視聴日からの経過日数
- 作成からの経過時間
- フォルダ所属の有無
- 現在のフォーカスフォルダとの一致
- ローカル動画かどうか

つまり、ただ新しい動画を出すのではなく、**続きから見やすい動画**や**今の集中に合う動画**を上に出す設計です。

## 7. 再生対応

### ローカル動画

- Documents ディレクトリに保存したファイルを読む
- `AVPlayerViewController` を使う
- 再生完了時にループ再生も扱う

### YouTube

- URL から動画 ID を抽出
- `youtube-nocookie.com` の埋め込み URL を使用
- `WKWebView` で再生

### Vimeo

- URL から動画 ID と必要なら hash を抽出
- `player.vimeo.com` の埋め込み URL を使用
- `WKWebView` で再生

## 8. 見た目の方向性

全体の見た目は、明るすぎない集中向けのトーンです。

- 背景は時間帯ベースのグラデーション
- 青とピンクをアクセントにしている
- カードはややガラスっぽい半透明
- フルスクリーン再生では暗めのシネマ寄り UI

`TikTokTheme` に色定義を集約していて、画面間で配色が揃うようになっています。

## 9. 主要ファイル

- `FocusVideoAppApp.swift`
- `ContentView.swift`
- `Views/Home/HomeView.swift`
- `Views/Home/ReturningHomeView.swift`
- `Views/StudyFeedView.swift`
- `Views/Library/LibraryView.swift`
- `Views/Settings/StudySettingsView.swift`
- `Views/Components/AddVideoSheet.swift`
- `Views/Components/RealVideoPlayer.swift`
- `Models/SwiftDataModels.swift`
- `StudyProgress.swift`
- `StudyGrowth.swift`
- `StudyPreferences.swift`
- `VideoEmbedURLBuilder.swift`

## 10. 補足

- 起動時のルートは `ContentView`
- 現在の実装は `FocusVideoApp` というアプリ名の構成で動いている
- 現在のコードベースでは、ホームとライブラリが主な操作入口
- Study Feed は縦横両対応だが、通常のアプリ全体はポートレート前提で始まる

