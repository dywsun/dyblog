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
SITE_NAME="My Blog"
SITE_DESC="Writing &amp; Thinking"
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
    title="${fm_title:-$filename}"
    date_str="${fm_date:-$(date +%Y.%m.%d)}"
    category="${fm_category:-}"
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
    body_html=$(strip_frontmatter "$md_file" | pandoc \
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
