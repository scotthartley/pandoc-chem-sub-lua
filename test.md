---
header-includes:
  \usepackage{mhchem}
substitutions:
  water: H~2~O
  aspirin: acetylsalicylic acid
  vitamin-c: ascorbic acid
---

# Chemical Structure Tests

## Simple formulas

Simple formula: [CH3OH]{.chem}

With explicit charge: [SO4^2-]{.chem}

With implicit charge: [Na+]{.chem}

With implicit negative: [CH3O-]{.chem}

Longer formula: [CH3CH2OH]{.chem}

## Substitutions

Compound name: {water}

Another compound: {aspirin}

Hyphenated key: {vitamin-c}

Unknown placeholder: {unknown}

## Mixed content

React [H2O]{.chem} with [SO4^2-]{.chem} to get {water}.

Prefix [Na+]{.chem} and {aspirin} suffix.

## No-pattern strings

This line has no patterns and should pass through unchanged.

Just a {  } with spaces inside should not match.

## Reactions

Simple reaction: [H2 + Cl2 -> 2 HCl]{.chem}

Equilibrium: [H2O <=> H+ + OH-]{.chem}

Double arrow: [A -> B <- C]{.chem}

Multi-species: [BaSO4 (v) <- Ba^2+ + SO4^2-]{.chem}

Isotope reaction: [^{14}C + ^{1}H -> ^{15}N]{.chem}

## States of aggregation

Aqueous ion: [CrO4^2-(aq)]{.chem}

Solid: [BaSO4(s)]{.chem}

## Brackets

Complex anion: [[AgCl2]-]{.chem}

## Isotopes and explicit groups

Isotope: [\^{14}_{6}C]{.chem}

Oxidation state: [Fe^{III}]{.chem}

Explicit charge group: [SO4^{2-}]{.chem}

## Precipitate and gas markers

Precipitate: [BaSO4(v)]{.chem}

Gas: [NH3^]{.chem}

Gas alt: [NH3(^)]{.chem}

## Parenthesised groups

Hydrate: [KCr(SO4)2]{.chem}

## Explicit bonds

Single bond: [CH3-CH3]{.chem}

Single bond to heteroatom: [CH3-OH]{.chem}

Double bond: [CH2=CH2]{.chem}

Triple bond: [HC#CH]{.chem}

Mixed bonds: [CH2=CH-CH3]{.chem}

Trailing charge (not a bond): [CH3O-]{.chem}

## Centre dots and radicals

Hydrate (centre dot): [CuSO4.5H2O]{.chem}

Hydrate (complex): [KCr(SO4)2.12H2O]{.chem}

Methyl radical: [CH3^{.}]{.chem}

Hydroxyl radical: [\^{.}OH]{.chem}

Radical anion: [NO^{(2.)-}]{.chem}
