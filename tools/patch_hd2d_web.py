#!/usr/bin/env python3
"""Improve Godot 4.3 web startup diagnostics for mobile Safari and stale caches.

Called after Godot's generated index.html is exported. Keeps Godot's
auto-generated bootloader intact and only injects independent error UI.
"""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_hd2d_web.py PATH_TO_EXPORTED_INDEX.HTML")

index = Path(sys.argv[1])
html = index.read_text(encoding="utf-8")
if 'const GODOT_CONFIG' not in html or 'const engine = new Engine(GODOT_CONFIG)' not in html:
    raise SystemExit("Cannot find Godot 4.3 web loader in " + str(index))
if 'id="hd2d-recovery"' in html:
    raise SystemExit("Web loader already patched")

support = r'''
<style>
#hd2d-recovery {
  display:none;position:fixed;z-index:9999;inset:0;overflow:auto;
  background:rgba(11,14,22,.96);color:#fff5e3;
  font:16px/1.55 -apple-system,BlinkMacSystemFont,"Noto Sans JP",sans-serif;
  padding:env(safe-area-inset-top,16px) 18px env(safe-area-inset-bottom,16px);
}
#hd2d-recovery .inner{max-width:560px;margin:8vh auto 0}
#hd2d-recovery h2{font-size:22px;margin:0 0 12px;color:#f9ca8a}
#hd2d-recovery pre{white-space:pre-wrap;word-break:break-word;font:12px/1.5 monospace;
  background:#252835;border:1px solid #69645e;border-radius:8px;padding:10px;max-height:28vh;overflow:auto}
#hd2d-recovery .links{display:flex;flex-wrap:wrap;gap:10px;margin:15px 0}
#hd2d-recovery a,#hd2d-recovery button{background:#443324;color:#fff;padding:12px 14px;border:1px solid #dfac6d;
  border-radius:8px;font-size:16px;text-decoration:none;cursor:pointer}
#hd2d-recovery small{color:#c0b9ac}
</style>
<section id="hd2d-recovery" aria-live="assertive" role="alert">
 <div class="inner">
  <h2>HD-2D版を起動できませんでした</h2>
  <p>GodotのWeb版は端末やブラウザによって起動できないことがあります。ChatGPT内のブラウザで開いている場合は、URLをコピーしてSafariに直接貼り付けてください。</p>
  <pre id="hd2d-error"></pre>
  <div class="links">
   <button id="hd2d-retry" type="button">再読み込み</button>
   <button id="hd2d-copy" type="button">エラー情報をコピー</button>
   <a href="../">以前の2D版で遊ぶ</a>
  </div>
  <small>再読み込みしても失敗する場合は「エラー情報をコピー」で内容を教えてください。iPhone実機での動作は端末依存です。</small>
 </div>
</section>
<script>
(function() {
 "use strict";
 const panel = document.getElementById("hd2d-recovery");
 const output = document.getElementById("hd2d-error");
 const overlay = document.getElementById("status");
 const notice = document.getElementById("status-notice");
 let fatal = "";
 function show(message) {
   if (fatal) return;
   fatal = String(message || "原因不明の起動エラー");
   output.textContent = fatal;
   panel.style.display = "block";
 }
 document.getElementById("hd2d-retry").onclick = () => location.reload();
 document.getElementById("hd2d-copy").onclick = async () => {
   const detail = "終わりの地図 / HD-2D\n" + fatal + "\n" + navigator.userAgent + "\n" + location.href;
   try {
     await navigator.clipboard.writeText(detail);
     document.getElementById("hd2d-copy").textContent = "コピーしました";
   } catch (_err) {
     const entry = document.createElement("textarea");
     entry.value = detail;entry.style.position="absolute";entry.style.left="-9999px";
     panel.appendChild(entry);entry.select();
     try {document.execCommand("copy")} catch (_ignored) {}
     entry.remove();
   }
 };
 function checkNotice() {
   if (notice && notice.textContent.trim().length > 0 &&
       overlay && overlay.style.visibility !== "hidden") {
     show(notice.textContent.trim());
   }
 }
 if (notice) {
   new MutationObserver(checkNotice).observe(notice,{childList:true,subtree:true,characterData:true});
   checkNotice();
 }
 window.addEventListener("unhandledrejection", event => {
   const text = String(event.reason?.message || event.reason || "");
   if (/webgl|wasm|memory|abort|godot|fetch|network|runtime/i.test(text)) show(text);
 });
 const canvas = document.getElementById("canvas");
 if (canvas) {
   canvas.addEventListener("webglcontextlost", event => {
     event.preventDefault();
     show("WebGLの描画コンテキストが失われました。iPhoneのGPUメモリ不足やブラウザの制限が考えられます。");
   },false);
 }
 setTimeout(() => {
   if (document.getElementById("status") &&
       document.getElementById("status").style.visibility !== "hidden") {
     show("起動が60秒以上完了しません。通信状況、WebGL 2.0対応、ブラウザメモリを確認してください。");
   }
 },60000);
})();
</script>
'''
html=html.replace("</body>", support + "\n</body>", 1)
index.write_text(html, encoding="utf-8")
print("Patched HD-2D mobile error overlay", index, "bytes", index.stat().st_size)
