# Dimension-five inputs and classification stages

The seven published representatives are now explicit inputs in
[dimension-five.json](../data/dimension-five.json). Each table contains s(0)
through s(31) as decimal labels in the existing binary-coordinate convention.
The article's Table 3 (printed p. 280, PDF p. 8) was inspected visually; all
224 entries and seven degrees were independently compared with the thesis's
Table 4.5 (printed p. 42, PDF p. 48). Source PDF hashes are recorded in the data.

Run the small input check from `artifacts/`:

```sh
sage -python sage/dimension_five_inputs.sage --output build/dimension-five-inputs.json
```

Ordinary `python3` can also run this entry point. No compiled kernel or
classification search is used. The [completed record](../results/dimension-five-inputs.json)
checks the supplied representatives, not the completeness of the published
classification. Its checks are:

- APN by both direct derivative multiplicities and all affine-plane constraints.
- Zero at zero and the standard basis; distinct tables in lexicographic order.
- Algebraic degree by both a Mobius transform and direct subset sums for ANF
  coefficients. The degrees are 2, 2, 3, 3, 4, 3, 3.
- Absolute Walsh spectra by both direct character sums and a fast Walsh
  transform, with both output-mask conventions. The fast transform also checks
  Parseval's identity; zero-function spectra provide an analytic test case.

The data also transcribe the published power-function correspondences, CCZ
class assignments, and EA stabilizer orders. Those are **verification targets**,
not results established by this input check. Finite-field representations and
explicit transformations remain to be supplied for the power correspondences.

## Walsh convention discrepancy

Article §5, p. 280 defines the extended Walsh spectrum with nonzero output mask
b. There are then 32*31=992 coefficients. Its printed multiplicities instead
sum to 1024 and agree with including b=0. Both are recorded explicitly:

| Representatives | All a,b (printed multiplicities) | All a, nonzero b (printed definition) |
| --- | --- | --- |
| 1, 2, 3, 4, 6, 7 | (0:527), (8:496), (32:1) | (0:496), (8:496) |
| 5 | (0:217), (4:465), (8:310), (12:31), (32:1) | (0:186), (4:465), (8:310), (12:31) |

The b=0 row contributes exactly 31 zeros and one coefficient of magnitude 32,
independently of the function. Thus the convention mismatch does not change
which functions have equal spectra. It does affect a literal comparison of
the formula and multiplicities, so it must not be silently hidden.
The two resulting spectrum groups do not establish all three CCZ classes.

## Work completed independently of construction

The [CCZ/stabilizer experiment](ccz-stabilizers.md) now establishes the three
CCZ blocks, all seven full EA stabilizer orders, and pairwise EA inequivalence
of the supplied tables. It saves explicit witnesses and exact orbit sizes.
These checks can precede the reduction of the full candidate set. They do not
establish that the seven supplied tables cover it or are globally minimal.
The input-check record above deliberately retains its narrower scope.

## Construction-dependent work and subsequent checks

The construction and EA reduction below are now completed: [11,768-candidate
search record](../results/ea-candidates-5.json), [exact EA reduction and
certificate replay](ea-reduction.md). The combined evidence establishes seven
EA classes, three CCZ classes and the published orbit total. The list below
records the stage boundaries and earlier rationale; its pending-runtime and
coverage language describes the situation before this completed reduction.

1. **Validate and retain the completed search.** Check completion status,
   configuration, source hashes, candidate-file hash and count, ordering,
   normalization, and the recorded direct APN checks. Check that all seven
   published tables occur among the candidates. Compare the intermediate
   count with 11,768, recording any discrepancy rather than changing filters
   after the fact. Preserve a validated record and its tables in `results/`.
2. **Compute the EA partition.** Use degrees as a cheap invariant, then exact
   EA equivalence tests. Build classes from the computed candidates, choosing
   their least elements, and compare the resulting representatives with the
   published tables. The current readable three-template test is a reference;
   its n=5 runtime is not yet established. Benchmark a separate accelerated
   implementation when the construction run no longer needs the CPU.
3. **Check witnesses and inequivalence.** For every assignment, verify full
   affine alpha, invertible linear beta, and affine gamma in
   `target(x) = beta(source(alpha(x))) XOR gamma(x)`. Use an independent
   validation of the transformations and equation. Different degrees prove
   some negative cases immediately; equal-degree representatives require a
   completed exact inequivalence test or a sufficient independently justified
   invariant. A timeout is inconclusive. The expected degree distribution is
   two quadratic, four cubic, and one quartic EA class.
4. **Compute CCZ classes.** Use the code-equivalence approach with a documented
   code convention and checked coordinate permutations. Establish three
   classes rather than infer them from the two Walsh groups. The published
   target blocks, in Table 3 identifiers, are {1,3,7}, {2,4,6}, and {5}; their
   canonical representatives are 1, 2, and 5. The CCZ/stabilizer experiment
   now verifies these supplied-table blocks with exact negative cases and
   explicit witnesses; global coverage still awaits the EA reduction.
5. **Compute EA stabilizers and totals.** Verify full stabilizer orders
   4960, 4960, 160, 160, 155, 155, 155, then derive orbit sizes and the total
   using the stated EA group convention. The separate CCZ/stabilizer experiment
   now computes these orders and orbit sizes for the supplied tables; global
   coverage still depends on the candidate reduction. Published orders alone do not prove
   that a generated subgroup is the full stabilizer. These are EA stabilizers,
   not code automorphism or CCZ stabilizer orders.

The candidate search's complete coverage and sound pruning provide the
completeness argument; finding the seven supplied tables alone does not.
Likewise, identifying every candidate with a published table would establish
coverage by those classes, but still requires pairwise inequivalence and
minimality checks before reporting the full canonical classification.

The article's p. 279 footnote separately reports rejection of 11,760 out of
11,768 candidates, followed by five remaining candidates; subtraction gives
eight, and the final EA class count is seven. Treat these historical stage
counts as unresolved source accounting, separate from this input verification.

## Isolation from the running experiment

These inputs, the Walsh helper, the input-check entry point, and this method
were added while the dimension-five construction ran. No source file used by
that running experiment was edited. The small input verification needs well
under a second of calculation on the development machine; no EA/CCZ searches,
additional APN construction, or compilation were started as part of that input
preparation. The subsequent CCZ/stabilizer experiment is recorded separately
and runs its complete verification in about three seconds.
