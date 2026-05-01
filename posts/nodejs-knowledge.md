# 从零上手 Node.js：踩坑实录与知识整理

## 概览

本文记录从零搭建 Node.js + TypeScript 项目过程中遇到的问题和学到的知识，分为四个部分：

- **一、包管理基础** — npm、npx 是什么，怎么装包
- **二、项目文件解析** — package.json、package-lock.json、node_modules 各是干什么的
- **三、TypeScript 配置** — package.json 和 tsconfig.json 配置项详解、常见报错怎么解决、Cocos Creator 推荐配置
- **四、快速参考** — 常用命令速查表

---

# 一、包管理基础

## npm 是什么

npm（Node Package Manager）是 Node.js 的**包管理器**，负责安装、卸载、发布第三方代码包。

---

## npx 是什么，跟 npm 有什么区别

`npx` 是 npm 自带的**命令执行工具**，从 npm 5.2 开始内置，不需要单独安装。

| | `npm` | `npx` |
|---|---|---|
| 作用 | 管理包（安装/卸载/发布） | 执行包里的命令 |
| 典型用法 | `npm install xxx` | `npx xxx` |
| 需要先安装吗 | 是 | **不需要** |

npx 的执行逻辑：检查本地有没有这个包 → 没有就临时下载到缓存 → 执行完就丢掉，不污染全局环境。

```bash
# ① 执行一次性工具（最常见）
npx tsx src/index.ts
npx create-react-app my-app

# ② 执行本地项目里的包（等价于 ./node_modules/.bin/tsc）
npx tsc --init

# ③ 指定版本运行
npx node@18 index.js
```

> **一句话总结：** `npm` 是包管理器，负责装包；`npx` 是包执行器，负责跑命令——用 npx 可以不装包直接跑。

---

## npm install 的两种依赖

`-D` 是 `--save-dev` 的缩写，表示安装为**开发依赖**。

| 类型 | 命令 | 例子 | 原因 |
|------|------|------|------|
| 生产依赖 | `npm install xxx` | `express`、`zod` | 程序运行时需要 |
| 开发依赖 | `npm install -D xxx` | `typescript`、`tsx`、`eslint` | 只在开发阶段用，上线后不需要 |

两者写入 `package.json` 的位置不同：

```json
{
  "dependencies": {
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "tsx": "^4.0.0"
  }
}
```

部署服务器时可以只装生产依赖，更轻量：

```bash
npm install --production
```

---

## 常用开发依赖解析

TypeScript 项目通常需要这三个开发依赖：

```bash
npm install -D typescript @types/node tsx
```

**`typescript`** — TypeScript 编译器，把 `.ts` 转成 `.js`，Node.js 才能运行。

**`@types/node`** — Node.js 的类型定义。TypeScript 需要知道每个函数的类型才能做检查，但 Node.js 本身是 JavaScript 写的没有类型信息，`@types/node` 负责补充这些描述。没有它，`import fs from "fs"` 会报错。

**`tsx`** — 开发时直接运行 `.ts` 文件，跳过编译步骤（底层基于 esbuild，速度快）。注意 tsx 不做类型检查，只管运行，上线前要单独用 `tsc --noEmit` 做类型检查。

```
写代码阶段    →  typescript + @types/node  提供类型检查和代码提示
开发运行阶段  →  tsx                        直接运行 .ts 文件
上线部署阶段  →  三个都不需要               只跑编译好的 .js
```

---

# 二、项目文件解析

## 项目初始化：先有 package.json

在空目录里直接执行 `npm install`，什么都不会发生。原因是没有 `package.json`，npm 不认为这是一个项目。

必须先初始化：

```bash
npm init -y   # -y 表示所有选项用默认值，不用一路回车确认
```

正确的完整流程：

```bash
mkdir my-project && cd my-project
npm init -y                                # ① 先初始化
npm install zod                            # ② 装生产依赖
npm install -D typescript @types/node tsx  # ③ 装开发依赖
```

---

## 项目文件结构说明

```
my-project/
├── node_modules/       ← 所有包都装在这里
│   ├── typescript/
│   ├── tsx/
│   └── @types/node/
├── package.json        ← 记录装了哪些包，分 dependencies / devDependencies
├── package-lock.json   ← 锁定精确版本，保证多人环境一致
├── .gitignore          ← 排除 node_modules 不上传 git
└── src/
    └── index.ts
```

所有包（无论是否加 `-D`）都装在 `node_modules/` 里，`-D` 只影响 `package.json` 里的分类，不影响存放位置。

---

## package.json vs package-lock.json

`package.json` 里的版本号通常带 `^`，表示允许更新的小版本：

```json
{ "typescript": "^5.0.0" }  // 5.0.0 或更新的版本都行
```

这导致不同时间、不同机器装出来的版本可能不一样，出现"我这里能跑，你那里报错"的问题。

`package-lock.json` 锁定精确版本解决这个问题：

```json
{
  "typescript": {
    "version": "5.0.0",   // 精确版本，不是范围
    "resolved": "https://registry.npmjs.org/typescript/-/typescript-5.0.0.tgz"
  }
}
```

只要 `package-lock.json` 存在，`npm install` 就严格按照它装，不会装到更新版本。

| 文件 | 作用 | 上传 git |
|------|------|---------|
| `package.json` | 记录要装哪些包 | ✅ 要 |
| `package-lock.json` | 锁定精确版本 | ✅ 要 |
| `node_modules/` | 包的实际文件 | ❌ 不要，加入 .gitignore |

---

# 三、TypeScript 配置

## tsconfig.json 是什么，怎么生成

TypeScript 项目的配置文件，告诉 `tsc` 如何编译代码。用以下命令生成：

```bash
npx tsc --init
```

会在当前目录创建一个带注释说明的 `tsconfig.json`。

---

## package.json 配置项详解

```json
{
  "name": "my-project",
  "version": "1.0.0",
  "description": "这是一个示例项目",
  "main": "dist/index.js",
  "type": "module",
  "scripts": {
    "dev": "tsx src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "dependencies": { "zod": "^3.22.0" },
  "devDependencies": { "typescript": "^5.0.0" },
  "keywords": ["mcp", "tool"],
  "author": "你的名字",
  "license": "ISC"
}
```

**`name`** — 项目名称，发布到 npm 时就是包名。

**`version`** — 版本号，格式是 `主版本.次版本.补丁版本`：

```
1.0.0
│ │ └── 修了个 bug
│ └──── 加了新功能，向下兼容
└────── 破坏性更新，不向下兼容
```

**`type`** — 告诉 Node.js 用哪种模块系统：

```json
"type": "module"    // 用 import/export（现代写法，推荐）
"type": "commonjs"  // 用 require()（旧写法，默认值）
```

**`main`** — 别人 `import` 你这个包时的入口文件，本地项目用不上，发布 npm 包时才重要。

**`scripts`** — 自定义快捷命令，用 `npm run xxx` 执行。脚本里可以直接写 `tsx`、`tsc`，不用加 `npx`，npm 会自动去 `node_modules/.bin/` 里找。

**版本号前缀的含义：**

| 写法 | 含义 |
|------|------|
| `"^5.0.0"` | 允许更新次版本和补丁（5.x.x） |
| `"~5.0.0"` | 只允许更新补丁（5.0.x） |
| `"5.0.0"` | 锁死精确版本 |
| `"*"` | 任意版本 |

---

## tsconfig.json 配置项详解

### 模块相关（最重要，最容易出错）

**`module`** — 输出的模块格式：

```json
"module": "nodenext"  // 现代 Node.js 项目推荐
"module": "commonjs"  // 输出 require() 写法
"module": "esnext"    // 输出 import 写法，给打包工具用
```

**`moduleResolution`** — TypeScript 查找模块文件的策略：

| 值 | 适用场景 |
|----|---------|
| `node`（旧） | 老项目，CommonJS `require()` |
| `Node16` | ES Module，import 路径必须带 `.js` 扩展名 |
| `bundler` | ES Module，import 路径不用带扩展名，**推荐** |

**`baseUrl` 和 `paths`** — 路径别名，避免写很深的相对路径：

```json
{
  "baseUrl": "./src",
  "paths": {
    "@utils/*": ["utils/*"]
  }
}
```

```typescript
import { helper } from "@utils/helper"  // 不用写 ../../utils/helper
```

---

### 编译输出相关

**`target`** — 编译后输出的 JavaScript 版本：

```json
"target": "esnext"  // 最新，不做降级转换
"target": "ES2022"  // 转成 ES2022 语法
"target": "ES5"     // 转成老式语法，兼容旧浏览器
```

**`outDir`** — 编译后的 `.js` 文件输出目录：

```json
"outDir": "./dist"
```

**`rootDir`** — 源码 `.ts` 文件的根目录：

```json
"rootDir": "./src"
```

**`sourceMap`** — 生成 `.map` 文件，让报错能定位到 `.ts` 源码的行号：

```json
"sourceMap": true
```

**`declaration`** — 生成 `.d.ts` 类型声明文件，发布 npm 包时需要，本地开发不需要：

```json
"declaration": true
```

---

### 类型相关

**`strict`** — 一个开关，同时启用多项严格检查，强烈建议开启：

```json
"strict": true
```

**`types`** — 指定加载哪些 `@types/xxx` 包，不写就全部加载：

```json
"types": ["node"]          // 只加载 @types/node
"types": ["node", "jest"]  // 加载多个
```

**`lib`** — 内置类型的白名单，控制能用哪些 JS 内置特性：

```json
"lib": ["ES2022"]          // Node.js 项目
"lib": ["ES2022", "DOM"]   // 浏览器项目，能用 window、document
```

**`verbatimModuleSyntax`** — 强制 import 类型时必须加 `type` 关键字：

```typescript
import type { User } from "./types"  // ✅
import { User } from "./types"       // ❌ 报错，User 只是类型
```

**`skipLibCheck`** — 跳过 `node_modules` 里 `.d.ts` 的类型检查，大幅加快编译速度，几乎所有项目都会开：

```json
"skipLibCheck": true
```

---

### 编译范围：include 和 exclude

这两个字段写在 `compilerOptions` **外面**，控制编译哪些文件：

```json
{
  "compilerOptions": { ... },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**`include`** — 白名单，只编译这些路径下的文件。`src/**/*` 表示 src 目录下所有子目录里的所有文件。TypeScript 只处理 `.ts`、`.tsx`、`.d.ts`，其他格式自动忽略。

**`exclude`** — 黑名单，这些路径不扫描。`exclude` 优先级高于 `include`，同时匹配时以 `exclude` 为准。

不写 `include` 默认扫描项目里所有 `.ts` 文件（包括 `node_modules`，会很慢）。不写 `exclude` 默认只排除 `node_modules`。**两个都建议明确写上**。

---

## 常见报错及解决

### 报错一：Cannot find name 'fs'

```
Cannot find name 'fs'. Do you need to install type definitions for node?
Try `npm i --save-dev @types/node` and then add 'node' to the types field in your tsconfig.
```

**原因：** TypeScript 不认识 Node.js 内置模块的类型。

**解决：** 在 `tsconfig.json` 的 `compilerOptions` 里加：

```json
{ "types": ["node"] }
```

---

### 报错二：ECMAScript imports cannot be written in a CommonJS file

```
ECMAScript imports and exports cannot be written in a CommonJS file under 'verbatimModuleSyntax'.
Adjust the 'type' field in the nearest 'package.json' to make this file an ECMAScript module.
```

**原因：** 代码用了 `import/export`（ES Module），但项目被识别为 CommonJS，两者冲突。

**解决：** 在 `package.json` 加：

```json
{ "type": "module" }
```

**常见额外错误：** 把 `"type": "module"` 误写进了 `tsconfig.json`。`type` 是 `package.json` 的字段，在 `tsconfig.json` 里写了不会生效，要删掉。

---

## 推荐的完整配置

**`package.json`：**

```json
{
  "type": "module",
  "devDependencies": {
    "typescript": "^5.0.0",
    "tsx": "^4.0.0",
    "@types/node": "^20.0.0"
  }
}
```

**`tsconfig.json`：**

```json
{
  "compilerOptions": {
    "module": "nodenext",
    "moduleResolution": "bundler",
    "target": "esnext",
    "outDir": "./dist",
    "rootDir": "./src",
    "types": ["node"],
    "strict": true,
    "sourceMap": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

---

## Cocos Creator 项目推荐配置

Cocos 项目的 `library/` 和 `temp/` 是自动生成的缓存目录，文件数量极多，不排除会导致 tsserver 扫描时很慢。

```json
{
  "compilerOptions": {
    "target": "ES2015",
    "module": "commonjs",
    "strict": false,
    "experimentalDecorators": true,
    "skipLibCheck": true
  },
  "include": ["assets/**/*"],
  "exclude": ["node_modules", "library", "temp", "local", "profiles", "build"]
}
```

`strict: false` — Cocos 内置 API 有些写法在严格模式下会报错，关掉省心。

`experimentalDecorators: true` — Cocos 组件用 `@ccclass` 这类装饰器必须开启。

`skipLibCheck: true` — 跳过 `node_modules` 里 `.d.ts` 的检查，加快速度。

---

# 四、快速参考

## 常用命令

| 命令 | 说明 |
|------|------|
| `npm init -y` | 初始化项目，生成 package.json |
| `npm install` | 安装 package.json 里所有依赖 |
| `npm install xxx` | 安装生产依赖 |
| `npm install -D xxx` | 安装开发依赖 |
| `npm install --production` | 只装生产依赖（部署用） |
| `rm -rf node_modules` | 删除所有已安装的包 |
| `npx xxx` | 不安装直接执行某个包的命令 |
| `npx tsx src/index.ts` | 直接运行 TypeScript 文件 |
| `npx tsx watch src/index.ts` | 运行并监听文件变化自动重启 |
| `npx tsc --init` | 生成 tsconfig.json |
| `npx tsc --noEmit` | 只做类型检查，不输出编译文件 |

## .gitignore 最小配置

```
node_modules/
dist/
```
