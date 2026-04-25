# 【Cocos Creator 踩坑记录】TypeScript 字符串 length 异常 & split 出现空字符串

> 环境：Cocos Creator 3.6.3 / TypeScript

---

## 🐛 问题描述

在开发小游戏过程中，需要对技能名称字符串做**逐字显示动画**（打字机效果），将字符串按字符拆分后逐个渲染到 Label 上。

```typescript
const str = "防抖技术"

console.log(str.length)    // 预期 4，实际输出 5 ❌
console.log(str.split('')) // 预期 ['防','抖','技','术']
                           // 实际输出 ['','防','抖','技','术'] ❌
```

第一个元素是一个**看不见的空字符串**，导致打字机动画第一帧显示空内容，逻辑出现偏差。

---

## 🔍 原因分析

### 原因一：隐藏的零宽字符（本案例的直接原因）

字符串头部混入了**不可见的 Unicode 字符**，它有编码、占 `length`，但没有任何显示图形。

| 字符 | Unicode | 名称 | 常见来源 |
|---|---|---|---|
| ﻿ | `U+FEFF` | BOM / 零宽不换行空格 | 从编辑器或网页**复制粘贴**文本时引入 |
| ​ | `U+200B` | 零宽空格 | 网页、富文本编辑器 |
| ‌ | `U+200C` | 零宽不连字 | 某些语言排版系统 |

```typescript
// 实际内存中的字符串是这样的：
const str = "\uFEFF防抖技术"

console.log(str.length)     // 5，\uFEFF 占一个 UTF-16 码元
console.log(str.split(''))  // ['\uFEFF', '防', '抖', '技', '术']
//                                ↑ 渲染为空，但实际存在
```

**定位方法：** 逐字打印码点，揪出隐藏字符：

```typescript
for (const char of str) {
    console.log(JSON.stringify(char), char.codePointAt(0)?.toString(16))
}
// 输出：
// ""   feff   ← 就是它！
// "防" 9632
// "抖" 6296
// "技" 6280
// "术" 672f
```

---

### 原因二：代理对问题（扩展知识，同类型隐患）

JS / TS 字符串底层是 **UTF-16 编码**，BMP 范围之外的字符（码点 > `U+FFFF`，如大多数 emoji、部分生僻汉字）需要**两个码元（代理对）** 表示。`length` 和 `split('')` 只认码元，不认完整字符。

```typescript
const emoji = "😂"
console.log(emoji.length)    // 2，不是 1！
console.log(emoji.split('')) // ['\uD83D', '\uDE02'] 乱码！
```

游戏中若技能名、角色名含有 emoji 或生僻字，同样会出现拆分错乱的问题。

---

## ✅ 解决方案

### 方案一：清除零宽不可见字符

```typescript
// 过滤掉常见零宽字符
const cleanStr = (str: string): string => {
    return str.replace(/[\u200B\uFEFF\u200C\u200D]/g, '')
}

const str = cleanStr("防抖技术") // 安全，length 正确为 4
```

### 方案二：用扩展运算符替代 split('')（同时解决代理对问题）

```typescript
// ❌ 不推荐：只认 UTF-16 码元
const chars1 = str.split('')

// ✅ 推荐：按 Unicode 码点正确拆分，兼容 emoji 和生僻字
const chars2 = [...str]
// 或
const chars3 = Array.from(str)
```

### 方案三：打字机动画完整安全写法

```typescript
import { _decorator, Component, Label } from 'cc'
const { ccclass, property } = _decorator

@ccclass('TypewriterLabel')
export class TypewriterLabel extends Component {

    @property(Label)
    label: Label = null!

    private _chars: string[] = []
    private _index: number = 0

    showText(raw: string) {
        // 1. 清除零宽字符
        const clean = raw.replace(/[\u200B\uFEFF\u200C\u200D]/g, '')
        // 2. 用扩展运算符正确拆分（兼容 emoji）
        this._chars = [...clean]
        this._index = 0
        this.label.string = ''
        this.schedule(this._tick, 0.08)
    }

    private _tick() {
        if (this._index >= this._chars.length) {
            this.unschedule(this._tick)
            return
        }
        this.label.string += this._chars[this._index]
        this._index++
    }
}
```

---

## 📌 总结

| 现象 | 原因 | 解决方式 |
|---|---|---|
| `length` 比预期多，`split` 出现 `''` | 字符串含隐藏零宽字符（`\uFEFF` 等） | `replace` 过滤零宽字符 |
| `length` 是字符数的两倍，`split` 出现乱码 | emoji / 生僻字占两个 UTF-16 码元（代理对） | 用 `[...str]` 替代 `split('')` |

> 💡 **最佳实践**：在 Cocos 项目中，所有来自配置表、网络接口、富文本粘贴的字符串，在进入渲染/逻辑处理前，统一做一次 `cleanStr` 预处理，防患于未然。
