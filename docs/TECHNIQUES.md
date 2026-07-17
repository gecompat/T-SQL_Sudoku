# Technique mapping

The solver reports a concrete technique where the pattern is directly identified. General graph deductions use an engine name when several named patterns are logically equivalent.

| Family | Technique / engine |
|---|---|
| Singles | Naked Single, Hidden Single |
| Locked candidates | Pointing, Claiming |
| Subsets | Naked/Hidden Pair, Triple, Quad |
| Basic fish | X-Wing, Swordfish, Jellyfish |
| Finned fish | Finned/Sashimi X-Wing, Swordfish, Jellyfish |
| Single-digit patterns | Skyscraper, Two-String Kite, Empty Rectangle |
| Wings | XY-Wing, XYZ-Wing, W-Wing |
| Coloring | Simple Coloring, Multi-Coloring, Remote Pairs |
| Chains | X-Chain, XY-Chain, AIC |
| Loops | Continuous Nice Loop, Discontinuous Nice Loop |
| Grouped inference | Grouped AIC |
| ALS | ALS-XZ, ALS-AIC |
| Fish plus inference | Kraken Fish |
| Last resort | Forcing Chain, bounded Forcing Net |
| Search | Backtracking fallback |

## Ordering

The default order favors understandable, low-cost deductions. A generalized technique is intentionally placed after its cheaper named special cases.

## Uniqueness techniques

Unique Rectangles and BUG+1 are not enabled by default because they rely on an assumption that the puzzle has one solution. The independent validator can establish uniqueness, but uniqueness-based eliminations remain outside the default logical path.
