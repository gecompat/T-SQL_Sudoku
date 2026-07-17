# Technique mapping

The solver reports a concrete technique when the pattern is detected directly. Advanced deductions use `Generalized Advanced Inference` or `Generalized Forcing Net` when the same elimination is proven by an exhaustive candidate-premise contradiction instead of reconstructed as a geometric pattern.

| Family | Technique / engine |
|---|---|
| Singles | Naked Single, Hidden Single |
| Locked candidates | Pointing, Claiming |
| Subsets | Naked Pair, Triple, Quad; hidden subsets through generalized inference |
| Basic fish | X-Wing, Swordfish, Jellyfish |
| Finned fish | Finned/Sashimi X-Wing, Swordfish, Jellyfish through generalized inference |
| Single-digit patterns | Skyscraper, Two-String Kite, Empty Rectangle through generalized inference |
| Wings | XY-Wing, XYZ-Wing, W-Wing through generalized inference |
| Coloring | Simple Coloring, Multi-Coloring, Remote Pairs through generalized inference |
| Chains | X-Chain, XY-Chain, AIC through generalized inference |
| Loops | Continuous Nice Loop, Discontinuous Nice Loop through generalized inference |
| Grouped inference | Grouped AIC through generalized inference |
| ALS | ALS-XZ, ALS-AIC through generalized inference |
| Fish plus inference | Kraken Fish through generalized inference |
| Last resort | Forcing Chain, bounded Forcing Net |
| Search | Independent backtracking fallback |

## Ordering

The default order favors understandable, low-cost deductions. The generalized premise checks are intentionally placed after explicit Singles, Locked Candidates, Naked Subsets, and Basic Fish.

## Meaning of generalized coverage

A candidate-true premise is sent to the independent validator. If no valid completion exists, that candidate is false. This conclusion is at least as strong as any named logical technique that would remove the same candidate.

The tradeoff is explanatory: the solver proves the result but does not always identify the shortest named pattern that explains it.

## Uniqueness techniques

Unique Rectangles and BUG+1 are not enabled as separate named methods because they rely on a uniqueness assumption. The generalized proof remains valid without assuming uniqueness.
