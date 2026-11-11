# フェーズ2 — JSONデータ契約と保存モデル v1

## マスターデータ（すべて `godot/data/`、UTF-8）
全ファイルのトップレベルは `{"schema_version":1,...}`。IDはASCIIの `snake_case` を原則とし、**公開後は変更しない**。

| ファイル | 配列・オブジェクト | 必須・主なフィールド |
|---|---|---|
| `world.json` | `phases[]` | `id:int` (1–3), `from_day:int`, `name:string` |
| `world.json` | `time_costs{}` | `rest`, `region_travel`, `major_event` など各行動に対する非負整数日数 |
| `characters.json` | `characters[]` | `id`, `name`, `role`, `is_hero`, `recruit` 条件、`event_id`（主人公以外） |
| `storylines.json` | `storylines[]` | `id`, `name`, `stages[]`; 各ステージは `id`, `when`, `event_id` |
| `events.json` | `events[]` | `id`, `when`, `effects[]`, `time_cost:int|string` |
| `endings.json` | `endings[]` | `id`, `name`, `when` |
| `items.json` | `items[]` | `id`, `name`, `carryover_allowed:boolean` |

**データとプログラムの境界**：条件ツリー・キャラごとの加入条件・段階・ED到達条件はJSON。GDScriptには一般演算子と「効果ハンドラ」だけを実装。新キャラを増やすだけなら原則GDScriptは変更不要。

## 条件式（再帰的・宣言的）
すべて**キー1個の辞書**。複数条件は `all` または `any` に入れる。未知の条件キーや空の `any` は**不成立**。

```json
{
  "all": [
    {"recruited": "ch_ricky"},
    {"recruited": "ch_meri"},
    {"active": "ch_meri"},
    {"phase_gte": 2},
    {"flag_is": ["bridge_evidence", true]}
  ]
}
```

| 演算子 | 値の型 | 内容 |
|---|---|---|
| `always` | boolean | `true` のとき成立 |
| `all` / `any` | condition[] | 全件／いずれか |
| `not` | condition | 否定 |
| `flag_is` | [name, value] | 周回内のフラグが指定値 |
| `meta_flag_is` | [name, value] | 周回を跨ぐフラグが指定値 |
| `recruited` | char_id | 控えも含む加入済み |
| `active` | char_id | 現在の4人以下の戦闘編成 |
| `phase_is` / `phase_gte` / `phase_lte` | int | 時期比較 |
| `day_gte` / `day_lte` | int | 経過日数比較 |
| `storyline_stage_is` | [story_id, stage_id] | 物語段階一致 |
| `ending_seen` | ending_id | 過去周回を含めて到達済み |
| `achievement_unlocked` | achievement_id | アチーブメント獲得済み |
| `loop_count_gte` | int | 周回回数以上 |
| `carryover_has` | item_id | 持込アイテム所持 |

将来の追加述語（例：地域滞在、関係性フラグ、NPC生死、手掛かり発見、所持数など）は条件評価器に追加し、既存述語の解釈は変更しない。

## イベントの効果
`effects` は配列で上から順に適用する。**事前に全効果を検証**してから反映し、部分的な進行失敗を避ける。

- `{"set_flag":["bridge_evidence",true]}` — 周回フラグ変更
- `{"recruit":"ch_meri"}` — 仲間加入。加入条件を二重チェック
- `{"set_storyline_stage":["bridge","start"]}` — ライン進行
- `time_cost` は0以上の整数か、`world.time_costs` のキー。実行できたときだけ世界時計を進める。

実装フェーズ2でのスコープはこの3効果のみ。ショップ、敵生成、アイテム増減、NPC移動、場面切替、ダイアログはフェーズ3以降に効果型を追加する。

## セーブ構造
```json
{
  "schema_version": 1,
  "state": {
    "day": 20, "phase": 2,
    "flags": {"village_helped": true},
    "recruited": ["ch_ricky", "ch_meri"],
    "party": ["hero", "ch_ricky", "ch_meri"],
    "storylines": {"bridge":"start"},
    "events_completed": ["help_village"],
    "items": [],
    "ending": "",
    "run_id": "stable-run-id"
  },
  "meta": {
    "schema_version": 1,
    "loop_count": 0,
    "achievements": [],
    "endings_seen": [],
    "unlocked_carryovers": [],
    "flags": {}
  }
}
```

- `state` は周回中だけ有効（参加者・イベント・時期など）。`meta` は周回を跨ぐ記録。
- `save_slot(1..5)` と `load_slot(1..5)` を提供。壊れたJSON・未知の保存形式は読み込まず、現セッションを壊さない。
- `finish(ending_id)` は達成条件を判定し、到達したEDのみ記録。`begin_next_loop(carryover[])` はED到達後のみ可能。
- 継承アイテムは `carryover_allowed` が真、かつメタで解放済みの物のみ、最大2個。レベル・編成・通常アイテム・世界時計・ストーリーフラグはリセット。
- **未実装**：セーブ暗号化、オンライン同期、セーブのスキーマ移行、メタ不整合の完全検証、複数端末の競合解決。

## フェーズ2終了時に決める論点
1. 世界時計のコスト（宿1／地域移動2／主要イベント3日）は仮のまま調整するか。
2. キャラの永久離脱・死亡時に `recruited` をどう解釈するか。
3. セーブスロット5つ、継承アイテム最大2つの妥当性。
4. データIDの命名規約・多言語テキストの分離（`dialogues_ja.json` 等）。
5. セーブ互換マイグレーションをフェーズ3の最優先にするか。
