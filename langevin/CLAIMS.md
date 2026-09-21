# Claim ledger: Langevin's dimension-five experiment

Source: Philippe Langevin, [Classification of APN mappings in dimension 5 over
GF(2)](https://langevin.univ-tln.fr/project/apn-5/apn-5.html), computation July
2011, webpage last modified 29 March 2012. The two linked input datasets are
preserved in `data/`, with source URLs in [expected.json](data/expected.json).

This ledger belongs to an independent project. It does not change the historical
Brinkmann–Leander reproduction in `../artifacts/`. “Reproduced” below means a
completed new computation with the stated checks, not recovery of Langevin's
original executable or loop organization. The [method notes](methods/component-covering.md)
give the coverage proof, corrected threshold and implementation differences.

## Completed computation

Run `make reproduce` to reconstruct all five levels; `make verify` replays the
retained evidence with the limitations below.

| ID | Claim | Evidence | Status |
| --- | --- | --- | --- |
| L-SEEDS-001 | 48 Boolean classes modulo RM(1,5) cover all possible starting components | [Level 1](results/level1.json): distinct marked-code canonical forms, computed stabilizers, orbit sizes summing to 67,108,864 | Reproduced; input completeness independently checked |
| L-SEEDS-002 | The character criterion selects the six linked functions and their stated stabilizers act on extensions | Same record; supplied generators checked on the functions modulo affine addition, and generated orders checked against exact stabilizers | Reproduced |
| L-SIGN-001 | Correct the sign of the printed extension bound | [Derivation](methods/component-covering.md#unresolved-affine-planes-and-the-extension-inequality); level-one record | Corrected: the right-hand side is negative. Negative threshold selects six Boolean classes; the printed positive threshold selects 26 |
| L-LEVEL2-001 | 3,628 extensions modulo seed stabilizers; 3,537 after the trivial-obstruction step; 1,782 CCZ classes | [Level 2](results/level2.json) | Reproduced exactly; the implemented obstruction is derivative-bin capacity |
| L-LEVEL3-001 | 3,437,013 extensions; 1,071,994 after obstruction; 288 extendable maps; seven CCZ classes | [Level 3](results/level3.json) | Reproduced exactly; negative two-component searches exhausted, positive completions retained |
| L-LEVEL4-001 | 75 extensions; 42 after obstruction; four CCZ classes | [Level 4](results/level4.json) | Reproduced exactly |
| L-LEVEL5-001 | Five completions and three CCZ classes | [Level 5](results/level5.json) | Reproduced exactly by last-component linear systems and code equivalence |
| L-COVERAGE-001 | Every APN CCZ class in dimension five is represented | [Coverage argument](methods/component-covering.md#reducing-extensions-and-the-covering-argument), Boolean orbit mass, and all completed stage enumerations | Established by the stated mathematical argument and completed finite computations; no earlier APN search supplies candidates |
| L-CHECKS-001 | Optimized extension and completion routines agree with independent finite checks | `make check`; [record](results/algorithm-checks.json) | Passed: 20 extension cases, 33 two-component cases, 139 final-component cases, 20 code-invariance cases; tiny two-component cases also exhaust all pairs of quotient words |
| L-REPLAY-001 | Saved positive witnesses and stage counts verify independently of the long search | `make verify`; [record](results/verification.json) | Passed: 3,872 code-equivalence certificates and 288 full APN completion witnesses; all stage representative codes distinct |
| L-COMPARISON-001 | The independently constructed classes match the earlier published dimension-five inputs | `sage -python sage/verify.sage --records results --compare-artifacts`; same replay record | Passed: the seven published EA rows partition as {1,3,7}, {2,4,6}, {5}. This is a final comparison, not an enumeration dependency |

## Runtime and scope

The completed run on 21 September 2026 used Sage 10.6, Python 3.12.5 and macOS
arm64. It took **626.38 seconds** inside the driver after kernel loading; level
three accounted for **620.85 seconds**. The timing is elapsed time, not a CPU
benchmark. [The progress log](results/reproduction.log) records every completed
level-three parent and the final totals. The two-component solver visited
306,916,700 recursive nodes in aggregate.

All result records retain source hashes. The new completion solver uses
constraint propagation and color symmetry, rather than Langevin's dancing-links
implementation; the code-equivalence backend uses Sage/Bliss. The exact original
seven-program pipeline has not been recovered. Matching its intermediate counts
does not make these implementation choices historical source recovery.

Replay recomputes the Boolean orbit partition, checks all retained positive code
and APN witnesses, verifies representative-code distinctness and recorded counts,
and repeats the final-component linear systems. It **does not repeat** the large
Walsh extension enumerations or negative two-component searches. Those are
reproduced by `make reproduce`, with finite implementation checks under `make check`.

This experiment classifies dimension five only. It makes no claim of exhaustive
dimension-six classification or performance scaling to larger dimensions.
