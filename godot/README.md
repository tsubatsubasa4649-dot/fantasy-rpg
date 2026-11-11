# Fantasy RPG — Phase 2: data foundation

**Godot 4 / GDScript** の独立したプロジェクト。既存のルート直下の HTML RPG は変更しない。

## 構成
- `project.godot` — Godotプロジェクト
- `data/` — 世界時期、キャラクター、イベント、ストーリーライン、エンディング、アイテムのJSON
- `scripts/content_registry.gd` — JSON読込、ID・参照検証
- `scripts/condition_evaluator.gd` — 宣言的条件評価
- `scripts/game_session.gd` — 世界時計、仲間、パーティ、イベント、ED、周回
- `scripts/save_store.gd` — セーブスロット（`user://saves/`）
- `scenes/main.tscn` — 読み込み確認のみの起動画面
- `tests/test_phase2.gd` — GDScriptでの一連の検証ケース

## 起動とテスト
Godot 4で `godot/project.godot` をインポートして起動。テストは実行環境にGodot 4があるPC等で:

```bash
godot --headless --path godot --script res://tests/test_phase2.gd
```

**現時点はフェーズ2であり、Godot側で探索・戦闘は未実装。** モバイルブラウザですぐ遊べるのは既存のHTML版。

## データの役割
`events.json` の `when` と `effects` に進行条件と変更結果を記述し、GDScriptは共通評価器／汎用ハンドラのみを持つ。仲間3人、物語ライン1本、独立ED2本のサンプルを含む。

`all` / `any` / `not` を入れ子にして条件を結合。原則として未知の述語は偽扱い。 `recruited` は控えを含む加入済み、`active` は現編成内。世界時期1–3は `world.json` の日数閾値で算出。

セーブはバージョン付きJSONで `user://saves/slot_N.json`。既存データを書き換える前に `.tmp` に書き込み、その後リネーム。現段階でクラウド同期、マイグレーション、暗号化、旧形式からの移行は未実装。

## 仕様確定
- 主人公＋仲間3人（計4人）
- 世界時計：宿泊1日、地域移動2日、重要イベント3日（数値は仮、JSON変更可能）
- プレイ時間：初回3–5時間が目標
- Godot 4独立版を構築する

## 次のフェーズで行うこと
小フィールドと洞窟、会話・時期別NPC、戦闘画面、二つのEDまで縦切り実装。生成PNG以外のキャラ・マップ素材をコードで描かない。

## 制限事項
このフェーズの実装は**コードレビューと静的チェック対象**であり、Godotランタイムでの実行確認は未実施。Godot本体が使える環境で `tests/test_phase2.gd` の結果を必ず確認すること。
