# Blog

用 Markdown 写作，自动发布为静态博客。

## 写新文章

在 `posts/` 目录下新建 `.md` 文件，支持以下 frontmatter：

```yaml
---
title: 文章标题
date: 2024.06.01
category: 分类名称
tags: Tag1, Tag2
---

正文从这里开始...
```

提交推送到 `main` 分支后，GitHub Actions 自动构建并发布。

## 本地预览

```bash
./md2html.sh ./posts ./dist
open dist/index.html
```

## 修改博客名称

编辑 `md2html.sh` 顶部的配置区：

```bash
SITE_NAME="My Blog"
SITE_DESC="Writing &amp; Thinking"
```
