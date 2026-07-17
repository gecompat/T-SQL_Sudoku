# Sources and method provenance

This project does not claim authorship of the Sudoku solving methods listed below. The T-SQL implementation is original to this repository, while the logical rules and terminology are based on established Sudoku community references and general algorithm literature.

## Primary Sudoku references

### HoDoKu

HoDoKu by Bernhard Hobiger is the main reference for the advanced human-style solving taxonomy used by this project.

- General technique index: https://hodoku.sourceforge.net/en/techniques.php
- Basic fish: https://hodoku.sourceforge.net/en/tech_fishb.php
- General fish model, fins, and sashimi: https://hodoku.sourceforge.net/en/tech_fishg.php
- Complex fish: https://hodoku.sourceforge.net/en/tech_fishc.php
- Wings: https://hodoku.sourceforge.net/en/tech_wings.php
- Single-digit patterns: https://hodoku.sourceforge.net/en/tech_sdp.php
- Coloring: https://hodoku.sourceforge.net/en/tech_col.php
- Chains, AIC, Nice Loops, grouped links, and ALS in chains: https://hodoku.sourceforge.net/en/tech_chains.php
- Uniqueness techniques: https://hodoku.sourceforge.net/en/tech_ur.php

HoDoKu is used as the primary source for:

- X-Wing, Swordfish, and Jellyfish
- finned and sashimi fish terminology
- Skyscraper, Two-String Kite, and Empty Rectangle
- XY-Wing, XYZ-Wing, W-Wing, and related wing terminology
- Simple Coloring, Multi-Coloring, and Remote Pairs
- X-Chains and XY-Chains
- Alternating Inference Chains
- Continuous and Discontinuous Nice Loops
- grouped AIC and grouped links
- the distinction between chains and nets

### Sudopedia

Sudopedia is used as a terminology cross-reference and for concise formal definitions.

- Solving technique taxonomy: https://www.sudopedia.org/wiki/Solving_Technique
- Terminology: https://www.sudopedia.org/wiki/Terminology
- ALS-XZ: https://www.sudopedia.org/wiki/ALS-XZ

Sudopedia is used especially for:

- Naked and Hidden Subsets
- Pointing and Claiming terminology
- XY-Wing, XYZ-Wing, and W-Wing definitions
- Almost Locked Set terminology
- ALS-XZ and Restricted Common Candidate terminology

### SudokuWiki

SudokuWiki by Andrew Stuart is used as a secondary explanatory source for Almost Locked Sets and related advanced deductions.

- Almost Locked Sets: https://www.sudokuwiki.org/Almost_Locked_Sets

This source is used for:

- the definition of an ALS as N cells containing N+1 candidates
- ALS-XZ explanatory examples
- the relationship between ALS, AIC, and wing patterns

## Method-by-method source mapping

| Solver family | Methods | Primary source |
|---|---|---|
| Singles | Naked Single, Hidden Single | Sudopedia solving-technique taxonomy |
| Locked candidates | Pointing, Claiming | Sudopedia solving-technique taxonomy |
| Subsets | Naked/Hidden Pair, Triple, Quad | Sudopedia solving-technique taxonomy |
| Basic fish | X-Wing, Swordfish, Jellyfish | HoDoKu Basic Fish |
| Finned fish | Finned/Sashimi X-Wing, Swordfish, Jellyfish | HoDoKu Fish General Explanation |
| Single-digit patterns | Skyscraper, Two-String Kite, Empty Rectangle | HoDoKu Single Digit Patterns |
| Wings | XY-Wing, XYZ-Wing, W-Wing | HoDoKu Wings; Sudopedia taxonomy |
| Coloring | Simple Coloring, Multi-Coloring, Remote Pairs | HoDoKu Coloring and Chains |
| Chains | X-Chain, XY-Chain, AIC | HoDoKu Chains and Loops |
| Nice Loops | Continuous Nice Loop, Discontinuous Nice Loop | HoDoKu Chains and Loops |
| Grouped inference | Grouped AIC | HoDoKu Chains and Loops |
| Almost Locked Sets | ALS-XZ, ALS-AIC concepts | Sudopedia ALS-XZ; SudokuWiki ALS; HoDoKu Chains and Loops |
| Fish plus inference | Kraken Fish concept | HoDoKu fish and forcing-chain model |
| Last-resort inference | Forcing Chain, bounded Forcing Net | HoDoKu Chains and Loops |
| Complete search | Backtracking validator and fallback | Chi and Lange, Techniques for Solving Sudoku Puzzles |

## Backtracking and complete validation

The independent validator and complete fallback are based on the standard depth-first backtracking approach with a minimum-remaining-values cell selection heuristic.

A general algorithmic reference is:

- Eric C. Chi and Kenneth Lange, "Techniques for Solving Sudoku Puzzles", 2012: https://arxiv.org/abs/1203.2295

The paper compares backtracking with other general-purpose approaches and reports backtracking as a reliable complete Sudoku solver. The repository implementation does not copy source code from the paper; it independently implements bounded depth-first enumeration in T-SQL.

## Implementation provenance

The repository's T-SQL implementation was written specifically for this project. The cited sources define the logical deductions and established terminology; they are not source-code dependencies.

Implementation-specific decisions include:

- 9-bit candidate masks from 1 through 256
- deterministic action ordering
- one aggregated update per target cell
- restart after every successful action
- bounded generalized inference
- independent solution counting for validation
- SQL Server-oriented CPU, I/O, locking, and TempDB controls

## Attribution and licensing

External pages remain subject to their own copyright and license terms. This repository links to those sources and paraphrases the relevant rules; it does not reproduce their full articles, diagrams, examples, or source code.
