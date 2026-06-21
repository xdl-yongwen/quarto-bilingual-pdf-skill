# Quarto Formatting Patterns

## File Naming

Default output names:

- Chinese: `<source-base>-zh-cn.qmd`
- English: `<source-base>-en.qmd`
- PDFs: produced by Quarto beside each `.qmd`

If the source already ends with `_CN`, `-CN`, `_zh-cn`, or `-zh-cn`, normalize the Chinese output to `-zh-cn` and the English output to `-en` unless the user gives a naming convention.

## Preserve Existing Layout

Most existing GPU documents use this reveal/PPT layout. Preserve it for slide or PPT outputs:

```yaml
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
execute:
  echo: false
code-fold: false
logo: pic/logo_color_horizontal.png
reference-doc: template_xdl3.pptx
```

For PDF output, add or merge this Typst target without removing existing formats:

```yaml
format:
  typst:
    toc: true
    toc-depth: 3
    number-sections: false
    include-in-header:
      - "C:/Users/azu/Documents/quarto/gpu/skill/assets/quarto-bilingual-style.typ"
```

If the document already has `format.typst`, only add missing keys. Do not clobber user-defined paper size, margins, numbering, logo, or template choices.

## Callout Color Scheme

Use Quarto callout classes and let the bundled Typst/SCSS assets provide colors.

| Type | Chinese title | English title | Accent | Use for |
|---|---|---|---|---|
| important | 重要 | Important | Red | Must-do, blocker, critical prerequisite |
| note | 注意 | Note | Blue | Clarification, context |
| warning | 警告 | Warning | Amber | Risk, failure, compatibility issue |
| tip | 提示 | Tip | Green | Best practice, optimization |
| caution | 谨慎 | Caution | Violet | Irreversible or delicate step |

Prefer standard callout blocks in source QMD:

```markdown
::: {.callout-important title="重要"}
这里写必须确认的关键事项。
:::

::: {.callout-warning title="警告"}
这里写风险、限制或可能失败的情况。
:::
```

The offline formatter also normalizes standalone one-line prompts into callouts, for example:

```markdown
注意：必须使用 eth0 端口。
Important: Confirm the package MD5 before installation.
Warning: Do not reboot during upgrade.
```

Existing callout blocks and fenced code blocks are not rewritten by the offline formatter.

## Terminal Code Blocks

Use language labels:

```markdown
```bash
cmake .. -DGGML_RPP=ON -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

```console
05:00.0 Co-processor: Device 1f2e:00a1 (rev 01)
```
```

Do not wrap terminal output as prose. Keep prompts/output in code fences so the Typst style can render them as terminal panels.

## PDF Layout Defaults

The bundled Typst style applies these defaults:

- Code fences render as terminal panels with a title bar identifying the fence language.
- The title page, table of contents, and body start on separate pages.
- The table of contents title is centered.
- PDF heading auto-numbering is disabled by default because many source QMD headings already contain manual numbers such as `1.`, `2.1`, or `一、`.
- Markdown horizontal rules are hidden in PDF output, so `---` can remain in source files for revealjs slide separation without adding decorative lines to PDFs.
