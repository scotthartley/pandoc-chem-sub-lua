# pandoc-chem-sub.lua

A [Pandoc](https://pandoc.org) Lua filter that handles two related tasks in a
single pass:

1. **Chemical formula formatting** — `s:{formula}` syntax renders subscripts,
   superscripts, reaction arrows, charges, and states of aggregation.
2. **Compound name substitution** — `{key}` placeholders are replaced with
   inline content defined in document metadata.

For LaTeX and Beamer output the filter delegates chemical rendering to the
[mhchem](https://ctan.org/pkg/mhchem) package (`\ce{}`), so full mhchem
fidelity is preserved in PDF output. For all other formats (HTML, DOCX, EPUB,
…) the filter renders formulas directly as pandoc inline elements using
Unicode characters.

---

## Requirements

- Pandoc 2.17 or later (Lua 5.4 filter API)
- For PDF/LaTeX output: the `mhchem` LaTeX package (`\usepackage{mhchem}`)

---

## Installation

Copy `pandoc-chem-sub.lua` to your project directory (or any location on your
`$PATH`). No other files are needed.

---

## Usage

```
pandoc --lua-filter pandoc-chem-sub.lua input.md -o output.html
pandoc --lua-filter pandoc-chem-sub.lua input.md -o output.pdf
```

---

## Chemical formulas: `s:{...}`

Write `s:{formula}` anywhere in inline text. The filter recognises mhchem-style
formula notation inside the braces.

### Subscripts and superscripts

Digits are automatically subscripted. Charges use `^`:

| Source | Rendered |
|---|---|
| `s:{CH3OH}` | CH₃OH |
| `s:{SO4^2-}` | SO₄²⁻ |
| `s:{Na+}` | Na⁺ |
| `s:{CH3O-}` | CH₃O⁻ |

Explicit groups with `^{...}` and `_{...}` are also supported:

| Source | Rendered |
|---|---|
| `s:{SO4^{2-}}` | SO₄²⁻ |
| `s:{^{14}_{6}C}` | ¹⁴₆C |
| `s:{Fe^{III}}` | Fe^(III) |

### Reaction equations

Reaction arrows and the `+` operator between species are recognised. Spaces
inside `s:{...}` are allowed, making source text easier to read:

| Source | Rendered |
|---|---|
| `s:{H2 + Cl2 -> 2 HCl}` | H₂ + Cl₂ → 2 HCl |
| `s:{H2O <=> H+ + OH-}` | H₂O ⇌ H⁺ + OH⁻ |
| `s:{A -> B <- C}` | A → B ← C |

Supported arrow tokens (mhchem notation):

| Token | Arrow |
|---|---|
| `->` | → |
| `<-` | ← |
| `<=>` | ⇌ |
| `<->` | ↔ |
| `<-->` | ⟷ |
| `<=>>` | ⇒ |
| `<<=>` | ⇐ |

### States of aggregation

Write the state label inside parentheses immediately after the formula:

| Source | Rendered |
|---|---|
| `s:{NaCl(s)}` | NaCl(s) |
| `s:{HCl(g)}` | HCl(g) |
| `s:{CrO4^2-(aq)}` | CrO₄²⁻(aq) |

Recognised labels: `aq`, `aq,sat`, `s`, `l`, `g`, `cr`, `am`, `vit`.

### Precipitate and gas markers

| Source | Rendered |
|---|---|
| `s:{BaSO4(v)}` | BaSO₄↓ |
| `s:{NH3^}` | NH₃↑ |
| `s:{NH3(^)}` | NH₃↑ |

### Complex species

Square brackets and nested parentheses are handled recursively:

| Source | Rendered |
|---|---|
| `s:{[AgCl2]-}` | [AgCl₂]⁻ |
| `s:{KCr(SO4)2}` | KCr(SO₄)₂ |

---

## Compound name substitution: `{key}`

Define a `substitutions` map (or `compound names`) in the document YAML
front matter. Any `{key}` in the text is replaced with the corresponding
value, which can itself contain Markdown inline formatting.

```yaml
---
substitutions:
  water: H~2~O
  aspirin: acetylsalicylic acid
  vitamin-c: ascorbic acid
---
```

In the document body:

```markdown
React {water} with {aspirin} to form a precipitate.
```

Unknown keys are left as-is (`{unknown}` is passed through unchanged).

The metadata key `compound names` (with a space) is also accepted as an
alternative to `substitutions`.

---

## LaTeX / PDF output

For `latex` and `beamer` targets the filter emits `\ce{...}` for every
chemical formula, passing the content verbatim so that mhchem handles
all rendering. Include the package in your document:

```yaml
---
header-includes:
  \usepackage{mhchem}
---
```

Spaced reaction syntax is preserved as-is inside `\ce{}`, which is what
mhchem expects:

```
s:{H2 + Cl2 -> 2 HCl}  →  \ce{H2 + Cl2 -> 2 HCl}
```

---

## Mixing both features

Both features work together on the same line:

```markdown
React s:{H2O} with s:{SO4^2-} to get {water}.
```

---

## Limitations

- `_{...}` subscript notation inside a spaced `s:{...}` expression (e.g.
  `s:{^{14}_{6}C + ...}`) is not supported in Markdown source because
  Pandoc's parser treats `_` as an emphasis delimiter before the filter
  runs. Use the compact form `s:{^{14}_{6}C}` (no spaces) for formulas
  containing explicit subscript groups.

---

## Acknowledgments

This filter was written by [Claude Code](https://claude.ai/claude-code),
Anthropic's AI coding assistant.
