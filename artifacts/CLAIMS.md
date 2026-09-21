# Claim ledger

The ledger tracks the computational and mathematical obligations of the
reconstruction. `T` means the March 2007 diploma thesis; `J` means the 2008
Brinkmann–Leander article; `K` means ePrint 2019/316 on all EA and CCZ classes
through dimension four. Page numbers refer to printed pages unless stated
otherwise. Bibliographic details are in [README.md](README.md).

Statuses:

- **Implemented**: a runnable experiment exists; its scope and checks are
  specified, but recorded validation must be consulted.
- **Reproduced**: the specified computational result has a completed run record
  and the documented checks passed. It does not imply all related theorems or
  larger cases have been reproduced, or that the historical algorithm was used.
  Consult the [algorithm provenance audit](methods/provenance.md); modern
  verification does not discharge historical algorithm reconstruction.
- **Pending**: reproduction work remains; no runnable command is promised.
- **Optional**: an additional investigation, not required to complete the core
  reconstruction or reproduce the classification results.
- **Historical context**: retained to explain the original work, with no
  implementation or verification obligation in the current scope.
- **Discrepancy**: a completed computation differs from a published claim;
  reproducing that claim remains unresolved even if other checks pass.

Entries covering whole sections must be
expanded into individual formulas, tables, and obligations as work reaches
them. It is not yet a complete audit of every statement in either publication.

## Runnable baseline

All four entries below use [the APN-count experiment](methods/apn-counts.md).
Run `make reproduce` from this directory to check all of them. For the readable
reference alone run `make reference`. The expected values and the source
discrepancy are stored in `data/apn-counts.json`.

| ID | Source and precise target | Reproduction command | Status |
| --- | --- | --- | --- |
| APN-001 | T Example 4.2 / J Table 4: all four functions in dimension 1 are APN; two are permutations. | `sage sage/apn_counts.sage --max-dimension 1 --cython` | Reproduced |
| APN-002 | T Example 4.4 / J Table 4: 192 APN functions in dimension 2; none is a permutation. | Same script with `--max-dimension 2 --cython` | Reproduced |
| APN-003 | T Example 4.7 / J Table 4: determine the dimension-three total (thesis: 668128; article: 688128) and reproduce 10752 APN permutations. | `make reproduce` | Reproduced: 688128; thesis numeral disagrees |
| APN-004 | T Definition 4.1, Theorem 4.3, Algorithm 4, Appendix A.2: finite validation of the APN predicates and incremental search, including rollback. | `make reproduce` | Reproduced for the documented finite range, not a proof of the general theorem |

The complete comparison checks every accepted table against both Cython methods;
the unpruned Cython method visits every complete function, including all 8^8 in
dimension three. Expected evidence is a completed JSON record with source
hashes, versions, counts, output hashes, and matching search profiles.
The [completed baseline record](results/apn-counts.json) contains all four
entries' evidence. It was produced with SageMath 10.6 and Cython 3.0.11 on
arm64 macOS. Migration from the earlier standalone C implementation preserved
all output hashes, counts, and incremental search profiles.

## Affine geometry and refinement

| ID | Source / target | Reproduction command | Status |
| --- | --- | --- | --- |
| PLANES-001 | T Propositions 3.1, 3.2, 3.7; Lemma 3.5; Example 3.3 / J §8 equations (20)–(21): plane sets, total count, hyperplane decomposition, prefix recurrences. | `make planes`; [method](methods/affine-planes.md), [record](results/affine-planes.json) | Reproduced through n=5, with general derivations documented |
| PLANES-003 | Finite verification of T Theorem 3.13, plus Example 3.12: extrema over all input subsets through n=4. | `make planes`; same method and record | Reproduced for the specified finite range; general saturation proof remains PLANES-002 |
| AFFINE-003 | T §4.2.1, Algorithms 5–6: affine refinement and completion, with optional injectivity. | `make refinement`; [method](methods/affine-refinement.md), [record](results/affine-refinement.json) | Reconstructed; every affine-template transition checked through n=2, every affine map reconstructed from two bases through n=3 |

## Remaining thesis work

Rows with a `make` command have runnable experiments. Other procedure entries
describe planned work. Some rows have completed portions, with remaining
obligations stated explicitly. Cython is optional support for larger computations.

| ID | Source / claim family | Planned reproduction procedure | Status |
| --- | --- | --- | --- |
| BACKTRACK-001 | T Chapter 2: refinement, filter, canonicity, weak-filter and efficiency framework. | Write explicit invariants and proof notes; use finite toy problems to check traversal and weak-filter semantics. Separate theorem proofs from examples. | Pending |
| PLANES-002 | T §3.4, Theorem 3.13 / J §8: extremal bound for arbitrary input subsets. | Reconstruct the saturation and shuffle/sink proof; finite verification is recorded separately as PLANES-003. | General proof reconstruction pending |
| SEARCH-001 | T §4.1.3, Proposition 4.8 / J §3 and §8: exact affine-plane conflict opportunities. | Use the reproduced A(k) and Delta(k) counts; connect the extremal theorem to left-refinement. | Exact prefix counts reproduced under PLANES-001; general extremal proof remains PLANES-002 |
| AFFINE-001 | T §4.2.2: affine canonicity algorithms. | `make canonicity`; [method](methods/affine-canonicity.md), [record](results/affine-canonicity.json). | Reconstructed; all prefixes verified against full affine actions through n=2; full-map oracle checks n=4 survivors |
| AFFINE-002 | T Theorem 4.17, Tables 4.1–4.2 / J Theorem 3, Table 1: APN permutation classification. | `make canonicity` for n=3,4; `make permutations5` / `make verify-permutations5-direct` for direct n=5 search; `make permutations5-from-ea` / `make verify-permutations5` for the EA-based route; [method](methods/apn-permutations-five.md), [record](results/apn-permutations-from-ea-5.json). | Reproduced: one affine class in n=3, none in n=4, five exact published affine minima in n=5. All 67 permutation-producing linear corrections of the seven EA representatives have checked affine witnesses; degrees, five power identifications and inverse relationships verified. Coverage uses completed EA-002, with exact full affine canonicity tests. This reapplies the linear-addition technique the author recalls using in 2019 to the earlier result; the direct historical-style permutation-tree search has also completed independently at cutoffs 14 and 16, returning the same five minima with ten checked power/inverse witnesses per run ([direct record](results/apn-permutations-5-cutoff16.json)) |
| EA-001 | T §4.2.4–4.2.5 / J §4: EA normalization and weak-filter candidates. | `make canonicity` for n=4; `make candidates5` for the compiled n=5 experiment, [method](methods/ea-candidates.md). Publications report 16 and 11768. | n=4 discrepancy: reconstructed filter gives 15. n=5 reproduced: completed search returns exactly 11,768; [record](results/ea-candidates-5.json) |
| EA-002 | T Theorem 4.20, Tables 4.3–4.5 / J Theorem 5, Tables 2–3: complete EA classification. | `make canonicity` for n=4; `make reduce5 WORKERS=8` and `make verify-reduction5` for n=5. | n=4 class count and exact representatives reproduced. n=5 complete: all 11,768 candidates reduce to the seven exact published representatives, with checked witnesses, 21 completed exact negative tests, and the global-minimum coverage argument; [method](methods/ea-reduction.md), [record](results/ea-reduction-5.json). Power and trace-family correspondences are reproduced separately under POWER-004, POWER-005 and FAMILY-001 |
| CCZ-001 | T §4.3.1: abandoned direct graph-based CCZ equivalence algorithm and its self-equivalence pruning. | Record the historical transition to Dillon's code-equivalence reduction and Magma. No direct-search reimplementation or small-case runs are required. | Historical context; removed from reconstruction scope by the author on 2026-09-20. Code-based classification remains CCZ-002; EA stabilizer reconstruction remains EA-GROUP-001 |
| CCZ-002 | T §4.3.2 / J §5: Walsh spectra and CCZ classification. | `sage -python sage/ccz_stabilizers.sage --output build/ccz-stabilizers.json`; [method](methods/ccz-stabilizers.md), [record](results/ccz-stabilizers.json); spectra under WALSH-005. | Reproduced: one class for n=4 inputs, three classes {1,3,7}, {2,4,6}, {5} for the seven supplied n=5 inputs, with checked affine graph witnesses and exact negative cases. Full n=5 coverage now follows from the completed EA-002 reduction |
| CCZ-STANDARD-001 | Standard code-equivalence route: distinguish supplied n=5 representatives 1 and 2, which have equal Walsh spectra. | `sage -python sage/ccz_standard_pair.sage --cpu-limit 300 --output build/ccz-standard-pair-300s.json`; [record](results/ccz-standard-pair.json). | Completed: Sage 10.6 `is_permutation_equivalent` returns False in 83.140 CPU seconds. No graph canonicalization; the earlier 20-second probe was insufficient to assess this route. This record covers the one pair, not the full candidate classification |
| GROUP-001 | T Example 4.24 / J Note 9: published self-equivalences and induced canonicity filter. | `make historical-stabilizers`; `make verify-historical-stabilizers`; [method](methods/historical-stabilizers.md), [record](results/historical-stabilizers.json) | Reproduced: the exact three printed generators are rediscovered in order, lifted to checked EA maps, and give precisely the three stated orbit rules. Pruning is checked against finite full group actions and positive/negative EA tests; the abandoned direct CCZ search remains out of scope |
| ENGINEERING-001 | T Appendix A and historical performance observations. | Document packed state, rollback, propagation, filter ordering, specialization, and cache behavior; report current work counts and measured runtimes without claiming identical historical timings. | Pending |
| SCHEDULE-001 | Thesis §4.2.3, p. 37, and author request: defer affine checks at deep partial templates, restoring them at complete functions. | `sage sage/ea_candidates.sage --dimension 4 --cutoff 11 --output build/ea-candidates-4-propagation.json`; [method](methods/ea-candidates.md), [current record](results/ea-candidates-4-propagation.json), [earlier prefix-only record](results/ea-candidates-4-cutoff11.json). | Implemented: inclusive cutoff on known-entry count after propagation. Final candidate sets verified invariant through n=4; historical cutoff convention differs by one and original run configurations remain unrecovered |
| PROPAGATION-001 | Author recollection (2026-09-19), APN affine-plane criterion: per-position exclusion masks, singleton assignments beyond the current prefix, and sparse affine filtering. | `sage sage/ea_candidates.sage --dimension 4 --cutoff 11 --output build/ea-candidates-4-propagation.json`; [method](methods/apn-propagation.md), [record](results/ea-candidates-4-propagation.json). | Reconstructed: independent closure/mask checks, exhaustive sparse templates through n=2, sampled n=3,5 templates, complete candidate-list and cutoff comparisons through n=4. Original construction source remains missing |

## Dimension-five published inputs

| ID | Source / target | Reproduction command | Status |
| --- | --- | --- | --- |
| INPUTS-005 | T Table 4.5 / J Table 3: seven supplied n=5 tables, APN property, zero normalization, and degrees. | `sage -python sage/dimension_five_inputs.sage --output build/dimension-five-inputs.json`; [data](data/dimension-five.json), [method](methods/dimension-five.md), [record](results/dimension-five-inputs.json). | Reproduced for supplied inputs only; EA/CCZ classification and canonicity remain EA-002 and CCZ-002 |
| WALSH-005 | J §5, p. 280: absolute Walsh multiplicities of those seven tables. | Same input-check command, with independent direct and fast transforms. | Printed multiplicities reproduced when b=0 is included; printed definition excludes b=0. Both conventions recorded; source convention discrepancy remains explicit |

## Field-function identifications

| ID | Source / target | Reproduction command | Status |
| --- | --- | --- | --- |
| POWER-004 | T Theorem 4.20, Table 4.4 / J Theorem 5, Table 2: exactly one n=4 EA class contains power functions; row 1 corresponds to x^3. | `make powers`; `make verify-powers`; [method](methods/power-correspondences.md), [record](results/power-correspondences.json) | Reproduced: all positive exponent residues checked, all four APN powers assigned to row 1 with explicit witnesses. The separate n=4 inequivalence result excludes row 2 |
| POWER-005 | T Theorem 4.20, Table 4.5 / J Theorem 5, Table 3: exactly five n=5 EA classes contain powers, with the printed correspondences. | Same commands, method and record | Reproduced: all 31 positive exponent residues checked, all 25 APN powers assigned to rows 1,2,5,6,7. The completed EA-002 negative tests exclude rows 3,4 |
| FAMILY-001 | T discussion following Theorem 4.20 / J equations (5)–(6), printed p. 279: the three nonpower EA classes contain the stated trace-family instances. | Same commands, method and record | Reproduced for these finite instances: n=4 i=1 maps to row 2; n=5 i=1,2 map to rows 4,3. General infinite-family theorems are not established by this check |

## Optional investigations

These do not block the core reconstruction. The author explicitly made the
conflict model, empirical measurements, and plot optional on 2026-09-19.
The independence model is a heuristic whose formula follows conditionally
from its assumptions; agreement with actual search behavior is an empirical
question, not an unconditional theorem to prove.

| ID | Source / target | Possible procedure | Status |
| --- | --- | --- | --- |
| SEARCH-002 | T Proposition 4.11, Corollary 4.12, Note 4.13 and Figure 4.2 / J Proposition 2, Figure 1 and associated complexity discussion: modeled and measured conflicts. | Document the independence model; reconstruct the Knuth sampling measurements (confirmed by the author on 2026-09-20), recovering their detailed configuration and aggregation; compare the measured curve with predicted forbidden-value counts. Distinguish prefix-only and propagated searches. | Optional; exact opportunity counts are tracked separately as SEARCH-001 |

## Article extensions

| ID | Source / target | Planned reproduction procedure | Status |
| --- | --- | --- | --- |
| EA-GROUP-001 | J §6, Lemma 7, Corollary 8, Algorithm 3: EA action and stabilizer computation. | `make historical-stabilizers`; `make verify-historical-stabilizers`; [recursive method](methods/historical-stabilizers.md), [search record](results/historical-stabilizers.json), [certificate replay](results/historical-stabilizers-verification.json) | Reconstructed and reproduced for all nine n=4,5 inputs: canonical generator sequences, selected-generator orbit pruning, checked EA lifts, and final exhausted searches. Actual groups equal the independent modern groups. Incumbent ordering and optional forced-equation propagation are documented implementation choices; the original complete driver remains unlocated |
| EA-CODE-001 | Modern verification, separate from the historical algorithm: EA stabilizer via Aut(C_s) intersect AGL(n,2), assuming rank(M_s)=2n+1. | [Lemma and proof](methods/ccz-stabilizers.md#lemma-ea-stabilizers-as-an-intersection-of-permutation-groups); literature basis: Bracken–Byrne–McGuire–Nebe (2011), §2, Theorem 1 and Lemma 1. | Full-rank bijection and group convention proved; hypotheses checked for all supplied n=4,5 representatives. Not attributed to the 2007 implementation; the separately reconstructed historical Algorithm 3 is EA-GROUP-001 |
| EA-GROUP-002 | J §6: stabilizer orders 5760,384 in n=4 and 4960,4960,160,160,155,155,155 in n=5. | `sage -python sage/ccz_stabilizers.sage --output build/ccz-stabilizers.json`; [record](results/ccz-stabilizers.json). | Reproduced for all nine supplied representatives; full code groups agree between Miller and Bliss, exact EA intersection orders and generator witnesses verified. The independent recursive reconstruction now returns the same groups and orders under EA-GROUP-001 |
| TOTAL-001 | J Table 4: APN totals in n=4,5. | Combine complete EA coverage with [computed stabilizers and orbit sizes](methods/ccz-stabilizers.md), [record](results/ccz-stabilizers.json). | n=4 total 18940805775360 reproduced using the completed two-class classification. n=5 total 110823678910407691468800 reproduced by combining the completed EA-002 coverage with the verified seven stabilizers and orbit sizes. The [historical replay](results/historical-stabilizers-verification.json) independently derives the same orbit totals from the backtracking-generated groups |
| DIM6-001 | J §7, Table 5: fourteen dimension-six representatives and their invariants/equivalences. | Transcribe inputs with source checks; verify APN, degrees, Gamma-ranks, code automorphism information and historical CCZ relationships. Assess canonicity claims separately from inequivalence. | Pending; no exhaustive dimension-six classification is claimed |

## All functions through dimension four (ePrint 2019/316)

These entries are independent verification of the published catalogue, not a
recovery of the original all-functions enumeration driver. The exact global EA
minimum checks and orbit-size sum establish completeness without re-enumerating
all 16^16 functions. See [the method and proofs](methods/ea-ccz-catalogue-2019.md).

| ID | Source / target | Reproduction command | Status |
| --- | --- | --- | --- |
| CATALOGUE-001 | K tables for n=1..4: 1,2,7,4713 global EA minima and all class sizes. | `make catalogue2019`; [record](results/ea-ccz-catalogue-2019.json) | Reproduced: exhaustive affine-input minimization, all stabilizer orders including rank-deficient cases, disjoint EA orbits summing to 4,256,16777216,18446744073709551616. All 71 dimension-four orbit sizes reproduced |
| CATALOGUE-002 | K tables: all degrees and extended Walsh spectra, 481 distinct n=4 spectra. | Same experiment; `make verify-catalogue2019` replays properties | Reproduced with two independent degree and Walsh calculations. The affine class has reported degree 1 by convention; b=0 is removed from uploaded raw spectra to match the printed tables |
| CATALOGUE-003 | K tables: which EA classes contain permutations, including 194 in n=4. | Same experiment and replay | Reproduced by exact linear-correction searches, following the approach in the saved 194 witnesses and the author's recollection of using linear addition in 2019 (clarified 20 September 2026). All 200 positive witnesses through n=4 retained; negative cases exhaust the collision-pruned search |
| CATALOGUE-004 | K tables: 1,2,7,4151 CCZ classes and all EA-to-CCZ assignments. | Same experiment and replay | Reproduced via the documented modern code/Bliss backend, with 562 checked affine graph witnesses and exact negative canonical-code comparisons. Complete EA coverage establishes global CCZ minima |
| CATALOGUE-HIST-001 | Surviving Magma source, inputs and 2008 output supporting K. | `python3 sage/audit_historical_magma.py --output build/historical-magma-data-audit.json`; [original files](historic/magma/README.md), [audit](results/historical-magma-data-audit.json) | Archived 4,713 dimension-four inputs, 4,713 assignments and 4,151 canonical rows agree exactly with the publication. The log reports Magma V2.11-2, 16 March 2008, 33723.769 seconds and 43.28 MB. No fresh Magma run; hardware unspecified. n=1 source includes an additional identity table in the same EA class |

## Active reconstruction order

Parallel implementation and scheduling work are deferred at the author's
request on 2026-09-20. The independent APN Lab confirmation is separate from
this artifact and is not needed to discharge its claims. The completed
single-CPU dimension-five search and its retained outputs remain the
construction evidence here.

Algorithm 3 and Note 9 are now reconstructed under EA-GROUP-001 and
GROUP-001. The original complete driver remains missing; the new implementation
and its documented adaptations are not presented as recovered source.

AFFINE-002 is complete by two routes: the correction search over the seven
exhaustive EA classes, and the separate direct permutation search. Direct runs
at cutoffs 14 and 16 have both completed; their records, progress logs and
certificate replays were preserved on 21 September 2026. Both return the same
five published affine minima without relying on EA enumeration. CATALOGUE-001
through CATALOGUE-004 complete the finite computational tables of the additional
2019 paper.

At the author's request, the following remain **open and deferred**:

- BACKTRACK-001 / PLANES-002 / ENGINEERING-001: general proof notes and the
  implementation retrospective.
- DIM6-001: the article's finite dimension-six examples and their invariants.
  No exhaustive dimension-six classification is claimed.

Historical intermediate-count discrepancies remain explicit; unavailable
original candidate lists cannot be replaced by an inferred explanation.
The optional conflict-model and sampling work remains optional.

## Discrepancies and completion rules

- APN-003: the thesis numeral 668128 was visually confirmed at PDF page 39;
  article Table 4 gives 688128. Report the computed count alongside the source
  discrepancy. Do not silently replace the thesis text or infer a cause.
- EA-001: n=4 produces 15 weak candidates versus 16 in both publications.
  All computed candidates pass independent complete affine canonicity checks
  and reduce to the two published EA representatives. The exact historical
  intermediate stage remains unresolved; no cause is inferred.
- WALSH-005: the printed spectrum definition excludes b=0, while the printed
  multiplicities include its 31 zeros and one coefficient of magnitude 32.
  Both conventions reproduce the same partition; report the discrepancy.
- CATALOGUE-004: the 2019 methodology reverses the implication in one sentence.
  EA implies CCZ; the verified grouping and completeness argument use this
  direction, consistent with the introduction.
- A positive equivalence result requires a checked witness. A negative result
  requires an exact test to finish; a timeout is inconclusive.
- Class representatives and pairwise inequivalence do not establish search
  completeness. Record the coverage argument and completed enumeration.
- A proof, an exhaustive finite check, a sampled check, and a heuristic estimate
  are different forms of evidence. Label which one an entry supplies.
- Compiled acceleration must be reachable through a documented Sage experiment, with
  readable reference behavior available on feasible instances.
- Historical backup checks belong in the private recovery inventory until
  reconstituted as maintained artifacts with reproducible commands.
