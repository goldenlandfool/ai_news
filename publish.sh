#!/bin/bash
# 发布到 GitHub Pages —— 单一数据源模式
#
# 架构：/Library/WebServer/Documents/ai-news/news 是指向本仓库 news/ 的符号链接，
#       HTML 与音频在磁盘上只有一份实体，本地 Apache 与 GitHub Pages 共用。
#       因此这里不再复制任何文件，只负责生成索引页 + git 提交推送。
# 若本地 news/ 被还原成实体目录，脚本会直接报错退出，避免悄悄产生第二份副本。
set -e
SITE="/Library/WebServer/Documents/ai-news"
REPO="/Users/hsf/WorkBuddy/2026-09-29-08-46-48/ai-news-repo"

/Users/hsf/.workbuddy/binaries/python/versions/3.13.12/bin/python3 - "$SITE" "$REPO" << 'EOF'
import os, re, sys, datetime, html

SITE, REPO = sys.argv[1], sys.argv[2]
NEWS = f"{REPO}/news"

# --- 单一数据源断言 ---
if not os.path.islink(f"{SITE}/news"):
    sys.exit(f"ERROR: {SITE}/news 不是符号链接，会重新产生两份数据。请先运行迁移。")
if os.path.realpath(f"{SITE}/news") != os.path.realpath(NEWS):
    sys.exit(f"ERROR: {SITE}/news 指向 {os.path.realpath(f'{SITE}/news')}，期望 {NEWS}")

os.makedirs(f"{NEWS}/audio", exist_ok=True)

months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
files = sorted([f for f in os.listdir(NEWS)
                if f.startswith("ai_news_reading_") and f.endswith(".html")], reverse=True)
items = []
for f in files:
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(f"{NEWS}/{f}")).strftime("%Y-%m-%d %H:%M")
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

# index.html = GitHub Pages / 本地站点首页；indexs.html 同名副本，
# 兼容新闻页里历史写法 href="../indexs.html"（此前线上点返回目录会 404）。
for name in ("index.html", "indexs.html"):
    open(f"{REPO}/{name}", "w", encoding="utf-8").write(page)
if not os.path.exists(f"{REPO}/.nojekyll"):
    open(f"{REPO}/.nojekyll", "w").write("")
print("indexed:", len(files), "pages,", len([f for f in os.listdir(f'{NEWS}/audio') if f.endswith('.m4a')]), "audio files (single copy)")
EOF

cd "$REPO"
git add -A
if ! git diff --cached --quiet; then
  git commit -m "Update AI news reading site $(date +%Y-%m-%d)"
fi

# 即使本次没有新文件变更，也要检查是否存在「已提交但未推送」的历史提交。
# 否则「产物齐全但上次 push 失败」的情况会被 no changes 分支永久跳过。
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git ls-remote origin main | cut -f1)
if [ "$LOCAL" != "$REMOTE" ]; then
  git push origin main
  echo "pushed to GitHub: ${LOCAL:0:7}"
else
  echo "already up to date: ${LOCAL:0:7}"
fi
