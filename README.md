# pandoc-chem-sub.lua

A [Pandoc](https://pandoc.org) Lua filter that handles two related tasks in a
single pass:

1. **Chemical formula formatting** — `[formula]{.chem}` span syntax renders subscripts,
   superscripts, reaction arrows, charges, and states of aggregation.
2. **Compound name substitution** — `{key}` placeholders are replaced with
   inline content defined in document metadata.

For LaTeX and Beamer output the filter delegates chemical rendering to the
[mhchem](https://ctan.org/pkg/mhchem) package (`\ce{}`), so full mhchem
fidelity is preserved in PDF output. For all other formats (HTML, DOCX, EPUB,
…) the filter renders formulas directly as pandoc inline elements using
Unicode characters.

Without the filter the formula text is visible in the output as-is, providing
a readable plain-text fallback.

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

## Chemical formulas: `[...]{.chem}`

Write `[formula]{.chem}` anywhere in inline text using standard Pandoc span
syntax. The filter recognises mhchem-style formula notation inside the span.

### Subscripts and superscripts

Digits are automatically subscripted. Charges use `^`:

| Source | Rendered |
|---|---|
| `[CH3OH]{.chem}` | CH₃OH |
| `[SO4^2-]{.chem}` | SO₄²⁻ |
| `[Na+]{.chem}` | Na⁺ |
| `[CH3O-]{.chem}` | CH₃O⁻ |

Explicit groups with `^{...}` and `_{...}` are also supported:

| Source | Rendered |
|---|---|
| `[SO4^{2-}]{.chem}` | SO₄²⁻ |
| `[\^{14}_{6}C]{.chem}` | ¹⁴₆C |
| `[Fe^{III}]{.chem}` | Fe<sup>III</sup> |

### Reaction equations

Reaction arrows and the `+` operator between species are recognised. Spaces
inside the span are allowed, making source text easier to read:

| Source | Rendered |
|---|---|
| `[H2 + Cl2 -> 2 HCl]{.chem}` | H₂ + Cl₂ → 2 HCl |
| `[H2O <=> H+ + OH-]{.chem}` | H₂O ⇌ H⁺ + OH⁻ |
| `[A -> B <- C]{.chem}` | A → B ← C |

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
| `[NaCl(s)]{.chem}` | NaCl(s) |
| `[HCl(g)]{.chem}` | HCl(g) |
| `[CrO4^2-(aq)]{.chem}` | CrO₄²⁻(aq) |

Recognised labels: `aq`, `aq,sat`, `s`, `l`, `g`, `cr`, `am`, `vit`.

### Precipitate and gas markers

| Source | Rendered |
|---|---|
| `[BaSO4(v)]{.chem}` | BaSO₄↓ |
| `[NH3^]{.chem}` | NH₃↑ |
| `[NH3(^)]{.chem}` | NH₃↑ |

### Explicit bonds

Bare `-`, `=`, and `#` between atoms/groups render as single, double, and
triple bonds. A `-` not followed by an atom/group is treated as a trailing
charge instead:

| Source | Rendered |
|---|---|
| `[CH3-CH3]{.chem}` | CH₃–CH₃ |
| `[CH2=CH2]{.chem}` | CH₂=CH₂ |
| `[HC#CH]{.chem}` | HC≡CH |
| `[CH2=CH-CH3]{.chem}` | CH₂=CH–CH₃ |
| `[CH3O-]{.chem}` | CH₃O⁻ |

### Centre dots and hydrates

A `.` is rendered as a middle dot (·, U+00B7). Digits that immediately follow
are treated as a stoichiometric coefficient (plain text, not subscripted):

| Source | Rendered |
|---|---|
| `[CuSO4.5H2O]{.chem}` | CuSO₄·5H₂O |
| `[KCr(SO4)2.12H2O]{.chem}` | KCr(SO₄)₂·12H₂O |

### Radical dots

A `.` inside an explicit `^{...}` group is rendered as a middle dot (·, U+00B7):

| Source | Rendered |
|---|---|
| `[CH3^{.}]{.chem}` | CH₃<sup>·</sup> |
| `[\^{.}OH]{.chem}` | <sup>·</sup>OH |
| `[NO^{(2.)-}]{.chem}` | NO<sup>(2·)⁻</sup> |

### Complex species

Square brackets and nested parentheses are handled recursively:

| Source | Rendered |
|---|---|
| `[[AgCl2]-]{.chem}` | [AgCl₂]⁻ |
| `[KCr(SO4)2]{.chem}` | KCr(SO₄)₂ |

### Explicit bonds: `\bond{...}`

mhchem's `\bond{TYPE}` command covers bond types that a bare `-`/`=`/`#`
character can't express: numeric aliases, undefined-stereochemistry (wavy)
bonds, hash/wedge stereo combinations, dotted/hydrogen bonds, and in-molecule
arrow bonds. For LaTeX/Beamer output `\bond{...}` is passed straight through
to `\ce{}`, giving full mhchem fidelity. For other formats it's approximated
with Unicode:

| `\bond{...}` | Meaning | Rendered (non-LaTeX) |
|---|---|---|
| `-` or `1` | single bond | – |
| `=` or `2` | double bond | = |
| `#` or `3` | triple bond | ≡ |
| `~` | undefined stereochemistry (wavy bond) | ⁓ |
| `~-`, `-~` | single bond, hash/wedge | ⁓–, –⁓ |
| `~=`, `=~` | double bond, hash/wedge | ⁓=, =⁓ |
| `~--`, `--~`, `-~-` | double bond, wedge/hash variants | ⁓––, ––⁓, –⁓– |
| `...`, `....` | dotted/hydrogen bond (N dots) | ···, ···· |
| `->`, `<-` | arrow bond (within a species) | →, ← |

Stereo/wedge combinations are rendered by transliterating each character in
the brace independently and concatenating the results — there isn't a
distinct glyph for every combination, so some exotic combos can't be drawn
as faithfully as two stacked bond lines in a chemistry-typesetting system.
Dotted bonds render as that many repeated middle dots, matching the source
count.

Unrecognised `TYPE` values are passed through as literal text (e.g.
`\bond{xyz}` renders as `\bond{xyz}`) rather than causing an error.

#### Markdown-source escaping required

Pandoc's markdown reader mangles raw `\bond{...}` text before the filter
ever sees it, so the source needs some extra escaping:

1. **Doubled backslash.** A single backslash before a letter becomes a raw
   TeX node whose content is dropped on every output path. Write `\\bond{...}`
   (which Pandoc collapses to one literal backslash) instead of `\bond{...}`.
2. **Escape every `~`.** A bare `~` is Pandoc's subscript-pair delimiter.
   Two unrelated `\bond{~...}` occurrences later in the same formula can pair
   up and swallow everything between them. Escape each one as `\~`.
3. **Escape every `.` in a dotted bond.** Pandoc's `smart` extension turns
   3+ unescaped periods into an ellipsis character. Escape each one as `\.`.
4. **Escape at least one hyphen in any adjacent hyphen pair.** Pandoc's
   `smart` extension converts adjacent unescaped hyphens to en/em dashes.
   Escape at least one as `\-` (hyphens separated by another character, like
   the two in `-~-`, don't need it).

For example, `\bond{~--}` must be written in Markdown source as
`\\bond{\~-\-}`.

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
[H2 + Cl2 -> 2 HCl]{.chem}  →  \ce{H2 + Cl2 -> 2 HCl}
```

---

## Mixing both features

Both features work together on the same line:

```markdown
React [H2O]{.chem} with [SO4^2-]{.chem} to get {water}.
```

---

## Limitations

- Formulas whose first character is `^` and that contain no spaces must
  escape the leading caret as `\^`. Pandoc interprets `[^...]` without spaces
  as a footnote reference before the filter runs. Write `[\^{14}_{6}C]{.chem}`
  rather than `[^{14}_{6}C]{.chem}`. Formulas starting with `^` that contain
  spaces (such as reaction equations) are unaffected.
- `\bond{...}` requires specific Markdown-source escaping (doubled backslash,
  escaped `~`, escaped `.`, escaped adjacent `-`) to survive Pandoc's
  markdown reader — see [Markdown-source escaping
  required](#markdown-source-escaping-required).

---

## Related filters

[pandoc-eqref.lua](https://github.com/scotthartley/pandoc-eqref-lua) can be
used alongside this filter to add numbered equation references to chemical
equations.

---

## Acknowledgments

This filter was written by [Claude Code](https://claude.ai/claude-code),
Anthropic's AI coding assistant.
