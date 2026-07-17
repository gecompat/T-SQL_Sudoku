# Test matrix

This matrix defines the required tests before a release can be marked validated. Test data must remain synthetic and generic.

## Core API tests

| Test | Expected result |
|---|---|
| Valid 81-character puzzle | Accepted |
| Null puzzle | Argument error |
| Puzzle shorter or longer than 81 characters | Argument error |
| Non-digit character | Argument error |
| Already solved valid board | `SolvedLogically` or equivalent complete status |
| Duplicate digit in a row | `Invalid` |
| Duplicate digit in a column | `Invalid` |
| Duplicate digit in a box | `Invalid` |
| Puzzle with no completion | Validator returns zero solutions |
| Puzzle with one completion | Validator returns one solution |
| Puzzle with multiple completions | Validator reaches `@MaxSolutions` |
| `@SingleStep = 1` | At most one logical action |
| `@AllowBacktracking = 0` | Stalled board remains partial |
| Very small `@MaxRuntimeMs` | Timeout status without invalid state |
| Very small `@MaxIterations` | Iteration-limit status without invalid state |

## Technique test pattern

Every directly detected method requires at least:

1. a positive test that forces the intended action;
2. a boundary test using the smallest valid pattern;
3. a negative look-alike that must not change the board;
4. a regression test for every defect found later.

## Required direct-method cases

| Technique | Positive | Boundary | Negative | Regression |
|---|---:|---:|---:|---:|
| Naked Single | Required | Required | Required | As needed |
| Hidden Single | Required | Required | Required | As needed |
| Pointing | Required | Required | Required | As needed |
| Claiming | Required | Required | Required | As needed |
| Naked Pair | Required | Required | Required | As needed |
| Hidden Pair | Required | Required | Required | As needed |
| Naked Triple | Required | Required | Required | As needed |
| Naked Quad | Required | Required | Required | As needed |
| X-Wing | Required | Required | Required | As needed |
| Swordfish | Required | Required | Required | As needed |
| Jellyfish | Required | Required | Required | As needed |
| XY-Wing | Required | Required | Required | As needed |
| XYZ-Wing | Required | Required | Required | As needed |

## Generalized-proof tests

For every method currently covered by generalized contradiction proof:

- a candidate that is impossible in every completion must be removed;
- a candidate that appears in at least one completion must not be removed;
- the proof stage must respect `@MaxForcingChecks`;
- truncated or bounded searches must not claim uniqueness;
- the solution-path entry must identify the action as generalized rather than pretending that a geometric pattern was reconstructed.

## X-Wing negative cases

- one base row has three candidate positions;
- the two base rows use different cover columns;
- the target is inside a base row;
- the target cell does not contain the fish digit;
- only one base row exists.

## Installation tests

1. install on an empty database;
2. run installation a second time;
3. verify helper-table row counts;
4. verify every position has exactly twenty peers;
5. execute smoke and validator tests;
6. uninstall;
7. reinstall after uninstall.
