# Cocos Tween 渐隐/渐显笔记

## 背景

在 Cocos Creator 中，如果想让 UI 节点做渐隐或渐显，常见方式是使用 `UIOpacity`。

但 `UIOpacity` 作用于整棵节点树，虽然使用方便，但可能会影响合批，从而增加 DrawCall。

如果只想控制某个渲染组件的透明度，可以直接修改组件 `color.a`，这种方式通常不会额外增加 DrawCall。

## 基本原则

节点本身没有真正的颜色透明度。

真正能显示颜色和透明度的是渲染组件，例如：

- `Sprite`
- `Label`
- 其他带 `color` 属性的渲染组件

所以如果节点本身没有 `Sprite` 或 `Label`，就不能直接改节点透明度，只能改它下面实际渲染组件的 `color.a`，或者使用 `UIOpacity`。

## Sprite 渐隐

```ts
import { Sprite, tween } from 'cc';

const sprite = this.node.getComponent(Sprite);
const color = sprite.color.clone();

tween(color)
    .to(0.3, { a: 0 }, {
        easing: 'quadOut',
        onUpdate: () => {
            sprite.color = color;
        },
    })
    .start();
```

## Sprite 渐显

```ts
import { Sprite, tween } from 'cc';

const sprite = this.node.getComponent(Sprite);
const color = sprite.color.clone();

color.a = 0;
sprite.color = color;

tween(color)
    .to(0.3, { a: 255 }, {
        easing: 'quadOut',
        onUpdate: () => {
            sprite.color = color;
        },
    })
    .start();
```

## Label 渐隐/渐显

`Label` 的用法和 `Sprite` 基本一致。

```ts
import { Label, tween } from 'cc';

const label = this.node.getComponent(Label);
const color = label.color.clone();

tween(color)
    .to(0.3, { a: 0 }, {
        easing: 'quadOut',
        onUpdate: () => {
            label.color = color;
        },
    })
    .start();
```

## 节点没有 Sprite 时怎么办

如果节点本身没有 `Sprite`，但子节点里有多个 `Sprite` 或 `Label`，可以遍历子节点里的渲染组件，统一修改它们的 `color.a`。

```ts
import { Label, Node, Sprite, tween } from 'cc';

function fadeRenderers(root: Node, toAlpha: number, duration = 0.3) {
    const renderers = [
        ...root.getComponentsInChildren(Sprite),
        ...root.getComponentsInChildren(Label),
    ];

    renderers.forEach(renderer => {
        const color = renderer.color.clone();

        tween(color)
            .to(duration, { a: toAlpha }, {
                easing: 'quadOut',
                onUpdate: () => {
                    renderer.color = color;
                },
            })
            .start();
    });
}
```

使用示例：

```ts
// 渐隐
fadeRenderers(this.node, 0, 0.3);

// 渐显
fadeRenderers(this.node, 255, 0.3);
```

## 泡泡爆炸渐隐推荐缓动

泡泡爆炸通常适合“前面快、后面慢”的缓动，让爆炸一开始比较有冲击力，后面柔和消失。

推荐透明度使用：

```ts
easing: 'quadOut'
```

或者更明显一点：

```ts
easing: 'cubicOut'
```

如果同时配合缩放，效果会更像爆开：

```ts
import { tween, v3 } from 'cc';

tween(node)
    .to(0.25, { scale: v3(1.25, 1.25, 1) }, { easing: 'quadOut' })
    .start();
```

透明度和缩放可以同时做：

```ts
const color = sprite.color.clone();

tween(color)
    .to(0.25, { a: 0 }, {
        easing: 'quadOut',
        onUpdate: () => {
            sprite.color = color;
        },
    })
    .start();

tween(node)
    .to(0.25, { scale: v3(1.25, 1.25, 1) }, {
        easing: 'quadOut',
    })
    .start();
```

## 缓动选择建议

- `quadOut`：最稳，适合大多数渐隐、爆炸消散。
- `cubicOut`：前段更快，爆炸感更强。
- `sineOut`：更柔和，适合轻微消散。
- `backOut`：带弹出感，适合 Q 弹风格的泡泡缩放，但不太适合直接用于透明度。

## 注意事项

- `color.a` 的范围是 `0-255`，不是 `0-1`。
- 修改 `color.a` 只影响当前渲染组件，不会自动影响整棵节点树。
- 如果需要整棵节点统一透明，`UIOpacity` 更方便，但可能影响 DrawCall。
- 使用 `sprite.color.clone()`，不要直接长期复用组件原始 color 引用，避免状态混乱。
