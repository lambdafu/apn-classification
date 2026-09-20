# Dimension-five candidate reduction to seven EA classes

This stage consumes the completed 11,768-table search output, verifies all
assignments to the seven proposed article representatives, and tests all 21
representative pairs exactly for EA inequivalence. The proposed representatives
are inputs to check, not an assumption that every candidate belongs to one of
their orbits. An unmatched candidate or an equivalent representative pair
aborts the experiment. The run also checks that each proposed representative
is the first lexicographic candidate assigned to its class.

From `artifacts/`:

```sh
sage -python sage/ea_reduce.sage --workers 8 --output build/ea-reduction-5.json
sage -python sage/verify_ea_reduction.sage --record build/ea-reduction-5.json \
  --output build/ea-reduction-5-verification.json
```

The first command creates a JSON run record and one JSONL witness record per
candidate. A `.partial` file is flushed during reduction; the completed file
is installed only after all candidates pass. The parent verifies every
worker's returned witness again. This stage can use multiple CPU processes
without changing the input enumeration or its historical run record. It does
not implement resumable reduction jobs. The original candidate text, search
record and progress log are read-only inputs.

## EA test and relation to the reconstruction

The existing readable three-template routine in `lib/ea_equivalence.py`
implements the relation

```
T(x) = beta(S(alpha(x))) XOR gamma(x).
```

Alpha is an affine permutation, beta a linear permutation, and gamma affine.
The new `normalized_equivalence_witness` in that file expresses the same exact
search after eliminating gamma algebraically. `cython/ea_reduce.pyx` implements
that adaptation with shared arrays, branch-local masks, and recursive affine
input refinement. This is a documented implementation adaptation for the
reproduction; it is not claimed to be the missing original reduction driver.
No CCZ classifier, code canonicalization, graph isomorphism, or stabilizer
order is used to assign candidates or prove these representatives inequivalent.

### Elimination lemma

For a complete function F define its affine interpolation and normalization by

```
L_F(x) = F(0) XOR XOR_{i : x_i=1} (F(e_i) XOR F(0)),
N(F)(x) = F(x) XOR L_F(x).
```

The operator N is linear over binary-vector-valued functions, kills every
affine function, and commutes with linear output maps. For any affine input
permutation alpha and linear output permutation beta, an affine gamma solving
`T = beta(S compose alpha) XOR gamma` exists if and only if

```
N(T) = beta(N(S compose alpha)).
```

Necessity follows by applying N. For sufficiency the difference has zero
normalization, hence equals its affine interpolation and is affine. Gamma is
then the pointwise difference, uniquely determined by alpha and beta.

Thus enumerate affine alpha and refine a linear beta with **forced** values
`beta(N(S compose alpha)(x)) = N(T)(x)`. Scan x in integer order. Every basis
position needed to calculate the normalized value at x is at most x, so its
alpha image is already known after affine refinement. Alpha's determined
input set is a prefix linear subspace, with an affine map on it; each next
independent input image is tried outside its current image set. This enumerates
all affine input permutations.

Beta's domain and image are linear subspaces. If a new input lies in its
domain, check its determined value. Otherwise its required image must lie
outside the existing image subspace, and linear closure determines the new
coset. Every solution's beta obeys these forced constraints. Any injective
linear map on the resulting subspace extends to an invertible linear map of
the full space. At success the implementation makes such a completion and
recovers gamma pointwise; at failure every admissible alpha has been tried.
A completed negative return is therefore exact, not a timeout heuristic.

For source degree at most two, `S(u+t) XOR S(u)` is affine in u. Input
translation can consequently be absorbed into gamma, so fixing alpha(0)=0
is exact in that case. The compiled and readable implementations support
turning that optimization off for verification.

## Invariants and order

Candidate processing retains the proposed representatives' published order.
Algebraic degree and the histogram of degrees of the nonzero-direction
functions `D_a S(x)=S(x+a) XOR S(x)` skip impossible comparisons. The derivative
histogram is an additional documented optimization of this reproduction; no
claim is made that the original reduction driver used it.

Indeed, writing alpha(x)=A x+t gives

```
D_a T(x) = beta(D_{A a} S(alpha(x))) XOR D_a gamma.
```

The last term is constant. Nonzero directions are permuted by A; affine input
substitution and invertible linear output substitution preserve derivative
degree, as does addition of a constant. The histogram is therefore an EA
invariant. Here all candidate degrees are at least two, so their ordinary
algebraic degree is also EA invariant. Independently of those shortcuts, the
run performs the exact EA backtrack test on **all 21 proposed pairs**.

## Verification and evidence

- All 65,536 ordered pairs of two-bit functions are checked against the
  independent ANF orbit characterization: the sole nonlinear coefficient is
  the XOR of the four outputs; zero and nonzero give the two EA orbits.
- The original three-template reference, normalized reference and compiled
  search without the translation shortcut agree on 512 two-bit comparisons.
- 64 seeded three-bit affine-action examples agree between the normalized
  reference and compiled search, with every returned map checked directly.
- Input file hashes are checked against the completed search record, including
  its hash of packed candidate bytes; ordering, uniqueness and APN predicates
  are checked again.
- Every returned alpha, beta and gamma is checked for affinity, applicable
  invertibility, and the EA equation at all 32 inputs. The separate verifier
  replays all assignment certificates with plain Python integer operations;
  it does not invoke the compiled equivalence search. It checks the presence
  of the 21 negative records, but does not re-execute them. Re-run the main
  experiment to repeat those exact negative searches.

The [completed run record](../results/ea-reduction-5.json),
[assignment certificates](../results/ea-reduction-5-assignments.jsonl), and
[separate certificate replay](../results/ea-reduction-5-verification.json)
provide the maintained evidence. This fills the candidate-reduction step
between the completed search and the existing CCZ/stabilizer calculations.
It does not reconstruct article Algorithm 3 or verify the remaining
power-function correspondences.

## From candidate coverage to the classification theorem

A lexicographically least function in any EA orbit vanishes at zero and each
standard basis vector. Otherwise subtract its value at zero, or subtract the
linear map `x -> x_i F(e_i)` at the first nonzero basis position. The latter
vanishes at every integer input smaller than `e_i`, and makes that entry zero,
contradicting minimality. Such an EA minimum is also affine canonical, since
affine equivalence is a subrelation of EA equivalence.

Consequently the completed normalized search with sound partial affine
pruning contains the least function in every EA orbit. APN propagation removes
only impossible completions; an affine rejection has a strictly smaller
comparable prefix and cannot remove an EA minimum. The cutoff omits some
partial checks but always restores the complete check. These are the search
coverage conditions established by the earlier reconstruction.

Assigning every enumerated candidate to the seven pairwise inequivalent
representatives therefore proves there are exactly seven EA classes. Since
those representatives are also the first candidates in their assigned classes,
and the global EA minima must be in the list, they are the global EA minima.
This implication uses the completed exhaustive search, not just the agreement
of counts or the published proposed tables.

Together with the existing supplied-representative CCZ witnesses and exact
negative distinctions, this supplies full dimension-five CCZ coverage as well.
Together with the verified full EA stabilizers and orbit sizes, it supplies the
coverage step for the dimension-five total in article Table 4. These are
combinations of separately recorded experiments, not additional results of
the witness-replay program alone.

## Completed class sizes

Counts below are weak candidates per EA class, not full EA orbit sizes.

| Article representative | Candidates | First candidate row |
| ---: | ---: | ---: |
| 1 | 76 | 1 |
| 2 | 76 | 2 |
| 3 | 2284 | 151 |
| 4 | 2284 | 152 |
| 5 | 2328 | 4577 |
| 6 | 2360 | 5207 |
| 7 | 2360 | 5209 |

The assignment stage used 8 low-priority processes and took
248.205 elapsed seconds, excluding initial compilation, kernel checks
and the 21 preliminary pair tests. The separate certificate replay verified
all 11,768 assignments.
