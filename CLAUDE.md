# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the filter

```bash
# HTML output
pandoc --lua-filter pandoc-chem-sub.lua test.md -o tests/test.html

# PDF/LaTeX output (requires mhchem package)
pandoc --lua-filter pandoc-chem-sub.lua test.md -o output.pdf

# DOCX output
pandoc --lua-filter pandoc-chem-sub.lua test.md -o output.docx
```

There is no test framework — verify by inspecting the rendered output from `test.md` against the expected values in the README tables.

## Architecture

Single-file Lua filter (`pandoc-chem-sub.lua`) with one entry point: `function Pandoc(doc)`, which does a single-pass `doc:walk` with two walkers:

- **`Span` walker** — handles `[formula]{.chem}` spans. For `latex`/`beamer` formats, emits `\ce{formula}` as a `RawInline`. For all other formats, calls `format_ce()` to produce pandoc inline elements.
- **`Str` walker** — handles `{key}` substitution placeholders by looking them up in the metadata dictionary.

### Formula rendering pipeline (non-LaTeX)

```
Span content
  → pandoc.utils.stringify (reassembles tokens, preserving spaces)
  → whitespace stripped
  → tokenize_ce()       splits at arrows and inter-species '+'
  → format_species()    extracts leading coefficient
  → parse_formula_body() recursive character-level renderer
```

`parse_formula_body` handles: `^{}`/`_{}` explicit groups, `^sign` charge shorthand, `[...]` square brackets (recursive), `(...)` parentheses (states of aggregation, precipitate/gas markers, polymer subscripts, or recursive), digits→Subscript, `.`→middle dot, `+`/`-`→Superscript.

### Substitution pipeline

`get_sub_dict(meta)` reads `meta.substitutions` or `meta["compound names"]` (MetaMap of MetaInlines). `process_str()` scans each `Str` element for `{key}` patterns and replaces them with the corresponding MetaInlines list. Unknown keys are passed through unchanged.

## Key constraints

- **Leading `^` in spans**: `[^...]` without spaces is parsed by Pandoc as a footnote reference before the filter runs. Escape as `[\^...]{.chem}`. Spaced reactions like `[^{14}C + ... ]{.chem}` are unaffected.
- **LaTeX path**: formula content is passed verbatim to `\ce{}` with only two fixups: bare `^$` and `(^)` are normalised to ` ^` (mhchem gas marker syntax).
- **`format_species` coefficient pattern**: `^(%d+[%.%/]?%d*)([%a%[%^%_%(].*)` — requires the remainder to start with a letter, `[`, `^`, `_`, or `(` to avoid treating bare numbers as coefficients.
