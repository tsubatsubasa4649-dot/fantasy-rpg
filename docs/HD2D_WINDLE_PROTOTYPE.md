# 終わりの地図 — HD-2Dウィンドル村試作

## 目的と実装内容
夕暮れの村のコンセプト画像を**目標美術**として、Godot 4.3 Compatibility / WebGL 2 に対応する実際の3D探索マップを追加した。

- 別シーン \`res://scenes/hd2d_village.tscn\`。既存の2D RPGとセーブデータは変更しない
- 斜め見下ろし3Dカメラ＋追従、オレンジ色の夕日、建物・井戸・階段・木・ランタンの3Dメッシュ
- **既存の画像素材** \`village_atlas.b64\` を地面に、\`hero_walk.b64\` と \`npc_idle_atlas.b64\` をSprite3Dに使用（タイル模様・ドット絵のコード生成なし）
- 方向キー / WASD / スマホ画面ボタンで移動、近距離で村人5人と会話
- 建物・井戸への当たり判定、従来の2D版に戻るボタン
- 実Godotでのスモークテスト、Webビルド、3Dスクリーンショット撮影用スクリプト

## 試す方法
Godot: \`godot/scenes/hd2d_village.tscn\` を開いてF6で実行（日本語フォントが必要。既存CIがライセンス確認の上取得する）。

GitHub Pagesに公開後:
\`https://tsubatsubasa4649-dot.github.io/fantasy-rpg/godot-play/hd2d/\`

既存2Dゲーム:
\`https://tsubatsubasa4649-dot.github.io/fantasy-rpg/godot-play/\`

## 現段階の限界
- これは本格HD-2D制作への**操作可能な技術実証版**であり、目標画像と同じ造形密度ではない。背景そのものを貼った疑似ゲームではない
- 建物や樹木は軽量なジオメトリ。将来的には専用3Dモデル、手描きテクスチャ、壁面装飾、パーティHUDやカメラ演出を制作する
- 既存の会話イベント・仲間加入・戦闘・セーブは**この3D試作シーンには未接続**。既存2D側では従来通り利用可能
- スマホ実機でのFPS、レンダラー依存、負荷、操作性は別途確認する

## CI
\`test_hd2d.gd\` が実シーン・地形素材・歩行と会話を検証。 \`capture_hd2d.gd\` がGodotの実描画を \`godot-play/hd2d/village-screen.png\` に出力。メインの2D Webページを変更せず、別パスにHD-2D Web版を作成。
