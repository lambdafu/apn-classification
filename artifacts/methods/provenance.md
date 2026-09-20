# Algorithm provenance: reconstruction and modern verification

This audit records the implemented methods as of 20 September 2026. Matching
a published numerical result does not establish that the historical algorithm
has been reconstructed. The first iteration still owes the faithful algorithm
reconstruction; independent modern computations provide additional evidence.

The codeword-graph CCZ backend and the code-group intersection for EA
stabilizers were introduced during the supplied-table verification without
first explaining the change of method to Marcus. They are retained as modern
verification, not treated as completion of the corresponding historical
algorithm obligations that remain in scope. The author has explicitly excluded
the abandoned direct CCZ search from reconstruction; code-based CCZ verification
remains the intended route. Future substantive changes of method should be stated
before implementation, including which reconstruction obligation remains.

“Modern addition” below means introduced in this artifact, not a claim of
research novelty or priority. No such novelty has been established. This is
an audit of the maintained artifact, not a completed audit of every backup.

## Implemented stages

| Stage | Provenance and limits |
| --- | --- |
| APN constraints and incremental difference-table recursion | Reconstruction of the thesis's APN criterion, incremental filtering and rollback. The Cython port and runtime dimension interface are modern engineering choices. |
| Immutable plane-based search and unpruned derivative enumeration | Independent verification implementations using the historical mathematical definitions. Their copied state and brute-force traversal are not reconstructions of the optimized historical program. |
| Affine refinement and nested alpha/beta canonicity search | Reconstruction of the thesis's recursive template method. The compiled implementation retains masked reusable buffers. This does not establish identical historical traversal, instruction order, or all original optimizations. |
| Three-template alpha/beta/gamma EA equivalence | Readable reconstruction of the thesis's recursive equivalence method, used for the complete n=4 candidate reduction. Historical self-equivalence pruning is still pending. |
| Gamma-eliminated EA backtracking for the full n=5 reduction | Documented adaptation of the same EA relation: affine interpolation eliminates gamma, alpha refinement forces beta, with Cython shared buffers. Degree and derivative-degree histograms skip impossible assignments; all 21 proposed representative pairs receive exact tests. The original three-template reference remains available. No CCZ or stabilizer signatures are used; see [method](ea-reduction.md). |
| Full-input affine enumeration with greedy output minimization | Independent verification oracle in `affine_oracle.py`, used to check the recursive filter and n=4 survivors. It is not presented as the historical canonicity algorithm. |
| APN singleton propagation, sparse templates and undo trail | Reconstruction requested by the author from his recollection of exclusion masks and forced later positions. Exact historical construction source remains missing. The current trail layout and processing order are implementation choices. |
| Cutoff and final full affine check | Historical technique, reintroduced at the author's request. The interface uses an inclusive threshold on known entries after propagation. This is not a recovered original run configuration; the documented historical threshold convention differs. |
| Binary-code representation for CCZ | Historical route used with Magma, following Dillon. The modern artifact uses the smaller row code instead of the recovered code's dual representation; duality preserves permutation equivalence and both witness conventions are checked. |
| Spanning-codeword incidence graph and Bliss canonicalization | Modern replacement backend, not the thesis's direct graph search and not a reproduction of the historical Magma backend. The exact reduction is documented in `ccz-stabilizers.md`. This is the maintained CCZ decision procedure. |
| Full code automorphism groups computed by Miller and Bliss | Modern independent group computations whose resulting coordinate groups are compared. Miller's group computation does not make the final CCZ decisions a Miller pairwise equivalence computation. |
| EA stabilizer as Aut(C_s) intersect AGL(n,2) | Modern method with an explicit full-rank lemma and literature basis. It replaces neither the obligation to reconstruct article Algorithm 3 nor the obligation to check its canonical generator sequence. |
| EA orbit sizes from action-group order divided by stabilizer order | Same mathematical calculation as article §6; the current stabilizer orders feeding it come from the modern intersection method. |
| Invariants and pairwise EA inequivalence of the seven supplied n=5 functions | Using invariants to reject equivalence is historical, as the author confirms. The current check uses the distinct tuples (computed CCZ class, algebraic degree, computed EA stabilizer order). Using stabilizer order at this stage is an addition: the author established canonicity before calculating stabilizers. The CCZ and stabilizer backends are also modern additions. This supplied-table check does not establish canonicity, reduce the full search output, or establish exhaustive n=5 coverage. |
| APN, degree, Walsh and witness checks; small exhaustive oracles | Independent verification suite. Direct/fast transform comparisons, affine-span checks in tiny dimensions, explicit matrix lifts, hashes and run records are verification machinery, not claims about historical implementation. |

The currently unresolved 15-versus-16 n=4 candidate count is a concrete limit
on historical fidelity. The main original construction driver and original
intermediate candidate lists have not been located. These gaps must not be
hidden by successful final class counts or modern verification.

## Which CCZ test the completed record uses

The maintained route in `lib/code_classification.py` is:

1. `graph_matrix`: construct the binary row code from columns (1,x,s(x)).
2. `spanning_word_graph`: include the all-one word and complete codeword
   weight shells, in increasing weight, until the selected words span the code.
   Build an incidence graph with separate vertex colors for input coordinates
   and selected codewords. An edge records a 1 in a codeword.
3. `canonical_code`: ask Sage's **Bliss** backend for an exact canonical graph
   and a labeling certificate. Selection of the words is invariant under
   coordinate permutations, and the spanning check makes this an exact code
   equivalence reduction, rather than only an invariant.
4. `equivalent_permutation`: compare the canonical graphs exactly. Equal
   graphs supply a coordinate permutation; unequal canonical graphs give a
   completed negative decision. SHA-256 fingerprints are record identifiers,
   not the decision test.
5. `lift_graph_permutation`: check the row and dual code equations, construct
   an invertible affine transformation between the function graphs, and verify
   that transformation point by point.

The incidence graph in step 2 is a different object from graph(s) =
{(x,s(x))}. Using it does not reconstruct the thesis's direct CCZ search on
function graphs, which the author abandoned and has excluded from the required
reconstruction. It does retain the code-equivalence route used subsequently.

Miller's direct code-equivalence call found positive witnesses in exploratory
probes. One negative pair hit a 20-CPU-second limit; a Feulner canonicalization
probe also hit that limit. These were inconclusive performance probes, not
negative mathematical results. Bliss was selected after those probes. Neither
Magma nor GAP/GUAVA's Leon equivalence backend was used for the retained record.
Miller's full code-automorphism computation is retained as an independent
comparison for the stabilizer calculation.

The author's historical direct method was a backtrack search pruned by
self-equivalences, followed by the later move to code equivalence in Magma.
For the current supplied n=5 tables, the Walsh spectrum separates row 5;
positive equivalence witnesses connect rows 3 and 7 to row 1 and rows 4 and 6
to row 2. Once those are verified, the only remaining inequivalence needed
for the three-class partition is row 1 versus row 2. Both have the same Walsh
spectrum. This allows a simpler standard-library route without canonicalizing
all the codes.

The targeted [standard Sage probe](../sage/ccz_standard_pair.sage) tests just
that pair with `C1.is_permutation_equivalent(C2)`, after confirming equal Walsh
spectra. Run from `artifacts/`:

```sh
sage -python sage/ccz_standard_pair.sage --cpu-limit 300 --output build/ccz-standard-pair-300s.json
```

The Unix CPU limit applies only to this probe process. A completed result file
is written only if the call returns; termination at the limit is inconclusive.
The [completed standard Sage result](../results/ccz-standard-pair.json) reports
**inequivalence in 83.140 CPU seconds (83.229 elapsed seconds)** on Sage 10.6,
at low process priority while the APN search continued. The original 20-second
limit covered several computations, not just this call, and was too short to
assess the practical standard-library route. No Bliss graph or code canonical
form is used in this probe. Together with the verified positive assignments
and Walsh separation, this resolves the outstanding pairwise question for the
supplied tables. It does not supply exhaustive n=5 EA coverage.

The standard-library approach is therefore practical for this instance; the
faster graph experiment is retained as separate modern verification, not a
necessary replacement. The dedicated probe records only the row-1/row-2 call;
it is not yet a combined runner for all standard positive calls and spectrum
filtering.

See [the detailed method and lemma](ccz-stabilizers.md),
[implementation](../lib/code_classification.py), and
[completed supplied-table record](../results/ccz-stabilizers.json).

## Historical obligations still open

- Reconstruct article Algorithm 3's recursive canonical-generator search
  (EA-GROUP-001), including the induced subgroup pruning (GROUP-001).
- Resolve historical intermediate counts and configurations where possible,
  keeping missing evidence and author recollections explicit.

The abandoned direct CCZ search (CCZ-001) is historical context only, following
the author's clarification on 20 September 2026. There is no obligation to
recover or reconstruct that implementation, even on small cases.

No search kernel, result record, or running computation was changed by this
documentation audit.

The subsequent [completed candidate reduction](ea-reduction.md) supplies the
EA-002 coverage missing from the earlier supplied-table checks. Their original
records retain their narrower scope. Historical Algorithm 3 remains open.
