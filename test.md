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

Simple formula: s:{CH3OH}

With explicit charge: s:{SO4^2-}

With implicit charge: s:{Na+}

With implicit negative: s:{CH3O-}

Longer formula: s:{CH3CH2OH}

## Substitutions

Compound name: {water}

Another compound: {aspirin}

Hyphenated key: {vitamin-c}

Unknown placeholder: {unknown}

## Mixed content

React s:{H2O} with s:{SO4^2-} to get {water}.

Prefix s:{Na+} and {aspirin} suffix.

## No-pattern strings

This line has no patterns and should pass through unchanged.

Just a {  } with spaces inside should not match.

## Reactions

Simple reaction: s:{H2 + Cl2 -> 2 HCl}

Equilibrium: s:{H2O <=> H+ + OH-}

Double arrow: s:{A -> B <- C}

Multi-species: s:{BaSO4 (v) <- Ba^2+ + SO4^2-}

Isotope reaction: s:{^{14}C + ^{1}H -> ^{15}N}

## States of aggregation

Aqueous ion: s:{CrO4^2-(aq)}

Solid: s:{BaSO4(s)}

## Brackets

Complex anion: s:{[AgCl2]-}

## Isotopes and explicit groups

Isotope: s:{^{14}_{6}C}

Oxidation state: s:{Fe^{III}}

Explicit charge group: s:{SO4^{2-}}

## Precipitate and gas markers

Precipitate: s:{BaSO4(v)}

Gas: s:{NH3^}

Gas alt: s:{NH3(^)}

## Parenthesised groups

Hydrate: s:{KCr(SO4)2}

## Centre dots and radicals

Hydrate (centre dot): s:{CuSO4.5H2O}

Hydrate (complex): s:{KCr(SO4)2.12H2O}

Methyl radical: s:{CH3^{.}}

Hydroxyl radical: s:{^{.}OH}

Radical anion: s:{NO^{(2.)-}}
