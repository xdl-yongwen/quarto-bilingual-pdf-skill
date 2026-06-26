// Quarto Typst styling for bilingual XDL/GPU technical documents.
// Include from QMD frontmatter with format.typst.include-in-header.

#let xdl-terminal-bg = rgb("#101820")
#let xdl-terminal-fg = rgb("#E6EDF3")
#let xdl-terminal-border = rgb("#2E4057")
#let xdl-terminal-title-bg = rgb("#2B2B2B")
#let xdl-terminal-title-fg = rgb("#DDE7F3")

// Hide Markdown horizontal rules in PDF output. They are useful as slide separators
// in QMD/revealjs, but look noisy in article-style PDFs.
#show line: none

#show raw.where(block: true): it => {
  let fields = it.fields()
  let lang = fields.at("lang", default: "text")
  if lang == none or lang == "" {
    lang = "text"
  }
  let body = fields.at("text", default: "")

  block(
    fill: xdl-terminal-bg,
    stroke: (paint: xdl-terminal-border, thickness: 0.7pt),
    radius: 2pt,
    inset: 0pt,
    width: 100%,
    breakable: true,
  )[
    #block(fill: xdl-terminal-title-bg, width: 100%, inset: (x: 8pt, y: 4pt))[
      #text(font: "Cascadia Mono", size: 0.78em, fill: xdl-terminal-title-fg, weight: "bold")[#(">_ " + lang + " - terminal")]
      #h(1fr)
      #text(font: "Cascadia Mono", size: 0.72em, fill: rgb("#AEB7C2"))[#("--  []  x")]
    ]
    #block(fill: xdl-terminal-bg, width: 100%, inset: 10pt)[
      #text(font: "Cascadia Mono", size: 0.9em, fill: xdl-terminal-fg)[#raw(body, lang: lang, block: false)]
    ]
  ]
}

#let xdl-callout-colors = (
  important: (bg: rgb("#FDECEC"), body: rgb("#FFF8F8"), accent: rgb("#C62828")),
  warning: (bg: rgb("#FFF3D6"), body: rgb("#FFFCF3"), accent: rgb("#B45309")),
  note: (bg: rgb("#EAF3FF"), body: rgb("#F7FBFF"), accent: rgb("#1565C0")),
  tip: (bg: rgb("#EAF7EF"), body: rgb("#F7FCF9"), accent: rgb("#2E7D32")),
  caution: (bg: rgb("#F1ECFF"), body: rgb("#FBF9FF"), accent: rgb("#6A1B9A")),
)

#let callout(body: [], title: "Callout", background_color: rgb("#EAEAEA"), icon: none, icon_color: rgb("#374151"), body_background_color: white) = {
  let palette = xdl-callout-colors.values().find(c => c.accent == icon_color)
  let bg = if palette == none { background_color } else { palette.bg }
  let body-bg = if palette == none { body_background_color } else { palette.body }
  block(
    breakable: true,
    fill: bg,
    stroke: (paint: icon_color, thickness: 0.8pt),
    width: 100%,
    radius: 3pt,
    inset: 0pt,
  )[
    #block(fill: bg, width: 100%, inset: 8pt)[
      #text(fill: icon_color, weight: "bold")[#if icon != none { icon } #title]
    ]
    #if body != [] {
      block(fill: body-bg, width: 100%, inset: 9pt)[#body]
    }
  ]
}

// Override Pandoc's default article wrapper to create a clean PDF structure:
// title page -> page break -> centered TOC -> page break -> body.
#let article(
  title: none,
  subtitle: none,
  authors: none,
  date: none,
  abstract: none,
  abstract-title: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: "libertinus serif",
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: "libertinus serif",
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set par(justify: true)
  set text(lang: lang, region: region, font: font, size: fontsize)

  // Existing source documents often already contain manual heading numbers
  // such as "1.", "2.1", or "一、". Disable Typst's automatic heading
  // numbering to avoid duplicated and confusing TOC entries.
  set heading(numbering: none)

  if title != none {
    align(center)[#block(inset: 2em)[
      #set par(leading: heading-line-height)
      #if (heading-family != none or heading-weight != "bold" or heading-style != "normal" or heading-color != black) {
        set text(font: heading-family, weight: heading-weight, style: heading-style, fill: heading-color)
        text(size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(size: subtitle-size)[#subtitle]
        }
      } else {
        text(weight: "bold", size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(weight: "bold", size: subtitle-size)[#subtitle]
        }
      }
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
        align(center)[
          #author.name \
          #author.affiliation \
          #author.email
        ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[#date]]
  }

  if abstract != none {
    block(inset: 2em)[#text(weight: "semibold")[#abstract-title] #h(1em) #abstract]
  }

  if toc {
    pagebreak()
    let shown_toc_title = if toc_title == none {
      if lang == "zh-CN" or lang == "zh" { [目录] } else { [Table of contents] }
    } else {
      toc_title
    }
    align(center)[#text(weight: "bold", size: 1.35em)[#shown_toc_title]]
    v(1em)
    outline(title: none, depth: toc_depth, indent: toc_indent)
    pagebreak()
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}
