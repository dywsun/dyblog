# uv 使用指南

> uv 是用 Rust 编写的 Python 包管理工具，速度极快，集成了 Python 版本管理、虚拟环境、包管理等功能，可替代 pyenv + pip + venv。

---

## 安装

### Linux / macOS

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

安装完成后重启终端，或执行：

```bash
source ~/.bashrc  # bash
source ~/.zshrc   # zsh
```

### Windows 10

**方式一：PowerShell（推荐）**

以管理员身份打开 PowerShell，执行：

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

**方式二：winget**

```powershell
winget install --id=astral-sh.uv -e
```

**方式三：pip 安装**

```powershell
pip install uv
```

安装完成后重启终端，验证安装：

```powershell
uv --version
```

> Windows 上 `uv run` 激活虚拟环境的命令略有不同：
> ```powershell
> .venv\Scripts\activate
> ```

---

## Python 版本管理

```bash
# 查看所有可用版本
uv python list

# 安装指定版本
uv python install 3.12

# 同时安装多个版本
uv python install 3.11 3.12 3.13

# 固定当前项目使用的 Python 版本（写入 .python-version）
uv python pin 3.12
```

---

## 项目管理

### 初始化项目

```bash
uv init myproject
cd myproject
```

会自动生成：

```
myproject/
├── .venv/
├── pyproject.toml
├── .python-version
└── main.py
```

### 依赖管理

```bash
# 添加依赖（自动写入 pyproject.toml）
uv add requests

# 添加多个依赖
uv add fastapi numpy pandas

# 添加开发依赖
uv add pytest --dev

# 移除依赖
uv remove requests

# 同步依赖（类似 npm install，按 pyproject.toml 安装所有包）
uv sync
```

### 运行脚本

```bash
# 直接运行（无需手动激活虚拟环境）
uv run main.py

# 运行命令
uv run pytest
uv run python -c "import sys; print(sys.version)"
```

---

## 虚拟环境

```bash
# 创建虚拟环境（默认生成 .venv/）
uv venv

# 指定 Python 版本
uv venv --python 3.11

# 手动激活（也可以直接用 uv run 跳过这步）
source .venv/bin/activate

# 退出虚拟环境
deactivate
```

---

## pip 兼容模式

兼容原有 pip 工作流，适合迁移老项目：

```bash
uv pip install requests
uv pip install -r requirements.txt
uv pip uninstall requests
uv pip list
uv pip freeze
```

---

## 典型工作流

### 新项目

```bash
uv init myapp
cd myapp
uv add fastapi uvicorn
uv run main.py
```

### 接手老项目

```bash
git clone https://github.com/xxx/project
cd project
uv sync               # 一键安装所有依赖
uv run main.py
```

### 替代 pip + venv 的传统流程

```bash
# 以前
python3 -m venv .venv
source .venv/bin/activate
pip install requests

# 现在
uv venv
uv pip install requests
# 或更推荐
uv add requests
```

---

## 常用命令速查

| 命令 | 说明 |
|------|------|
| `uv init <name>` | 初始化新项目 |
| `uv add <包名>` | 添加依赖 |
| `uv remove <包名>` | 移除依赖 |
| `uv sync` | 同步安装所有依赖 |
| `uv run <脚本>` | 运行脚本 |
| `uv venv` | 创建虚拟环境 |
| `uv pip install <包名>` | pip 兼容模式安装 |
| `uv python install <版本>` | 安装 Python 版本 |
| `uv python list` | 查看可用 Python 版本 |
| `uv python pin <版本>` | 固定项目 Python 版本 |

---

## 与其他工具对比

| 功能 | uv | pip + venv | conda | poetry |
|------|----|-----------|-------|--------|
| 速度 | ⚡ 极快 | 慢 | 慢 | 中 |
| Python 版本管理 | ✅ | ❌ | ✅ | ❌ |
| 虚拟环境 | ✅ | ✅ | ✅ | ✅ |
| 依赖锁定 | ✅ | ❌ | ✅ | ✅ |
| pip 兼容 | ✅ | ✅ | 部分 | 部分 |
| 非 Python 依赖 | ❌ | ❌ | ✅ | ❌ |

---

## 参考链接

- 官方文档：https://docs.astral.sh/uv/
- GitHub：https://github.com/astral-sh/uv
