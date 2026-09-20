# Claim ledger

The ledger tracks the computational and mathematical obligations of the
reconstruction. `T` means the March 2007 diploma thesis; `J` means the 2008
Brinkmann–Leander article. Page numbers refer to printed pages unless stated
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

This is the initial claim ledger. Entries covering whole sections must be
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
| AFFINE-002 | T Theorem 4.17, Tables 4.1–4.2 / J Theorem 3, Table 1: APN permutation classification. | `make canonicity` for n=3,4; same method and record. | Reproduced: one affine class in n=3, none in n=4. Five n=5 classes remain pending |
| EA-001 | T §4.2.4–4.2.5 / J §4: EA normalization and weak-filter candidates. | `make canonicity` for n=4; `make candidates5` for the compiled n=5 experiment, [method](methods/ea-candidates.md). Publications report 16 and 11768. | n=4 discrepancy: reconstructed filter gives 15. n=5 reproduced: completed search returns exactly 11,768; [record](results/ea-candidates-5.json) |
| EA-002 | T Theorem 4.20, Tables 4.3–4.5 / J Theorem 5, Tables 2–3: complete EA classification. | `make canonicity` for n=4; `make reduce5 WORKERS=8` and `make verify-reduction5` for n=5. | n=4 class count and exact representatives reproduced. n=5 complete: all 11,768 candidates reduce to the seven exact published representatives, with checked witnesses, 21 completed exact negative tests, and the global-minimum coverage argument; [method](methods/ea-reduction.md), [record](results/ea-reduction-5.json). Power-function correspondences remain pending |
| CCZ-001 | T §4.3.1: abandoned direct graph-based CCZ equivalence algorithm and its self-equivalence pruning. | Record the historical transition to Dillon's code-equivalence reduction and Magma. No direct-search reimplementation or small-case runs are required. | Historical context; removed from reconstruction scope by the author on 2026-09-20. Code-based classification remains CCZ-002; EA stabilizer reconstruction remains EA-GROUP-001 |
| CCZ-002 | T §4.3.2 / J §5: Walsh spectra and CCZ classification. | `sage -python sage/ccz_stabilizers.sage --output build/ccz-stabilizers.json`; [method](methods/ccz-stabilizers.md), [record](results/ccz-stabilizers.json); spectra under WALSH-005. | Reproduced: one class for n=4 inputs, three classes {1,3,7}, {2,4,6}, {5} for the seven supplied n=5 inputs, with checked affine graph witnesses and exact negative cases. Full n=5 coverage now follows from the completed EA-002 reduction |
| CCZ-STANDARD-001 | Standard code-equivalence route: distinguish supplied n=5 representatives 1 and 2, which have equal Walsh spectra. | `sage -python sage/ccz_standard_pair.sage --cpu-limit 300 --output build/ccz-standard-pair-300s.json`; [record](results/ccz-standard-pair.json). | Completed: Sage 10.6 `is_permutation_equivalent` returns False in 83.140 CPU seconds. No graph canonicalization; the earlier 20-second probe was insufficient to assess this route. This record covers the one pair, not the full candidate classification |
| GROUP-001 | T Example 4.24 / J Note 9: published self-equivalences and induced canonicity filter. | Lift published permutations to valid transformations; compute subgroup orders and validate the resulting pruning on small instances. Distinguish EA and CCZ stabilizers. | Pending; exploratory subgroup check exists outside the maintained artifact |
| ENGINEERING-001 | T Appendix A and historical performance observations. | Document packed state, rollback, propagation, filter ordering, specialization, and cache behavior; report current work counts and measured runtimes without claiming identical historical timings. | Pending |
| SCHEDULE-001 | Thesis §4.2.3, p. 37, and author request: defer affine checks at deep partial templates, restoring them at complete functions. | `sage sage/ea_candidates.sage --dimension 4 --cutoff 11 --output build/ea-candidates-4-propagation.json`; [method](methods/ea-candidates.md), [current record](results/ea-candidates-4-propagation.json), [earlier prefix-only record](results/ea-candidates-4-cutoff11.json). | Implemented: inclusive cutoff on known-entry count after propagation. Final candidate sets verified invariant through n=4; historical cutoff convention differs by one and original run configurations remain unrecovered |
| PROPAGATION-001 | Author recollection (2026-09-19), APN affine-plane criterion: per-position exclusion masks, singleton assignments beyond the current prefix, and sparse affine filtering. | `sage sage/ea_candidates.sage --dimension 4 --cutoff 11 --output build/ea-candidates-4-propagation.json`; [method](methods/apn-propagation.md), [record](results/ea-candidates-4-propagation.json). | Reconstructed: independent closure/mask checks, exhaustive sparse templates through n=2, sampled n=3,5 templates, complete candidate-list and cutoff comparisons through n=4. Original construction source remains missing |

## Dimension-five published inputs

| ID | Source / target | Reproduction command | Status |
| --- | --- | --- | --- |
| INPUTS-005 | T Table 4.5 / J Table 3: seven supplied n=5 tables, APN property, zero normalization, and degrees. | `sage -python sage/dimension_five_inputs.sage --output build/dimension-five-inputs.json`; [data](data/dimension-five.json), [method](methods/dimension-five.md), [record](results/dimension-five-inputs.json). | Reproduced for supplied inputs only; EA/CCZ classification and canonicity remain EA-002 and CCZ-002 |
| WALSH-005 | J §5, p. 280: absolute Walsh multiplicities of those seven tables. | Same input-check command, with independent direct and fast transforms. | Printed multiplicities reproduced when b=0 is included; printed definition excludes b=0. Both conventions recorded; source convention discrepancy remains explicit |

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
| EA-GROUP-001 | J §6, Lemma 7, Corollary 8, Algorithm 3: EA action and stabilizer computation. | [Sage group experiment](methods/ccz-stabilizers.md): full code automorphism group intersected with affine input permutations; checked EA lifts and independent group computations. | Action/order formulas and unique-lift argument documented; modern full-stabilizer computation reproduced. Historical Algorithm 3's canonical generator search remains pending |
| EA-CODE-001 | Modern verification, separate from the historical algorithm: EA stabilizer via Aut(C_s) intersect AGL(n,2), assuming rank(M_s)=2n+1. | [Lemma and proof](methods/ccz-stabilizers.md#lemma-ea-stabilizers-as-an-intersection-of-permutation-groups); literature basis: Bracken–Byrne–McGuire–Nebe (2011), §2, Theorem 1 and Lemma 1. | Full-rank bijection and group convention proved; hypotheses checked for all supplied n=4,5 representatives. Not attributed to the 2007 implementation; historical Algorithm 3 remains pending |
| EA-GROUP-002 | J §6: stabilizer orders 5760,384 in n=4 and 4960,4960,160,160,155,155,155 in n=5. | `sage -python sage/ccz_stabilizers.sage --output build/ccz-stabilizers.json`; [record](results/ccz-stabilizers.json). | Reproduced for all nine supplied representatives; full code groups agree between Miller and Bliss, exact EA intersection orders and generator witnesses verified |
| TOTAL-001 | J Table 4: APN totals in n=4,5. | Combine complete EA coverage with [computed stabilizers and orbit sizes](methods/ccz-stabilizers.md), [record](results/ccz-stabilizers.json). | n=4 total 18940805775360 reproduced using the completed two-class classification. n=5 total 110823678910407691468800 reproduced by combining the completed EA-002 coverage with the verified seven stabilizers and orbit sizes |
| DIM6-001 | J §7, Table 5: fourteen dimension-six representatives and their invariants/equivalences. | Transcribe inputs with source checks; verify APN, degrees, Gamma-ranks, code automorphism information and historical CCZ relationships. Assess canonicity claims separately from inequivalence. | Pending; no exhaustive dimension-six classification is claimed |

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
