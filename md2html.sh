#!/usr/bin/env bash
# =============================================================================
# md2html.sh — 将目录下所有 Markdown 文件批量转换为匹配 Alex.D 样式的 HTML
#
# 用法：
#   chmod +x md2html.sh
#   ./md2html.sh [md目录] [输出目录]
#
# 示例：
#   ./md2html.sh ./posts ./dist
#   ./md2html.sh                  # 默认：当前目录 → ./dist
#
# MD 文件支持 YAML Frontmatter（可选）：
#   ---
#   title: 文章标题
#   date: 2024-01-15
#   category: Front-end Development
#   tags: CSS, WebDesign, Grid
#   back_url: index.html          # "返回" 链接，默认 index.html
#   ---
#
# 依赖：pandoc（用于 Markdown → HTML 转换）
#   macOS:  brew install pandoc
#   Ubuntu: sudo apt install pandoc
# =============================================================================

set -euo pipefail

# =============================================================================
# 站点配置 — 在这里修改你的博客名称和副标题
# =============================================================================
SITE_NAME="dywsun"
SITE_DESC="思绪来得快，去得也快，何不执笔留下。"
# =============================================================================

# ─── 颜色输出 ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'; BOLD='\033[1m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ─── 参数处理 ─────────────────────────────────────────────────────────────────
MD_DIR="${1:-.}"
OUT_DIR="${2:-./dist}"

# ─── 依赖检查 ─────────────────────────────────────────────────────────────────
if ! command -v pandoc &>/dev/null; then
    log_error "未找到 pandoc，请先安装："
    echo "  macOS:  brew install pandoc"
    echo "  Ubuntu: sudo apt install pandoc"
    exit 1
fi

# ─── 输出目录 ─────────────────────────────────────────────────────────────────
mkdir -p "$OUT_DIR"

# ─── Frontmatter 解析函数 ─────────────────────────────────────────────────────
# 用法：get_frontmatter_field <file> <field>
# 返回对应字段的值（无 YAML 时返回空字符串）
get_frontmatter_field() {
    local file="$1"
    local field="$2"
    # 检查是否有 YAML frontmatter（文件以 --- 开头）
    if ! head -1 "$file" | grep -q '^---'; then
        echo ""
        return
    fi
    # 提取 --- 之间的内容，找到对应字段
    awk "
        /^---/ { count++; next }
        count == 1 && /^${field}:/ {
            sub(/^${field}:[[:space:]]*/, \"\")
            print
            exit
        }
        count == 2 { exit }
    " "$file"
}

# ─── 去除 Frontmatter，返回纯 Markdown 正文 ──────────────────────────────────
strip_frontmatter() {
    local file="$1"
    if ! head -1 "$file" | grep -q '^---'; then
        cat "$file"
        return
    fi
    awk '
        /^---/ { count++; next }
        count >= 2 { print }
    ' "$file"
}

get_markdown_title() {
    local file="$1"
    strip_frontmatter "$file" \
    | awk '
        /^[[:space:]]*#/ {
            sub(/^[[:space:]]*#+[[:space:]]*/, "")
            print
            exit
        }
    '
}

strip_article_body() {
    local file="$1"
    local has_frontmatter_title="$2"
    if [[ -n "$has_frontmatter_title" ]]; then
        strip_frontmatter "$file"
        return
    fi

    strip_frontmatter "$file" \
    | awk '
        !skipped && /^[[:space:]]*#[[:space:]]/ { skipped = 1; next }
        { print }
    '
}

html_escape() {
    sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g'
}

js_escape() {
    sed \
        -e 's/\\/\\\\/g' \
        -e "s/'/\\\\'/g" \
        -e 's/<\/script>/<\\\/script>/g'
}

shared_css() {
    cat <<'CSS'
:root {
    --page: #f7f3ea;
    --surface: #fbfaf4;
    --surface-soft: #f1f4ea;
    --surface-hover: #fffdf7;
    --text: #34382f;
    --muted: #7d8375;
    --subtle: #a4aa99;
    --line: #e3e0d4;
    --accent: #7f9371;
    --accent-dark: #637458;
    --shadow: 0 12px 32px rgba(83, 78, 61, 0.055);
    --radius: 6px;
    --content: 600px;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
    margin: 0;
    min-height: 100vh;
    background:
        linear-gradient(180deg, rgba(255,255,255,0.36), rgba(255,255,255,0) 280px),
        var(--page);
    color: var(--text);
    font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
    line-height: 1.7;
}
a { color: inherit; text-decoration: none; }
button, input { font: inherit; }
.site-shell {
    width: min(100% - 36px, var(--content));
    margin: 0 auto;
}
.site-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 24px;
    padding: 30px 0 24px;
}
.brand {
    color: var(--text);
    font-family: Georgia, "Times New Roman", "Songti SC", serif;
    font-size: clamp(1.38rem, 2.4vw, 1.72rem);
    font-weight: 600;
    letter-spacing: 0;
}
.site-nav {
    display: flex;
    align-items: center;
    gap: clamp(14px, 3vw, 24px);
    color: var(--muted);
    font-size: 0.92rem;
}
.site-nav a {
    position: relative;
    padding: 4px 0;
}
.site-nav a::after {
    position: absolute;
    right: 0;
    bottom: 0;
    left: 0;
    height: 1px;
    background: var(--accent);
    content: "";
    opacity: 0;
    transform: scaleX(0.4);
    transition: 180ms ease;
}
.site-nav a:hover,
.site-nav a.is-active { color: var(--accent-dark); }
.site-nav a:hover::after,
.site-nav a.is-active::after {
    opacity: 1;
    transform: scaleX(1);
}
.site-main { padding-bottom: 72px; }
.intro {
    max-width: var(--content);
    margin: 8px auto 28px;
}
.intro h1,
.page-title {
    margin: 0;
    color: var(--text);
    font-family: Georgia, "Times New Roman", "Songti SC", serif;
    font-size: clamp(1.08rem, 2vw, 1.3rem);
    font-weight: 500;
    letter-spacing: 0;
    line-height: 1.32;
}
.page-copy {
    max-width: 620px;
    margin: 18px 0 0;
    color: var(--muted);
    font-size: clamp(1rem, 2vw, 1.1rem);
}
.post-list,
.category-list,
.archive-list,
.search-panel,
.article-page {
    width: min(100%, var(--content));
    margin: 0 auto;
}
.post-list {
    display: grid;
    gap: 14px;
}
.post-card {
    display: block;
    padding: clamp(18px, 2.4vw, 24px);
    border: 1px solid rgba(145,151,126,0.18);
    border-radius: var(--radius);
    background: color-mix(in srgb, var(--surface) 86%, var(--surface-soft));
    box-shadow: var(--shadow);
    transition: transform 160ms ease, border-color 160ms ease, background 160ms ease;
}
.post-card:hover {
    border-color: rgba(127,147,113,0.36);
    background: var(--surface-hover);
    transform: translateY(-2px);
}
.post-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    align-items: center;
    margin-bottom: 8px;
    color: var(--accent-dark);
    font-size: 0.78rem;
}
.post-meta span + span::before {
    margin-right: 10px;
    color: var(--subtle);
    content: "/";
}
.post-title {
    margin: 0;
    color: var(--text);
    font-size: clamp(0.98rem, 1.65vw, 1.16rem);
    font-weight: 650;
    line-height: 1.35;
}
.post-excerpt {
    display: -webkit-box;
    margin: 12px 0 0;
    overflow: hidden;
    color: var(--muted);
    font-size: 0.88rem;
    line-height: 1.68;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 3;
}
.load-more-wrap {
    display: flex;
    justify-content: center;
    width: min(100%, var(--content));
    margin: 24px auto 0;
}
.load-more-button {
    min-width: 144px;
    min-height: 38px;
    padding: 8px 16px;
    border: 1px solid rgba(145,151,126,0.28);
    border-radius: var(--radius);
    background: var(--surface);
    color: var(--muted);
    cursor: pointer;
    font-size: 0.82rem;
    transition: border-color 160ms ease, background 160ms ease, color 160ms ease;
}
.load-more-button span {
    margin-left: 8px;
    color: var(--subtle);
}
.load-more-button:hover,
.load-more-button:focus-visible {
    border-color: rgba(127,147,113,0.48);
    background: var(--surface-hover);
    color: var(--accent-dark);
    outline: 0;
}
.category-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16px;
    margin-top: 28px;
}
.category-card {
    display: block;
    width: 100%;
    padding: 22px;
    border: 1px solid rgba(145,151,126,0.2);
    border-radius: var(--radius);
    background: var(--surface);
    color: inherit;
    cursor: pointer;
    box-shadow: var(--shadow);
    text-align: center;
    transition: transform 160ms ease, border-color 160ms ease, background 160ms ease;
}
.category-card:hover,
.category-card:focus-visible {
    border-color: rgba(127,147,113,0.38);
    background: var(--surface-hover);
    outline: 0;
    transform: translateY(-2px);
}
.category-card h2 {
    margin: 0 0 8px;
    font-size: 1.22rem;
}
.category-card p {
    margin: 0;
    color: var(--muted);
}
.clear-button {
    margin-top: 16px;
    padding: 0;
    border: 0;
    background: transparent;
    color: var(--accent-dark);
    cursor: pointer;
}
.archive-list {
    display: grid;
    gap: 30px;
}
.archive-group { padding: 0; }
.archive-group h2 {
    margin: 0 0 14px;
    color: var(--accent-dark);
    font-size: 1rem;
    font-weight: 650;
}
.archive-items {
    display: grid;
    gap: 7px;
}
.archive-item {
    display: grid;
    grid-template-columns: 54px minmax(0, 1fr);
    gap: 14px;
    align-items: baseline;
    padding: 5px 0;
    border-bottom: 1px solid rgba(145,151,126,0.14);
    color: var(--text);
    font-size: 0.88rem;
}
.archive-item:last-child { border-bottom: 0; }
.archive-item time {
    color: var(--subtle);
    font-size: 0.78rem;
}
.archive-item span {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.archive-item:hover span,
.archive-item:focus-visible span {
    color: var(--accent-dark);
    text-decoration: underline;
    text-underline-offset: 4px;
}
.search-box {
    display: grid;
    gap: 12px;
    margin: 30px 0 24px;
}
.search-box input {
    width: 100%;
    padding: 15px 16px;
    border: 1px solid rgba(145,151,126,0.34);
    border-radius: var(--radius);
    outline: 0;
    background: var(--surface);
    color: var(--text);
    box-shadow: var(--shadow);
}
.search-box input:focus { border-color: var(--accent); }
.empty-state {
    padding: 28px;
    border: 1px dashed rgba(145,151,126,0.38);
    border-radius: var(--radius);
    color: var(--muted);
    text-align: center;
}
.article-page { padding-top: 12px; }
.back-link {
    display: inline-flex;
    margin-bottom: 26px;
    color: var(--accent-dark);
}
.article-header { margin-bottom: 34px; }
.article-title {
    margin: 0 0 12px;
    font-family: Georgia, "Times New Roman", "Songti SC", serif;
    font-size: clamp(1.08rem, 2.2vw, 1.42rem);
    font-weight: 500;
    line-height: 1.18;
}
.article-body {
    padding: clamp(20px, 3.5vw, 36px);
    border: 1px solid rgba(145,151,126,0.18);
    border-radius: var(--radius);
    background: var(--surface);
    box-shadow: var(--shadow);
}
.article-body p {
    margin: 0 0 1.25em;
    color: #4a4f43;
    font-size: 0.92rem;
    line-height: 1.78;
}
.article-body h1,
.article-body h2 {
    margin: 2em 0 0.8em;
    font-size: 1.08rem;
    line-height: 1.35;
}
.article-body h3 {
    margin: 1.8em 0 0.7em;
    font-size: 1rem;
}
.article-body blockquote {
    margin: 1.6em 0;
    padding: 6px 0 6px 18px;
    border-left: 3px solid var(--accent);
    color: var(--accent-dark);
}
.article-body code {
    padding: 0.12em 0.34em;
    border-radius: 4px;
    background: #ecebdd;
    color: #4f5b46;
    font-size: 0.92em;
}
.article-body pre {
    overflow: auto;
    padding: 16px;
    border-radius: var(--radius);
    background: #34382f;
    color: #f5f0e5;
    line-height: 1.55;
}
.article-body pre code {
    padding: 0;
    background: transparent;
    color: inherit;
}
.article-body ul,
.article-body ol {
    margin: 0 0 1.25em;
    padding-left: 1.4em;
    color: #4a4f43;
    font-size: 0.92rem;
}
.article-body table {
    width: 100%;
    border-collapse: collapse;
    margin: 1.4em 0;
    color: #4a4f43;
    font-size: 0.86rem;
}
.article-body th,
.article-body td {
    padding: 8px 10px;
    border-bottom: 1px solid var(--line);
    text-align: left;
}
.article-body hr {
    border: 0;
    border-top: 1px solid var(--line);
    margin: 1.6em 0;
}
.article-body img {
    max-width: 100%;
    height: auto;
    border-radius: var(--radius);
}
@media (max-width: 720px) {
    .site-shell { width: min(100% - 28px, var(--content)); }
    .site-header { padding: 22px 0 18px; }
    .site-nav { gap: 12px; font-size: 0.88rem; }
    .intro { margin: 6px auto 22px; }
    .category-grid { grid-template-columns: 1fr; }
    .post-card { padding: 18px; }
    .post-excerpt { -webkit-line-clamp: 2; }
    .load-more-wrap { margin-top: 20px; }
    .load-more-button { width: 100%; min-height: 36px; font-size: 0.78rem; }
    .archive-item { grid-template-columns: 48px minmax(0, 1fr); gap: 10px; font-size: 0.84rem; }
    .article-header { margin-bottom: 24px; }
    .article-body { padding: 20px; }
}
@media (max-width: 420px) {
    .site-header { gap: 18px; }
    .site-nav { gap: 12px; }
}
CSS
}

# ─── 提取摘要：取正文前若干个纯文字句子，约 120 字 ─────────────────────────────
get_excerpt() {
    local file="$1"
    strip_frontmatter "$file" \
    | awk '
        /^```/          { in_code = !in_code; next }
        in_code         { next }
        /^[[:space:]]*$/ { next }
        /^#+[[:space:]]/ { next }          # 跳过标题行
        /^>/             { next }          # 跳过引用块
        /^[-*+][[:space:]]/ { next }       # 跳过列表项
        /^[0-9]+\./     { next }           # 跳过有序列表
        /^\[.*\]:/      { next }           # 跳过链接定义
        { print; count++; if (count >= 3) exit }
    ' \
    | sed \
        -e 's/!\[[^]]*\]([^)]*)//g' \
        -e 's/\[\([^]]*\)\]([^)]*)/\1/g' \
        -e 's/\*\*\([^*]*\)\*\*/\1/g' \
        -e 's/\*\([^*]*\)\*/\1/g' \
        -e 's/`[^`]*`//g' \
        -e 's/^[[:space:]]*//' \
    | tr '\n' ' ' \
    | sed 's/[[:space:]]\+/ /g' \
    | cut -c1-160
}

# ─── 将 tags 字符串转为 HTML span 标签 ───────────────────────────────────────
render_tags() {
    local tags_str="$1"
    if [[ -z "$tags_str" ]]; then
        echo ""
        return
    fi
    local result=""
    IFS=',' read -ra tag_arr <<< "$tags_str"
    for tag in "${tag_arr[@]}"; do
        tag="${tag#"${tag%%[![:space:]]*}"}"   # ltrim
        tag="${tag%"${tag##*[![:space:]]}"}"   # rtrim
        result+="<span class=\"tag\">#${tag}</span>"
    done
    echo "$result"
}

# ─── 主 HTML 模板生成函数 ─────────────────────────────────────────────────────
generate_html() {
    local title="$1"
    local date_str="$2"
    local category="$3"
    local tags_html="$4"
    local back_url="$5"
    local body_html="$6"

    cat <<HTML
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
    <link href="https://cdn.jsdelivr.net/npm/remixicon@3.5.0/fonts/remixicon.css" rel="stylesheet">
    <style>
        :root {
            --bg-color: #FCF7EE;
            --board-bg: #FFFFFF;
            --text-main: #180A00;
            --text-light: #AA7A42;
            --line-color: #E0C8A0;
            --font-size-content: 13px;
            --font-size-title: 16px;
            --accent-color: #B06820;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            -webkit-font-smoothing: antialiased;
            min-height: 100vh;
            display: flex;
            justify-content: center;
        }
        a { text-decoration: none; transition: opacity 0.2s; }
        .content-board {
            width: 640px;
            background-color: var(--board-bg);
            display: flex;
            flex-direction: column;
            min-height: 100vh;
            padding: 40px 50px;
            box-shadow: 0 0 20px rgba(0,0,0,0.05);
        }
        .back-link {
            display: inline-flex;
            align-items: center;
            font-size: var(--font-size-content);
            color: var(--text-light);
            margin-bottom: 30px;
            cursor: pointer;
            flex-shrink: 0;
        }
        .back-link i { margin-right: 5px; }
        .back-link:hover { color: var(--text-main); }
        .post-header {
            margin-bottom: 40px;
            border-bottom: 1px solid var(--line-color);
            padding-bottom: 30px;
            flex-shrink: 0;
        }
        .post-meta {
            font-size: 12px;
            color: var(--text-light);
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .post-title {
            font-size: 22px;
            font-weight: 700;
            line-height: 1.3;
            color: var(--text-main);
            font-family: "Georgia", serif;
        }
        .post-content {
            font-size: var(--font-size-content);
            line-height: 1.85;
            color: var(--text-main);
            flex: 1;
        }
        .post-content p { margin-bottom: 1.5em; text-align: justify; }
        .post-content a { color: var(--accent-color); border-bottom: 1px dotted var(--accent-color); }
        .post-content h2 {
            font-size: var(--font-size-title);
            font-weight: 700;
            margin-top: 2.5em;
            margin-bottom: 1em;
            padding-bottom: 0.5em;
            border-bottom: 1px solid var(--line-color);
            font-family: -apple-system, sans-serif;
        }
        .post-content h3 { font-size: 14px; font-weight: 700; margin-top: 2em; margin-bottom: 0.8em; color: #333; }
        /* ── 代码块容器 ── */
        .code-block {
            position: relative;
            margin-bottom: 1.5em;
            border-radius: 6px;
            border: 1px solid #D8C090;
            overflow: hidden;
        }
        /* 顶栏：语言标志 + 复制按钮 */
        .code-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background-color: #EDD5A8;
            padding: 5px 12px;
            border-bottom: 1px solid #D8C090;
            min-height: 30px;
        }
        .code-lang {
            font-family: "Menlo", "Monaco", "Consolas", monospace;
            font-size: 10px;
            color: var(--text-light);
            text-transform: lowercase;
            letter-spacing: 0.5px;
            user-select: none;
        }
        /* 无语言时隐藏标签但保留按钮 */
        .code-lang:empty::before { content: "plain text"; opacity: 0.5; }
        .copy-btn {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            font-size: 10px;
            color: var(--text-light);
            background: none;
            border: none;
            cursor: pointer;
            padding: 2px 6px;
            border-radius: 3px;
            transition: color 0.15s, background 0.15s;
            font-family: inherit;
            line-height: 1;
        }
        .copy-btn:hover { color: var(--text-main); background: rgba(0,0,0,0.06); }
        .copy-btn.copied { color: #38A169; }
        .copy-btn i { font-size: 12px; }
        /* pre 本身去掉 border/margin，交给 .code-block 管理 */
        .post-content pre {
            background-color: #FAF0D8;
            padding: 14px 15px;
            overflow-x: auto;
            margin-bottom: 0;
            font-size: 12px;
            border: none;
            border-radius: 0;
        }
        .post-content code { font-family: "Menlo", "Monaco", "Consolas", "Courier New", monospace; color: #333; }
        .post-content p code {
            background-color: #EDD5A8;
            padding: 2px 4px;
            border-radius: 3px;
            font-size: 0.9em;
            color: #B05010;
        }
        .post-content blockquote {
            margin: 1.5em 0;
            padding: 0.5em 1.5em;
            border-left: 4px solid var(--text-main);
            background-color: #FDF4E4;
            color: var(--text-light);
            font-style: italic;
        }
        .post-content figure { margin: 2em 0; text-align: center; }
        .post-content img { max-width: 100%; height: auto; border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); display: block; }
        .post-content figcaption { margin-top: 10px; font-size: 11px; color: var(--text-light); font-style: italic; }
        .post-content ul, .post-content ol { margin-bottom: 1.5em; padding-left: 1.5em; }
        .post-content li { margin-bottom: 0.5em; }
        .post-content table { width: 100%; border-collapse: collapse; margin-bottom: 1.5em; font-size: 12px; }
        .post-content th { background: #EDD5A8; padding: 8px 12px; text-align: left; border-bottom: 2px solid var(--line-color); }
        .post-content td { padding: 8px 12px; border-bottom: 1px solid var(--line-color); }
        .post-content hr { border: none; border-top: 1px solid var(--line-color); margin: 2em 0; }
        .post-footer {
            margin-top: 50px;
            padding-top: 30px;
            border-top: 2px solid var(--line-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-shrink: 0;
        }
        .tags { display: flex; gap: 8px; flex-wrap: wrap; }
        .tag { font-size: 11px; padding: 3px 8px; background-color: #EDD5A8; color: var(--text-main); border-radius: 20px; }
        @media (max-width: 700px) {
            body { display: block; }
            .content-board { width: 100%; padding: 30px 20px; border-radius: 0; box-shadow: none; min-height: 100vh; }
            .post-content pre { padding: 10px; font-size: 11px; }
        }
    </style>
</head>
<body>
    <main class="content-board">
        <a href="${back_url}" class="back-link">
            <i class="ri-arrow-left-line"></i> 返回文章列表
        </a>
        <header class="post-header">
            <div class="post-meta">
                <span>${date_str}</span>${category:+ &bull; <span>${category}</span>}
            </div>
            <h1 class="post-title">${title}</h1>
        </header>
        <article class="post-content">
${body_html}
        </article>
        <footer class="post-footer">
            <div class="tags">${tags_html}</div>
            <div style="font-size: 12px; color: var(--text-light);">
                $(date +%Y) &copy; $(basename "$OUT_DIR" | sed 's/dist//')
            </div>
        </footer>
    </main>

    <script>
    (function () {
        // ── 语言名称美化映射 ──────────────────────────────────────────────────
        var LANG_LABELS = {
            js: 'JavaScript', javascript: 'JavaScript',
            ts: 'TypeScript', typescript: 'TypeScript',
            py: 'Python',     python: 'Python',
            rb: 'Ruby',
            sh: 'Shell',      bash: 'Shell', zsh: 'Shell',
            css: 'CSS',       scss: 'SCSS',  less: 'Less',
            html: 'HTML',     xml: 'XML',
            json: 'JSON',     yaml: 'YAML',  yml: 'YAML',
            md: 'Markdown',   markdown: 'Markdown',
            sql: 'SQL',
            go: 'Go',
            rs: 'Rust',
            java: 'Java',
            kt: 'Kotlin',
            swift: 'Swift',
            cpp: 'C++',       'c++': 'C++',
            c: 'C',
            cs: 'C#',
            php: 'PHP',
            r: 'R',
            dockerfile: 'Dockerfile',
            toml: 'TOML',
            ini: 'INI',
            diff: 'Diff',
        };

        // ── 提取语言：pandoc 输出 <code class="language-xxx"> ────────────────
        function getLang(codeEl) {
            var cls = codeEl.className || '';
            var m = cls.match(/language-([^\s]+)/);
            if (!m) return '';
            var raw = m[1].toLowerCase();
            return LANG_LABELS[raw] || raw;
        }

        // ── 为每个代码块注入顶栏 ────────────────────────────────────────────
        document.querySelectorAll('.post-content pre').forEach(function (pre) {
            var code = pre.querySelector('code');
            if (!code) return;

            var lang = getLang(code);

            // 建立外层 wrapper
            var wrapper = document.createElement('div');
            wrapper.className = 'code-block';
            pre.parentNode.insertBefore(wrapper, pre);
            wrapper.appendChild(pre);

            // 建立顶栏
            var header = document.createElement('div');
            header.className = 'code-header';

            var langSpan = document.createElement('span');
            langSpan.className = 'code-lang';
            langSpan.textContent = lang;

            var copyBtn = document.createElement('button');
            copyBtn.className = 'copy-btn';
            copyBtn.innerHTML = '<i class="ri-clipboard-line"></i> 复制';
            copyBtn.setAttribute('aria-label', '复制代码');

            copyBtn.addEventListener('click', function () {
                var text = code.innerText;
                if (navigator.clipboard && window.isSecureContext) {
                    navigator.clipboard.writeText(text).then(onCopied);
                } else {
                    // 降级方案
                    var ta = document.createElement('textarea');
                    ta.value = text;
                    ta.style.cssText = 'position:fixed;opacity:0';
                    document.body.appendChild(ta);
                    ta.select();
                    try { document.execCommand('copy'); onCopied(); } catch(e) {}
                    document.body.removeChild(ta);
                }
            });

            function onCopied() {
                copyBtn.innerHTML = '<i class="ri-check-line"></i> 已复制';
                copyBtn.classList.add('copied');
                setTimeout(function () {
                    copyBtn.innerHTML = '<i class="ri-clipboard-line"></i> 复制';
                    copyBtn.classList.remove('copied');
                }, 2000);
            }

            header.appendChild(langSpan);
            header.appendChild(copyBtn);
            wrapper.insertBefore(header, pre);
        });
    })();
    </script>
</body>
</html>
HTML
}

# ─── 生成首页 index.html ──────────────────────────────────────────────────────
# 参数：关联数组已通过全局变量 INDEX_* 传递
generate_index() {
    local site_name="${SITE_NAME:-My Blog}"
    local site_desc="${SITE_DESC:-文章列表}"
    local out_file="${OUT_DIR}/index.html"

    # 构建文章列表 HTML（已按日期降序排好）
    local list_html=""
    local i
    for i in "${!IDX_TITLES[@]}"; do
        local title="${IDX_TITLES[$i]}"
        local date_s="${IDX_DATES[$i]}"
        local cat="${IDX_CATS[$i]}"
        local excerpt="${IDX_EXCERPTS[$i]}"
        local href="${IDX_HREFS[$i]}"

        local meta_html="<span>${date_s}</span>"
        [[ -n "$cat" ]] && meta_html+=" &bull; <span>${cat}</span>"

        list_html+="
        <a href=\"${href}\" class=\"post-item\">
            <div class=\"item-meta\">${meta_html}</div>
            <h2 class=\"item-title\">${title}</h2>
            <p class=\"item-excerpt\">${excerpt}…</p>
        </a>"
    done

    cat > "$out_file" <<HTML
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${site_name}</title>
    <link href="https://cdn.jsdelivr.net/npm/remixicon@3.5.0/fonts/remixicon.css" rel="stylesheet">
    <style>
        :root {
            --bg-color: #FCF7EE;
            --board-bg: #FFFFFF;
            --text-main: #180A00;
            --text-light: #AA7A42;
            --line-color: #E0C8A0;
            --accent-color: #B06820;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            -webkit-font-smoothing: antialiased;
            min-height: 100vh;
            display: flex;
            justify-content: center;
        }
        .content-board {
            width: 640px;
            background-color: var(--board-bg);
            display: flex;
            flex-direction: column;
            min-height: 100vh;
            padding: 50px 50px 60px;
            box-shadow: 0 0 20px rgba(0,0,0,0.05);
        }

        /* ── 站点头部 ── */
        .site-header {
            margin-bottom: 50px;
            padding-bottom: 28px;
            border-bottom: 2px solid var(--text-main);
            flex-shrink: 0;
        }
        .site-name {
            font-family: "Georgia", serif;
            font-size: 26px;
            font-weight: 700;
            color: var(--text-main);
            letter-spacing: -0.3px;
        }
        .site-desc {
            margin-top: 6px;
            font-size: 12px;
            color: var(--text-light);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        /* ── 文章列表 ── */
        .post-list {
            flex: 1;
            display: flex;
            flex-direction: column;
        }
        .post-item {
            display: block;
            padding: 24px 0;
            border-bottom: 1px solid var(--line-color);
            text-decoration: none;
            color: inherit;
            transition: none;
        }
        .post-item:first-child { padding-top: 4px; }
        .post-item:last-child  { border-bottom: none; }

        .item-meta {
            font-size: 11px;
            color: var(--text-light);
            text-transform: uppercase;
            letter-spacing: 0.6px;
            margin-bottom: 8px;
        }
        .item-title {
            font-family: "Georgia", serif;
            font-size: 17px;
            font-weight: 700;
            line-height: 1.35;
            color: var(--text-main);
            margin-bottom: 10px;
            transition: color 0.15s;
        }
        .post-item:hover .item-title {
            color: var(--accent-color);
        }
        .item-excerpt {
            font-size: 12.5px;
            line-height: 1.8;
            color: var(--text-light);
            /* 严格限制两行，超出用省略号 */
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }

        /* ── 空状态 ── */
        .empty-tip {
            padding: 60px 0;
            text-align: center;
            font-size: 13px;
            color: var(--text-light);
        }

        /* ── 底栏 ── */
        .site-footer {
            margin-top: 40px;
            padding-top: 24px;
            border-top: 1px solid var(--line-color);
            font-size: 11px;
            color: var(--text-light);
            display: flex;
            justify-content: space-between;
            flex-shrink: 0;
        }

        @media (max-width: 700px) {
            body { display: block; }
            .content-board { width: 100%; padding: 36px 22px 48px; box-shadow: none; }
            .site-name { font-size: 22px; }
            .item-title { font-size: 15px; }
        }
    </style>
</head>
<body>
    <main class="content-board">

        <header class="site-header">
            <div class="site-name">${site_name}</div>
            <div class="site-desc">${site_desc} &nbsp;&middot;&nbsp; ${#IDX_TITLES[@]} 篇文章</div>
        </header>

        <div class="post-list">
$(if [[ ${#IDX_TITLES[@]} -eq 0 ]]; then
    echo '            <div class="empty-tip">暂无文章</div>'
else
    echo "$list_html"
fi)
        </div>

        <footer class="site-footer">
            <span>$(date +%Y) ${site_name}</span>
            <span>Generated by md2html</span>
        </footer>

    </main>
</body>
</html>
HTML

    log_ok "$(printf '%-40s' "index.html") → ${out_file}  (${#IDX_TITLES[@]} 篇)"
}

# ─── dywsun 新版模板：覆盖旧模板函数 ─────────────────────────────────────────────
generate_html() {
    local title="$1"
    local date_str="$2"
    local category="$3"
    local tags_html="$4"
    local back_url="$5"
    local body_html="$6"
    local title_html date_html category_html

    title_html=$(printf '%s' "$title" | html_escape)
    date_html=$(printf '%s' "$date_str" | html_escape)
    category_html=$(printf '%s' "$category" | html_escape)

    cat <<HTML
<!doctype html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title_html} - ${SITE_NAME}</title>
    <meta name="description" content="${SITE_DESC}">
    <style>
$(shared_css)
    </style>
</head>
<body>
    <div class="site-shell">
        <header class="site-header">
            <a class="brand" href="index.html#home" aria-label="${SITE_NAME} 首页">${SITE_NAME}</a>
            <nav class="site-nav" aria-label="主导航">
                <a href="index.html#home">首页</a>
                <a href="index.html#categories">分类</a>
                <a href="index.html#archive">归档</a>
                <a href="index.html#search">搜索</a>
            </nav>
        </header>

        <main class="site-main">
            <article class="article-page">
                <a class="back-link" href="${back_url}#home">返回首页</a>
                <header class="article-header">
                    <div class="post-meta">
                        <span>${date_html}</span><span>${category_html}</span>
                    </div>
                    <h1 class="article-title">${title_html}</h1>
                </header>
                <div class="article-body">
${body_html}
                </div>
            </article>
        </main>
    </div>
</body>
</html>
HTML
}

generate_index() {
    local site_name="${SITE_NAME:-dywsun}"
    local site_desc="${SITE_DESC:-思绪来得快，去得也快，何不执笔留下。}"
    local out_file="${OUT_DIR}/index.html"
    local post_data=""
    local i

    for i in "${!IDX_TITLES[@]}"; do
        local title date_s cat excerpt href
        title=$(printf '%s' "${IDX_TITLES[$i]}" | js_escape)
        date_s=$(printf '%s' "${IDX_DATES[$i]}" | js_escape)
        cat=$(printf '%s' "${IDX_CATS[$i]}" | js_escape)
        excerpt=$(printf '%s' "${IDX_EXCERPTS[$i]}" | js_escape)
        href=$(printf '%s' "${IDX_HREFS[$i]}" | js_escape)
        post_data+="    { title: '${title}', date: '${date_s}', category: '${cat}', excerpt: '${excerpt}', href: '${href}' },
"
    done

    cat > "$out_file" <<HTML
<!doctype html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${site_name}</title>
    <meta name="description" content="${site_desc}">
    <style>
$(shared_css)
    </style>
</head>
<body>
    <div class="site-shell">
        <header class="site-header">
            <a class="brand" href="#home" aria-label="${site_name} 首页">${site_name}</a>
            <nav class="site-nav" aria-label="主导航">
                <a href="#home" data-route="home">首页</a>
                <a href="#categories" data-route="categories">分类</a>
                <a href="#archive" data-route="archive">归档</a>
                <a href="#search" data-route="search">搜索</a>
            </nav>
        </header>

        <main id="app" class="site-main" tabindex="-1"></main>
    </div>

    <script>
const posts = [
${post_data}];
const SITE_DESC = '${site_desc}';
HTML

    cat >> "$out_file" <<'HTML'
const PAGE_SIZE = 5;
const app = document.querySelector("#app");

function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, (char) => {
        const map = {
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            '"': "&quot;",
            "'": "&#039;",
        };
        return map[char];
    });
}

function dateParts(dateString) {
    const digits = String(dateString).replace(/\D/g, "");
    return {
        year: digits.slice(0, 4) || "0000",
        month: digits.slice(4, 6) || "01",
        day: digits.slice(6, 8) || "01",
    };
}

function formatDate(dateString) {
    const parts = dateParts(dateString);
    return `${Number(parts.year)}年${Number(parts.month)}月${Number(parts.day)}日`;
}

function formatArchiveMonth(dateString) {
    const parts = dateParts(dateString);
    return `${Number(parts.year)} 年 ${Number(parts.month)} 月`;
}

function formatArchiveDay(dateString) {
    const parts = dateParts(dateString);
    return `${parts.month}.${parts.day}`;
}

function setActiveNav(route) {
    document.querySelectorAll(".site-nav a").forEach((link) => {
        link.classList.toggle("is-active", link.dataset.route === route);
    });
}

function renderIntro() {
    return `
        <section class="intro">
            <h1>${escapeHtml(SITE_DESC)}</h1>
        </section>
    `;
}

function renderPostCard(post) {
    return `
        <a class="post-card" href="${post.href}">
            <div class="post-meta">
                <span>${formatDate(post.date)}</span>
                <span>${escapeHtml(post.category)}</span>
            </div>
            <h2 class="post-title">${escapeHtml(post.title)}</h2>
            <p class="post-excerpt">${escapeHtml(post.excerpt)}...</p>
        </a>
    `;
}

function renderLoadMore(visibleCount, totalCount) {
    if (visibleCount >= totalCount) return "";
    const remainingCount = totalCount - visibleCount;
    return `
        <div class="load-more-wrap">
            <button class="load-more-button" type="button" data-load-more>
                加载更多
                <span>剩余 ${remainingCount} 篇</span>
            </button>
        </div>
    `;
}

function renderPostList(list, visibleCount = PAGE_SIZE) {
    if (list.length === 0) {
        return `<div class="empty-state">没有找到相关文章。</div>`;
    }
    const safeVisibleCount = Math.min(Math.max(visibleCount, PAGE_SIZE), list.length);
    const visiblePosts = list.slice(0, safeVisibleCount);
    return `
        <section class="post-list">${visiblePosts.map(renderPostCard).join("")}</section>
        ${renderLoadMore(safeVisibleCount, list.length)}
    `;
}

function bindLoadMore(handler) {
    app.querySelectorAll("[data-load-more]").forEach((button) => {
        button.addEventListener("click", () => handler());
    });
}

function renderHome(visibleCount = PAGE_SIZE) {
    setActiveNav("home");
    app.innerHTML = renderIntro() + renderPostList(posts, visibleCount);
    bindLoadMore(() => renderHome(visibleCount + PAGE_SIZE));
}

function groupByCategory() {
    return posts.reduce((result, post) => {
        result[post.category] = result[post.category] || [];
        result[post.category].push(post);
        return result;
    }, {});
}

function renderCategories() {
    setActiveNav("categories");
    const grouped = groupByCategory();
    app.innerHTML = `
        <section class="intro">
            <h1 class="page-title">分类</h1>
            <p class="page-copy">按写作的来处，把文章分成不同的主题。</p>
        </section>
        <section class="category-list">
            <div class="category-grid">
                ${Object.entries(grouped)
                    .map(([category, list]) => `
                        <button class="category-card" type="button" data-category="${escapeHtml(category)}">
                            <h2>${escapeHtml(category)}</h2>
                            <p>${list.length} 篇文章</p>
                        </button>
                    `)
                    .join("")}
            </div>
        </section>
    `;
    app.querySelectorAll("[data-category]").forEach((button) => {
        button.addEventListener("click", () => {
            const category = button.dataset.category;
            renderCategoryPosts(category, grouped[category], PAGE_SIZE);
        });
    });
}

function renderCategoryPosts(category, list, visibleCount) {
    app.innerHTML = `
        <section class="intro">
            <h1 class="page-title">${escapeHtml(category)}</h1>
            <p class="page-copy">这一类下共有 ${list.length} 篇文章。</p>
            <button class="clear-button" type="button" id="backToCategories">返回分类</button>
        </section>
        ${renderPostList(list, visibleCount)}
    `;
    document.querySelector("#backToCategories").addEventListener("click", renderCategories);
    bindLoadMore(() => renderCategoryPosts(category, list, visibleCount + PAGE_SIZE));
    app.focus();
}

function renderArchive() {
    setActiveNav("archive");
    const grouped = posts.reduce((result, post) => {
        const key = formatArchiveMonth(post.date);
        result[key] = result[key] || [];
        result[key].push(post);
        return result;
    }, {});
    app.innerHTML = `
        <section class="intro">
            <h1 class="page-title">归档</h1>
            <p class="page-copy">按月份收起这些文章，一眼看见时间留下的纹理。</p>
        </section>
        <section class="archive-list">
            ${Object.entries(grouped)
                .map(([month, list]) => `
                    <section class="archive-group">
                        <h2>${escapeHtml(month)}</h2>
                        <div class="archive-items">
                            ${list
                                .map((post) => `
                                    <a class="archive-item" href="${post.href}">
                                        <time datetime="${escapeHtml(post.date)}">${formatArchiveDay(post.date)}</time>
                                        <span>${escapeHtml(post.title)}</span>
                                    </a>
                                `)
                                .join("")}
                        </div>
                    </section>
                `)
                .join("")}
        </section>
    `;
}

function renderSearch() {
    setActiveNav("search");
    app.innerHTML = `
        <section class="intro">
            <h1 class="page-title">搜索</h1>
            <p class="page-copy">输入关键词，在标题、分类、摘要和正文里寻找那些被留下的念头。</p>
        </section>
        <section class="search-panel">
            <label class="search-box">
                <input id="searchInput" type="search" placeholder="搜索文章..." autocomplete="off" />
            </label>
            <div id="searchResults"></div>
        </section>
    `;
    const input = document.querySelector("#searchInput");
    const results = document.querySelector("#searchResults");

    function updateSearchResults(visibleCount = PAGE_SIZE) {
        const keyword = input.value.trim().toLowerCase();
        const matched = posts.filter((post) => {
            const content = [post.title, post.category, post.excerpt].join(" ").toLowerCase();
            return content.includes(keyword);
        });
        results.innerHTML = renderPostList(keyword ? matched : posts, visibleCount);
        results.querySelectorAll("[data-load-more]").forEach((button) => {
            button.addEventListener("click", () => updateSearchResults(visibleCount + PAGE_SIZE));
        });
    }

    input.addEventListener("input", () => updateSearchResults(PAGE_SIZE));
    updateSearchResults(PAGE_SIZE);
    input.focus();
}

function route() {
    const hash = window.location.hash.replace(/^#/, "") || "home";
    if (hash === "categories") {
        renderCategories();
    } else if (hash === "archive") {
        renderArchive();
    } else if (hash === "search") {
        renderSearch();
    } else {
        renderHome();
    }
    window.scrollTo({ top: 0 });
}

window.addEventListener("hashchange", route);
route();
    </script>
</body>
</html>
HTML

    log_ok "$(printf '%-40s' "index.html") → ${out_file}  (${#IDX_TITLES[@]} 篇)"
}

# ─── 统计 & 首页数据收集数组 ─────────────────────────────────────────────────
total=0; success=0; skipped=0

# 站点名称/描述（在脚本顶部配置）
# SITE_NAME / SITE_DESC 已在脚本头部定义

# 用于首页排序的临时文件（存 "排序键\t索引" 行）
_SORT_TMP=$(mktemp)

# 各字段数组（用数字索引，保持插入顺序，排序后重排）
declare -a IDX_TITLES=()
declare -a IDX_DATES=()
declare -a IDX_CATS=()
declare -a IDX_EXCERPTS=()
declare -a IDX_HREFS=()

# ─── 遍历 MD 文件 ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  md2html — Markdown 批量转换为 HTML${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
log_info "源目录：$MD_DIR"
log_info "输出目录：$OUT_DIR"
echo ""

# find 支持递归子目录；如只需当前层加 -maxdepth 1
while IFS= read -r -d '' md_file; do
    total=$((total + 1))
    filename=$(basename "$md_file" .md)
    out_file="${OUT_DIR}/${filename}.html"

    # ── 读取 Frontmatter 字段 ──────────────────────────────────────────────
    fm_title=$(get_frontmatter_field "$md_file" "title")
    fm_date=$(get_frontmatter_field "$md_file" "date")
    fm_category=$(get_frontmatter_field "$md_file" "category")
    fm_tags=$(get_frontmatter_field "$md_file" "tags")
    fm_back=$(get_frontmatter_field "$md_file" "back_url")

    # ── 回退默认值 ────────────────────────────────────────────────────────
    md_title=$(get_markdown_title "$md_file")
    title="${fm_title:-${md_title:-$filename}}"
    date_str="${fm_date:-$(date +%Y.%m.%d)}"
    category="${fm_category:-技术博客}"
    back_url="${fm_back:-index.html}"

    # ── 将 tags 转为 HTML ─────────────────────────────────────────────────
    tags_html=$(render_tags "$fm_tags")

    # ── 提取摘要 ──────────────────────────────────────────────────────────
    excerpt=$(get_excerpt "$md_file")

    # ── 收集到首页数组 ────────────────────────────────────────────────────
    _idx=${#IDX_TITLES[@]}
    IDX_TITLES+=("$title")
    IDX_DATES+=("$date_str")
    IDX_CATS+=("$category")
    IDX_EXCERPTS+=("$excerpt")
    IDX_HREFS+=("${filename}.html")
    # 排序键：将日期中的分隔符去掉，凑成纯数字（倒序用负号前缀不易处理，后面 tac 倒序）
    _sort_key=$(echo "$date_str" | tr -dc '0-9')
    printf '%s\t%d\n' "${_sort_key:-00000000}" "$_idx" >> "$_SORT_TMP"

    # ── Pandoc 转换：Markdown 正文 → HTML ────────────────────────────────
    body_html=$(strip_article_body "$md_file" "$fm_title" | pandoc \
        --from markdown+smart+fenced_code_attributes \
        --to html5 \
        --no-highlight \
        2>/dev/null) || {
        log_warn "跳过（pandoc 转换失败）：$md_file"
        skipped=$((skipped + 1))
        continue
    }

    # ── 生成完整 HTML ──────────────────────────────────────────────────────
    generate_html "$title" "$date_str" "$category" "$tags_html" "$back_url" "$body_html" \
        > "$out_file"

    log_ok "$(printf '%-40s' "$filename.md") → ${out_file}"
    success=$((success + 1))

done < <(find "$MD_DIR" -maxdepth 1 -name "*.md" -print0 | sort -z)

# ─── 按日期降序重排首页数据数组 ──────────────────────────────────────────────
declare -a S_TITLES=() S_DATES=() S_CATS=() S_EXCERPTS=() S_HREFS=()
while IFS=$'\t' read -r _key _i; do
    S_TITLES+=("${IDX_TITLES[$_i]}")
    S_DATES+=("${IDX_DATES[$_i]}")
    S_CATS+=("${IDX_CATS[$_i]}")
    S_EXCERPTS+=("${IDX_EXCERPTS[$_i]}")
    S_HREFS+=("${IDX_HREFS[$_i]}")
done < <(sort -rn "$_SORT_TMP")
rm -f "$_SORT_TMP"

# 用排好序的数组替换
IDX_TITLES=("${S_TITLES[@]+"${S_TITLES[@]}"}")
IDX_DATES=("${S_DATES[@]+"${S_DATES[@]}"}")
IDX_CATS=("${S_CATS[@]+"${S_CATS[@]}"}")
IDX_EXCERPTS=("${S_EXCERPTS[@]+"${S_EXCERPTS[@]}"}")
IDX_HREFS=("${S_HREFS[@]+"${S_HREFS[@]}"}")

# ─── 生成首页 ─────────────────────────────────────────────────────────────────
generate_index

# ─── 汇总 ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  总计：${total} 个文件  ✓ 成功：${GREEN}${success}${RESET}  ✗ 跳过：${YELLOW}${skipped}${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
