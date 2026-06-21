---
name: skill
description: Format Quarto Markdown (.qmd) technical documents while preserving the existing XDL/GPU document layout. Use when Codex needs to polish Quarto Markdown, add colored callout blocks, apply terminal-style code block rendering, generate Chinese and English bilingual output files from either source language, and automatically export the finalized Quarto files to PDF through Quarto Typst preview/render commands.
---

# Quarto Bilingual Formatter

## Core Workflow

1. Inspect the source `.qmd` frontmatter and nearby files before editing. Preserve existing title/subtitle/author/date/logo/reference-doc/theme values unless the user asks to change them.
2. Produce two final `.qmd` files by default:
   - Chinese: `<basename>-zh-cn.qmd`, with `lang: zh-CN`
   - English: `<basename>-en.qmd`, with `lang: en-US`
3. Translate only prose, headings, table text, figure captions, callout titles, and explanatory comments. Preserve commands, code fences, paths, package names, model names, hardware names, API names, logs, version numbers, and identifiers unless there is an obvious human-language phrase inside a comment or caption.
4. Keep the existing XDL/GPU layout style. Reuse the source YAML structure, especially `format.revealjs`, `pptx`, `logo`, `reference-doc`, fonts, slide size, footer, and execution options.
5. Add or retain Typst PDF output styling using the bundled assets when the target is PDF.
6. Render both finalized files to PDF automatically unless the user explicitly asks not to.
7. For PDF output, set `format.typst.number-sections: false` by default unless the user has removed all manual heading numbers. Do not combine automatic heading numbering with headings that already contain `1.`, `2.1`, `一、`, or similar prefixes.

## Bilingual Output Rules

- If the source is Chinese, create the Chinese file as the polished canonical version and create the English file by translation.
- If the source is English, create the English file as the polished canonical version and create the Chinese file by translation.
- If the source mixes Chinese and English, normalize each final file so body prose is consistently in the target language while technical tokens remain unchanged.
- Keep tables, list nesting, anchors, cross-references, image links, and code fences structurally identical between the two versions.
- Use terminology consistently: RPP, XDL SDK, AzurEngine, llama.cpp, GGUF, PCIe, DKMS, CMake, kernel, backend, driver, firmware, and SDK should usually remain unchanged.

## Callout Blocks

Use Quarto callouts for key prompts. Prefer these types and meanings:

- `important`: critical action, must-do item, blocking prerequisite. Color: red.
- `warning`: risk, failure mode, destructive operation, compatibility caveat. Color: amber/orange.
- `note`: neutral explanation, background, clarification. Color: blue.
- `tip`: recommended practice, shortcut, optimization. Color: green.
- `caution`: careful operation, irreversible or easy-to-misread step. Color: violet.

Write callouts with standard Quarto syntax:

```markdown
::: {.callout-important title="Important"}
Confirm the SDK package MD5 before installation.
:::

::: {.callout-note title="Note"}
The first RPP model load may take longer because the weight cache is generated.
:::

::: {.callout-warning title="Warning"}
Do not reboot while the driver package is being installed.
:::
```

Use localized titles in the Chinese file: `重要`, `注意`, `警告`, `提示`, `谨慎`.
Use English titles in the English file: `Important`, `Note`, `Warning`, `Tip`, `Caution`.

## Terminal Code Styling

- Keep shell commands in fenced blocks with `bash`, `sh`, `powershell`, `console`, or `text` language labels.
- Use `console` or `text` for expected terminal output.
- Do not translate command text or output unless it is a user-facing sentence outside the command.
- For PDF/Typst output, include `assets/quarto-bilingual-style.typ` through the target file frontmatter.
- For HTML/reveal output, include `assets/quarto-bilingual-style.scss` when a document already uses SCSS themes.


## PDF Layout Defaults

- Render fenced code blocks as a single dark terminal panel with a top title bar such as `>_ cpp - terminal` or `>_ text - terminal`.
- Keep the document title page separate from the table of contents.
- Center the table of contents title and keep the table of contents separate from the body.
- Hide Markdown horizontal rules in Typst/PDF output by default; keep them in QMD when they are useful as revealjs slide separators.
## PDF Export

Use the bundled PowerShell script when possible:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -SourceQmd "RPP OCC Search Kernel v1.2.qmd"
```

The script uses `quarto render` by default so both language PDFs can be exported without blocking. With `-SourceQmd`, derive the expected bilingual filenames and automatically generate any missing `-zh-cn.qmd` or `-en.qmd` file through Codex before exporting. If Codex is not installed or cannot run, print a clear warning and fall back to exporting the original source QMD as PDF. The script should only check that the YAML `logo:` asset exists; do not attempt to repair or regenerate other `pic/` images. Use `-Mode preview` only for manual preview sessions:

```powershell
quarto preview "xxx.qmd" --to typst --no-browser --no-watch-inputs
```

When the user has already manually adjusted QMD files and only wants PDFs, use `-RenderOnly` to skip Codex generation entirely:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\azu\Documents\quarto\gpu\skill\scripts\Export-QuartoBilingualPdf.ps1 -SourceQmd "RPP OCC Search Kernel v1.2.qmd" -RenderOnly
```

With `-SourceQmd -RenderOnly`, render only the source QMD directly. Do not derive, generate, or render CN/EN files in this mode. To render explicit manually edited CN/EN files, pass `-ChineseQmd`, `-EnglishQmd`, or both with `-RenderOnly`.

When Codex generation is required, show two concise independent progress stages. Stage 1 is QMD content generation and uses its own 0-100% progress, for example `Generate QMD [########################] 100% done elapsed 00:04:05`; do not mark it complete until the target QMD files exist. Stage 2 is a separate watchdog for Codex CLI shutdown, for example `Codex exit [######------------------] 25% files ready elapsed 00:01:00`. The last stage does not mean QMD content is still being generated; it waits for the Codex subprocess to exit cleanly. Suppress Codex subprocess stdout/stderr during normal runs; only surface a concise warning when Codex fails or the target QMD files are missing.

Use `-Mode preview` only when the user explicitly wants Quarto to keep a local preview server open.

## Reference

Read `references/quarto-formatting-patterns.md` when you need concrete YAML snippets, callout color mapping, or filename conventions.
Read `references/host-setup-zh.md` when the user needs Chinese setup instructions for a new Windows host, VS Code/Codex extension, Quarto, Python, export troubleshooting, or a manual QMD adaptation template.
