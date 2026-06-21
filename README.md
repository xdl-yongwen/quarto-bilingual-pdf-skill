<div align="center">
  <h1>Quarto Bilingual Formatter</h1>
  <p>面向 RPP / 技术文档的 Quarto 双语排版、样式统一与 PDF 导出 Skill</p>

  <img alt="platform" src="https://img.shields.io/badge/platform-Windows%20PowerShell-0078D4">
  <img alt="quarto" src="https://img.shields.io/badge/Quarto-Typst%20PDF-39729E">
  <img alt="workflow" src="https://img.shields.io/badge/output-CN%20%2B%20EN%20%2B%20PDF-2EA44F">
  <img alt="codex" src="https://img.shields.io/badge/Codex-supported-111827">
  <img alt="render-only" src="https://img.shields.io/badge/RenderOnly-supported-8A2BE2">
</div>

---

## 它解决什么问题

你已经有一个 Quarto Markdown (`.qmd`) 技术文档，但每次交付前还需要手动处理这些事情：

- 整理中文 / 英文两个版本。
- 统一 callout、代码块、目录、标题和 PDF 样式。
- 保留原有 GPU / XDL 文档风格。
- 手动执行 Quarto 命令导出 PDF。
- 在新电脑上重新配置 VS Code、Codex、Quarto、Python 等依赖。

这套 skill 把这些步骤收进一个可复用工具包里：给它一个源 QMD，它可以生成双语 QMD，并导出对应 PDF；也可以跳过 Codex，只渲染你已经手动调整好的 QMD。

---

## 它会交付什么

| 能力 | 输出 |
| --- | --- |
| 双语生成 | `<name>-zh-cn.qmd`、`<name>-en.qmd` |
| PDF 导出 | 中文 PDF、英文 PDF，或原始 QMD PDF |
| 统一样式 | Typst PDF 样式、terminal 风格代码块、callout 配色 |
| 手动模式 | `-RenderOnly` 直接导出已有 QMD，不调用 Codex |
| 新机说明 | `references/host-setup-zh.md` 提供安装与模板说明 |

---

## 五个常用动作

| 场景 | 命令参数 |
| --- | --- |
| 从原始 QMD 生成 CN / EN 并导出 PDF | `-SourceQmd ".\your-file.qmd"` |
| 只导出原始 QMD PDF | `-SourceQmd ".\your-file.qmd" -RenderOnly` |
| 导出手动改好的 CN / EN QMD | `-ChineseQmd ".\your-file-zh-cn.qmd" -EnglishQmd ".\your-file-en.qmd" -RenderOnly` |
| 不想自动生成，缺少 CN / EN 时回退原始 QMD | `-SourceQmd ".\your-file.qmd" -SkipGenerateQmd` |
| 使用 Quarto preview 模式 | `-Mode preview` |

---

## 快速开始

在 QMD 文件所在目录运行。

下面命令里的脚本路径是示例路径。使用者需要把：

```text
C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1
```

改成自己电脑上 `skill\scripts\Export-QuartoBilingualPdf.ps1` 的实际绝对路径。例如，如果同事把 `skill` 放在 `D:\quarto\gpu\skill`，就改成：

```text
D:\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1
```

自动生成双语 QMD 并导出 PDF：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -SourceQmd ".\your-file.qmd"
```

### 只导出原始 QMD

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -SourceQmd ".\your-file.qmd" -RenderOnly
```

### 导出手动调整好的双语 QMD

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -ChineseQmd ".\your-file-zh-cn.qmd" -EnglishQmd ".\your-file-en.qmd" -RenderOnly
```

---

## 进度条说明

调用 Codex 生成双语 QMD 时，脚本会显示两个彼此独立的进度阶段。

```text
Generate QMD [########################] 100% done elapsed 00:04:05
Codex exit  [######------------------] 25% files ready elapsed 00:01:00
```

| 阶段 | 含义 |
| --- | --- |
| `Generate QMD` | QMD 内容生成阶段。只有目标 QMD 文件出现后才显示 100%。 |
| `Codex exit` | Codex CLI 退出守护阶段。文件已生成，但仍在等待 Codex 子进程正常退出。 |
| `files 1/2` | 两个目标 QMD 中已有 1 个生成。 |
| `files ready` | 中文和英文 QMD 都已生成。 |

---

## 样式规则

这套 skill 默认保留当前文档整体风格，并额外统一以下格式：

- callout 使用 Quarto 标准语法：`important`、`note`、`warning`、`tip`、`caution`。
- 不同 callout 类型使用不同颜色。
- fenced code block 在 PDF 中使用 terminal 风格。
- PDF 默认关闭自动章节编号，避免和手写标题编号重复。
- 标题页、目录页、正文之间使用 PDF 分页。
- Markdown 横线在 PDF 中默认隐藏，避免正文出现多余横线。

手动改造 QMD 的模板见：

```text
references/host-setup-zh.md
```

---

## 新主机依赖

同事的新主机需要安装：

| 组件 | 用途 |
| --- | --- |
| VS Code | 运行 Codex / ChatGPT 扩展 |
| OpenAI ChatGPT / Codex 扩展 | 生成优化后的 CN / EN QMD |
| Quarto CLI | 渲染 QMD 到 Typst PDF |
| Python 3 | 部分 Quarto / 文档环境依赖 |
| Windows PowerShell | 执行导出脚本 |

完整安装说明见：

```text
references/host-setup-zh.md
```

---

## 需要分发的文件清单

把这套 skill 发给同事时，保留下面这些文件和目录：

```text
skill/
  README.md
  SKILL.md
  agents/
    openai.yaml
  assets/
    quarto-bilingual-style.scss
    quarto-bilingual-style.typ
  references/
    host-setup-zh.md
    quarto-formatting-patterns.md
  scripts/
    Export-QuartoBilingualPdf.ps1
```

不需要分发：

```text
.git/
.agents/
.codex/
临时生成的 *.typ
临时生成的测试 PDF
```

---

## 常见问题

### 没有 Codex 怎么办

脚本会提示缺少 Codex，并回退为导出原始 QMD PDF。要生成优化后的中文 / 英文 QMD，需要安装并登录 VS Code 的 OpenAI ChatGPT / Codex 扩展。

### 已经手动改好了 QMD，不想重新生成

使用 `-RenderOnly`。这个模式不会调用 Codex，也不会生成或覆盖 CN / EN 文件。

### 图片缺失怎么办

脚本只检查 YAML 中的 `logo:` 是否存在。正文图片需要保留在 QMD 引用的位置，例如 `pic/xxx.png`。

### 目录编号重复怎么办

PDF 默认使用 `number-sections: false`，适合原始 QMD 已经手写标题编号的文档。不要同时使用手写编号和自动章节编号。

---

## 核心文件

| 文件 | 作用 |
| --- | --- |
| `SKILL.md` | 给 Codex 读取的 skill 工作说明 |
| `scripts/Export-QuartoBilingualPdf.ps1` | 双语生成与 PDF 导出的主脚本 |
| `assets/quarto-bilingual-style.typ` | Typst PDF 样式 |
| `assets/quarto-bilingual-style.scss` | HTML / revealjs 辅助样式 |
| `references/host-setup-zh.md` | 新主机安装说明与手动 QMD 模板 |
| `references/quarto-formatting-patterns.md` | Quarto 格式规则参考 |
