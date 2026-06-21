# 新主机安装说明

这份说明用于在新的 Windows 主机上配置 Quarto GPU 文档导出环境。该 skill 默认在已安装 VS Code、并启用 OpenAI ChatGPT/Codex 扩展的平台上使用。

## 必装组件

1. VS Code
   - 安装 Visual Studio Code: <https://code.visualstudio.com/>
   - 在 VS Code 扩展市场安装 OpenAI ChatGPT/Codex 相关扩展。扩展市场用法参考: <https://code.visualstudio.com/docs/configure/extensions/extension-marketplace>
   - 登录可用的 OpenAI/Codex 账号。
   - 验证本机是否存在 Codex CLI：

```powershell
Get-Command codex -ErrorAction SilentlyContinue
Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Recurse -Filter codex.exe -ErrorAction SilentlyContinue
```

2. Quarto CLI
   - 安装 Quarto: <https://quarto.org/docs/get-started/>
   - 安装后重新打开 PowerShell，验证：

```powershell
quarto --version
```

3. Python
   - 安装 Python 3: <https://www.python.org/downloads/windows/>
   - 安装时勾选 Add Python to PATH。
   - 验证：

```powershell
python --version
py -3 --version
```

4. PowerShell
   - Windows 自带 PowerShell 可以直接使用。
   - 如果执行脚本被策略阻止，使用 `powershell -ExecutionPolicy Bypass -File <脚本绝对路径>` 运行。
   - 下面的 `C:\Users\azu\...` 是示例路径，使用者需要改成自己电脑上 `skill\scripts\Export-QuartoBilingualPdf.ps1` 的实际绝对路径。

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -SourceQmd ".\your-file.qmd"
```

## 可选组件

- Typst: 当前导出命令使用 `--to typst`。如果 Quarto 当前版本没有内置可用 Typst，按 Quarto 提示安装 Typst 或升级 Quarto。
- LaTeX/TinyTeX: 仅当改用 LaTeX PDF 引擎时需要。当前 Typst PDF 流程通常不需要。
- Git: 方便同步 skill 文件，但不是导出 PDF 的必需项。

## 文件和图片要求

- QMD 的 `logo:` 路径必须存在，例如 `pic/logo_color_horizontal.png`。
- 内容图片不会由脚本自动恢复或生成。请在原始 QMD 引用的 `pic/` 目录中保留实际图片文件。
- 如果缺少 logo，脚本会停止并提示缺少哪个 logo 文件。

## 导出命令

在 QMD 文件所在目录运行：

推荐路线：

| 需求 | 推荐脚本 | 说明 |
| --- | --- | --- |
| 已有 QMD，只需要统一格式并导出 PDF | `Convert-QuartoOfflineFormat.ps1` | 离线、快速、不调用 Codex，默认生成 `-formatted.qmd` 和 PDF |
| 新写 QMD，已经按照 `references/quarto-formatting-patterns.md` 的规则组织 | `Convert-QuartoOfflineFormat.ps1` | 默认推荐方式，默认直接导出 PDF |
| 需要生成中文/英文两个版本，并追求翻译和改写准确度 | `Export-QuartoBilingualPdf.ps1` | 调用 Codex，会消耗 token |
| 手动已经改好 QMD，只需要导出 PDF | `Export-QuartoBilingualPdf.ps1 -RenderOnly` | 不调用 Codex |

下面命令中的 `C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1` 是示例路径。使用者需要根据自己电脑上 `skill` 目录的实际位置，改成自己的脚本绝对路径。例如如果 `skill` 放在 `D:\quarto\gpu\skill`，脚本路径就是 `D:\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1`。

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -SourceQmd ".\RPP OCC Search Kernel v1.2.qmd"
```

默认行为：

- 如果已经存在 `<basename>-zh-cn.qmd` 和 `<basename>-en.qmd`，直接导出两个 PDF。
- 如果缺少中文或英文 QMD，并且 Codex CLI 可用，自动调用 Codex 基于原始 QMD 生成中文/英文 QMD，再导出两个 PDF。
- 如果缺少中文或英文 QMD，但 Codex CLI 不可用，打印提示并回退为使用原始 QMD 直接导出 PDF。

如果 QMD 已经手动调整好，只想直接导出 PDF，不想等待 Codex 重新生成中文/英文文件，增加 `-RenderOnly`：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -SourceQmd ".\RPP OCC Search Kernel v1.2.qmd" -RenderOnly
```

`-SourceQmd -RenderOnly` 的行为：

- 只导出原始 `-SourceQmd` 对应的 PDF。
- 即使同目录下已经存在 `<basename>-zh-cn.qmd` 和 `<basename>-en.qmd`，也不会自动导出它们。
- 全程不会调用 Codex，也不会生成或覆盖 QMD。

如果要直接导出手动改好的 CN/EN 文件，需要显式指定：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -ChineseQmd ".\xxx-zh-cn.qmd" -EnglishQmd ".\xxx-en.qmd" -RenderOnly
```

当脚本需要调用 Codex 生成新的 CN/EN QMD 时，会分成两个彼此独立的进度阶段。第一阶段是 QMD 内容生成，按自己的 0-100% 计算，例如 `Generate QMD [########################] 100% done elapsed 00:04:05`；只有目标 QMD 文件已经出现时才会显示 100%。第二阶段是 Codex CLI 退出守护，是新的独立进度，例如 `Codex exit [######------------------] 25% files ready elapsed 00:01:00`。第二阶段不表示 QMD 内容还在继续生成，而是在等待 Codex 子进程正常退出。

## 离线格式转换

如果只想把 QMD 调整为当前 PDF 样式规则，不需要 Codex 翻译或润色，优先使用离线格式化脚本。更推荐的工作方式是：先按照 `references/quarto-formatting-patterns.md` 的格式建议编写 QMD，然后默认只运行离线格式转换，这样速度更快，也不消耗 token。

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Convert-QuartoOfflineFormat.ps1 -SourceQmd ".\xxx.qmd"
```

默认输出：

```text
xxx-formatted.qmd
xxx-formatted.pdf
```

离线格式转换会保留原有 YAML 中的标题、作者、日期、`revealjs`、`pptx`、`logo`、`reference-doc` 等配置，并补充或修正 Typst PDF 样式、目录设置、`number-sections: false`、`execute.echo: false` 和 `code-fold: false`。它只会把手动写出的单独一行提示语，例如 `注意：...`、`重要：...`、`警告：...`、`提示：...`、`Note: ...`、`Important: ...`、`Warning: ...`，自动改成 Quarto callout 块；已有 callout、表格、图片和代码块内容不会被改写。它不会根据正文语义自动猜测哪些段落应该变成 callout。如果源文件没有 `logo:`，但当前目录存在 `pic/logo_color_horizontal.png`，脚本会自动补充；如果缺少 logo 文件，会打印提示。它不会翻译正文，也不会自动生成真正的中文/英文双语版本。

## 手动改造 QMD 模板

如果不想等待 Codex 生成，可以手动把原有 QMD 调整为当前规则适配的 QMD，然后使用 `-RenderOnly` 直接导出 PDF。

### 1. 文件命名

建议按用途命名：

- 原始文件：`xxx.qmd`
- 中文文件：`xxx-zh-cn.qmd`
- 英文文件：`xxx-en.qmd`

如果只想导出原始文件，不需要创建 CN/EN 文件。

### 2. YAML 模板

把原有 YAML 中的标题、作者、日期、logo、revealjs、pptx 等配置保留下来，并补充 `format.typst`：

```yaml
---
title: "文档标题"
subtitle: "文档副标题"
author: "XDL Technical Support"
date: "2026-06-21"
lang: zh-CN

format:
  revealjs:
    theme: [league, xdl-tech-theme.scss]
    slide-number: true
    small-footer: "XDL RPP"
    transition: slide
    background-transition: fade
    width: 1280
    height: 720
  pptx:
    theme: simple
    slide-number: true
    footer: "XDL RPP"
  typst:
    toc: true
    toc-depth: 3
    number-sections: false
    include-in-header:
      - "C:/Users/azu/Documents/quarto/gpu/skill/assets/quarto-bilingual-style.typ"

execute:
  echo: false
code-fold: false
logo: pic/logo_color_horizontal.png
reference-doc: template_xdl3.pptx
---
```

英文版本把 `lang` 改为：

```yaml
lang: en-US
```

标题编号建议只保留一套。很多原始 QMD 已经在标题里手动写了 `一、`、`1.`、`2.1`，因此 PDF 默认关闭自动章节编号：

```yaml
number-sections: false
```

如果确实想使用 Quarto 自动编号，请先删除标题文本里的人工编号，否则目录会出现重复编号或层级混乱。

### 3. Callout 模板

使用 Quarto 标准 callout。中文文件可用中文标题，英文文件用英文标题。

```markdown
::: {.callout-important title="重要"}
这里写必须确认的关键事项。
:::

::: {.callout-note title="注意"}
这里写背景说明或补充信息。
:::

::: {.callout-warning title="警告"}
这里写风险、限制或可能失败的情况。
:::

::: {.callout-tip title="提示"}
这里写推荐做法或优化建议。
:::
```

### 4. 代码块模板

命令、日志、代码和终端输出都放在 fenced code block 中，并标注语言。PDF 中会自动显示 terminal 风格。

````markdown
```powershell
quarto render ".\xxx.qmd" --to typst
```

```bash
cmake .. -DGGML_RPP=ON -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

```cpp
__device__ uint32_t* m_nGpuBwtTable;
#define occ_intv(k)
```

```text
PASS
2048 x 32
13107200 Logical Search
```
````

### 5. 图片和 logo

保留原有图片路径，例如：

```markdown
![](pic/rpp.png)
```

确认 YAML 中的 `logo:` 文件存在：

```yaml
logo: pic/logo_color_horizontal.png
```

脚本只检查 `logo:`，不会自动生成或恢复正文图片。

### 6. 横线和分页

原有 Markdown 中的 `---` 可以继续保留，用于 revealjs 分页。PDF 输出会通过 Typst 样式隐藏横线，避免正文中出现不美观的横线。

### 7. 手动文件导出

只导出原始 QMD：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -SourceQmd ".\xxx.qmd" -RenderOnly
```

导出手动改好的中英文 QMD：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -ChineseQmd ".\xxx-zh-cn.qmd" -EnglishQmd ".\xxx-en.qmd" -RenderOnly
```

## 常见问题

### 提示缺少 Codex CLI

说明当前主机没有安装或没有启用 VS Code OpenAI ChatGPT/Codex 扩展。脚本仍会使用原始 QMD 导出 PDF，但不会生成优化后的中文/英文 QMD。

处理方式：

1. 安装 VS Code。
2. 安装 OpenAI ChatGPT/Codex 扩展。
3. 在 VS Code 中登录账号。
4. 重新打开 PowerShell 后再次执行导出命令。

### 提示 `quarto` 找不到

说明 Quarto 没有安装，或者安装后 PATH 没有刷新。安装 Quarto 后重新打开 PowerShell，再运行：

```powershell
quarto --version
```

### 提示 Python 找不到

说明 Python 没有安装，或者 PATH 没有配置。安装 Python 3 后重新打开 PowerShell，再运行：

```powershell
python --version
```

### 图片缺失

脚本只检查 `logo:` 文件是否存在。正文图片需要手动保留在 QMD 引用的位置，例如 `pic/xxx.png`。
