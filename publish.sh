#!/bin/bash
# 同步本地 Apache 站点到 GitHub Pages 仓库并推送
set -e
SRC="/Library/WebServer/Documents/ai-news"
REPO="/Users/hsf/WorkBuddy/2026-09-29-08-46-48/ai-news-repo"

/Users/hsf/.workbuddy/binaries/python/versions/3.13.12/bin/python3 - "$SRC" "$REPO" << 'EOF'
import os, re, shutil, sys, datetime, html

SRC, DST = sys.argv[1], sys.argv[2]
os.makedirs(f"{DST}/news/audio", exist_ok=True)

for f in os.listdir(f"{SRC}/news"):
    if f.endswith(".html"):
        s = open(f"{SRC}/news/{f}", encoding="utf-8").read()
        s = s.replace('href="../indexs.html"', 'href="../index.html"')
        open(f"{DST}/news/{f}", "w", encoding="utf-8").write(s)

for f in os.listdir(f"{SRC}/news/audio"):
    if f.endswith(".m4a"):
        shutil.copy2(f"{SRC}/news/audio/{f}", f"{DST}/news/audio/{f}")

months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
files = sorted([f for f in os.listdir(f"{DST}/news") if f.endswith(".html")], reverse=True)
items = []
for f in files:
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(f"{DST}/news/{f}")).strftime("%Y-%m-%d %H:%M")
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", f)
    title = f'{months[int(m.group(2))-1]} {int(m.group(3))}, {m.group(1)} AI News' if m else f
    items.append(f'<li><a href="news/{f}">{html.escape(title)}</a> <span class="time">{mtime}</span></li>')
items_html = "\n".join(items) if items else "<li><em>暂无朗读稿</em></li>"

page = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Daily AI News</title>
<style>
  body {{ font-family: "PingFang SC", "Helvetica Neue", Arial, sans-serif; max-width: 720px; margin: 0 auto; padding: 40px 24px; color: #2c3e50; background: #f7f9fb; }}
  h1 {{ font-size: 1.6em; color: #1a5276; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
  .sub {{ color: #7f8c8d; margin-bottom: 24px; }}
  ul {{ list-style: none; padding: 0; }}
  li {{ background: #fff; border: 1px solid #d6eaf8; border-radius: 8px; margin-bottom: 10px; padding: 14px 18px; transition: box-shadow .15s; }}
  li:hover {{ box-shadow: 0 2px 8px rgba(52,152,219,.25); }}
  a {{ color: #2980b9; text-decoration: none; font-size: 1.05em; font-weight: 500; }}
  a:hover {{ text-decoration: underline; }}
  .time {{ float: right; color: #95a5a6; font-size: 0.85em; }}
</style>
</head>
<body>
<h1>📚 Daily AI News</h1>
<p class="sub">每天早上 8:30 自动更新</p>
<ul>
{items_html}
</ul>
</body>
</html>
"""
open(f"{DST}/index.html", "w", encoding="utf-8").write(page)
if not os.path.exists(f"{DST}/.nojekyll"):
    open(f"{DST}/.nojekyll", "w").write("")
print("synced:", len(files), "pages,", len(os.listdir(f'{DST}/news/audio')), "audio files")
EOF

cd "$REPO"
git add -A
if git diff --cached --quiet; then
  echo "no changes to publish"
else
  git commit -m "Update AI news reading site $(date +%Y-%m-%d)"
  git push origin main
  echo "pushed to GitHub"
fi
