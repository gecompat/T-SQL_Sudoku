# Technique mapping

The solver reports a concrete technique when the pattern is detected directly. Advanced deductions use `Generalized Advanced Inference` or `Generalized Forcing Net` when the same elimination is proven by an exhaustive candidate-premise contradiction instead of reconstructed as a geometric pattern.

The full bibliography and provenance notes are maintained in [SOURCES.md](SOURCES.md).

| Family | Technique / engine | Principal reference |
|---|---|---|
| Singles | Naked Single, Hidden Single | Sudopedia solving-technique taxonomy |
| Locked candidates | Pointing, Claiming | Sudopedia solving-technique taxonomy |
| Subsets | Naked Pair, Triple, Quad; hidden subsets through generalized inference | Sudopedia solving-technique taxonomy |
| Basic fish | X-Wing, Swordfish, Jellyfish | HoDoKu Basic Fish |
| Finned fish | Finned/Sashimi X-Wing, Swordfish, Jellyfish through generalized inference | HoDoKu Fish General Explanation |
| Single-digit patterns | Skyscraper, Two-String Kite, Empty Rectangle through generalized inference | HoDoKu Single Digit Patterns |
| Wings | XY-Wing, XYZ-Wing, W-Wing through generalized inference | HoDoKu Wings; Sudopedia taxonomy |
| Coloring | Simple Coloring, Multi-Coloring, Remote Pairs through generalized inference | HoDoKu Coloring and Chains |
| Chains | X-Chain, XY-Chain, AIC through generalized inference | HoDoKu Chains and Loops |
| Loops | Continuous Nice Loop, Discontinuous Nice Loop through generalized inference | HoDoKu Chains and Loops |
| Grouped inference | Grouped AIC through generalized inference | HoDoKu Chains and Loops |
| ALS | ALS-XZ, ALS-AIC through generalized inference | Sudopedia ALS-XZ; SudokuWiki ALS; HoDoKu Chains and Loops |
| Fish plus inference | Kraken Fish through generalized inference | HoDoKu fish and forcing-chain model |
| Last resort | Forcing Chain, bounded Forcing Net | HoDoKu Chains and Loops |
| Search | Independent backtracking fallback | Chi and Lange, Techniques for Solving Sudoku Puzzles |

## Ordering

The default order favors understandable, low-cost deductions. The generalized premise checks are intentionally placed after explicit Singles, Locked Candidates, Naked Subsets, and Basic Fish.

## Meaning of generalized coverage

A candidate-true premise is sent to the independent validator. If no valid completion exists, that candidate is false. This conclusion is at least as strong as any named logical technique that would remove the same candidate.

The tradeoff is explanatory: the solver proves the result but does not always identify the shortest named pattern that explains it.

## Method provenance versus implementation provenance

The cited references define the established Sudoku rules and terminology. The repository's T-SQL code, candidate-mask representation, deterministic ordering, aggregated updates, validation workflow, and SQL Server performance controls were implemented specifically for this project.

No external Sudoku solver source code is copied or linked as a runtime dependency.

## Uniqueness techniques

Unique Rectangles and BUG+1 are not enabled as separate named methods because they rely on a uniqueness assumption. The generalized proof remains valid without assuming uniqueness.