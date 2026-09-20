# CCZ classes, EA stabilizers, and orbit sizes of supplied representatives

Run from `artifacts/`:

```sh
sage -python sage/ccz_stabilizers.sage --output build/ccz-stabilizers.json
```

The readable Sage implementation is [code_classification.py](../lib/code_classification.py),
with an independent small-instance suite in
[verify_code_classification.py](../lib/verify_code_classification.py).
The [completed record](../results/ccz-stabilizers.json) includes all positive
CCZ assignment witnesses, every pair's equivalence decision, generators of the
full code automorphism groups, lifted EA stabilizer generators, exact orders,
canonical code matrices, orbit sizes, source hashes, and software versions.
No Magma, GUAVA, or new compiled kernel is required. The full verification
currently takes about three seconds after Sage startup on the development Mac.

This experiment classifies **the supplied representatives**. The separate
[completed dimension-five EA reduction](ea-reduction.md) now assigns every
construction candidate to those seven classes. Combining the two records
establishes full dimension-five coverage and the total; the original group
record itself retains its supplied-input scope.

## Computed results

Dimension-four representatives 1 and 2 lie in one CCZ class and have EA
stabilizer orders 5760 and 384. In dimension five, using article Table 3 numbers:

| Representative | Degree | CCZ representative among supplied tables | EA stabilizer order | Code automorphism order |
| --- | ---: | ---: | ---: | ---: |
| 1 | 2 | 1 | 4960 | 4960 |
| 2 | 2 | 2 | 4960 | 4960 |
| 3 | 3 | 1 | 160 | 4960 |
| 4 | 3 | 2 | 160 | 4960 |
| 5 | 4 | 5 | 155 | 310 |
| 6 | 3 | 2 | 155 | 4960 |
| 7 | 3 | 1 | 155 | 4960 |

Thus the seven supplied functions partition into CCZ blocks {1,3,7}, {2,4,6},
and {5}, exactly as published. Distinct canonical forms establish the negative
cases; positive assignments carry checked invertible affine graph maps.

The tuple (CCZ class, algebraic degree, EA stabilizer order) differs for every
pair of these seven functions. Each component is an EA invariant: EA implies
CCZ equivalence, affine additions preserve degree for these nonlinear
functions, and stabilizers of points in the same group orbit are conjugate.
Consequently the seven supplied representatives are pairwise EA inequivalent.
This argument uses the computed full stabilizers, not the published orders
as an assumption. It does not establish lexicographic minimality among all
functions or cover the remaining construction candidates.

## The code and the CCZ reduction

Let M_s have columns (1, x, s(x)), with x in increasing integer order and each
vector expanded least-significant bit first. Let C_s be its binary row code.
The surviving historical Magma implementation used the dual code instead;
coordinate permutation equivalence is preserved under duality. This experiment
uses the smaller row code, checks both row and dual witness equations, and
independently checks equality of their permutation automorphism groups.

An invertible affine map of graph space sending graph(s) to graph(t) induces
a permutation p of the graph points. In augmented coordinates it gives an
invertible row transformation sending M_s to M_t with column x replaced by
column p(x), hence a code equivalence.

Conversely, equal row codes after that column permutation give identical
linear dependencies among the corresponding augmented graph columns. Sending
one set of columns to the other is therefore a well-defined isomorphism of
their spans. Equivalently, subtract a chosen graph point to obtain an
isomorphism of the graph difference spans. Extend corresponding bases to
bases of the whole 2n-dimensional space and restore the offset. This yields
an invertible affine graph map, including when the graph does not span the
whole ambient space. The implementation constructs this extension explicitly.

The record uses zero-based permutations p(x) from source to target and an
augmented binary matrix T satisfying, for every x,

```text
T * (1, x, s(x))^T = (1, p(x), t(p(x)))^T.
```

A separate pure-integer check verifies the matrix shape, affine first row,
full rank of its linear part, permutation bijectivity, and all graph images.
A code canonical form is not a canonical function truth table. Representatives
1, 2, and 5 are the least supplied tables in their computed blocks; identifying
them as globally CCZ canonical also needs the completed EA classification.

## Exact canonicalization through spanning codewords

For a small binary code, enumerate its words. Include the all-one word if it
is present, then add complete positive-weight shells in increasing order until
the selected words span the code. This selection is invariant under coordinate
permutation: weights, the all-one word, and span ranks are preserved.

Construct a bipartite incidence graph with separate colors for coordinates
and selected words. A coordinate is adjacent to a word exactly when that word
has a 1 at the coordinate. Code equivalences induce colored graph isomorphisms.
Conversely, a colored graph isomorphism permutes coordinates and takes the
selected words onto the target selected words. Since both selected sets span,
it takes the entire source code onto the target code. Thus this reduction is
exact; using a nonspanning selection would not establish the converse.

This check matters here: the minimum-weight words of dimension-five row 5
span only dimension 10. Adding the all-one word gives the required dimension
11. For the other six rows, the minimum-weight words already span dimension
11. Their selected incidence graphs use 497 words; row 5 uses 32 words.

Sage's Bliss backend computes exact canonical labels and graph automorphism
groups with the two vertex colors fixed. Canonical point labels yield both a
canonical row-code matrix and explicit permutations between equivalent codes.
Decisions use exact graph equality, not just the recorded SHA-256 fingerprints.
The reference implementation limits enumerated code dimension to 12; its
intended inputs here have dimensions 9 and 11.

## Full EA stabilizers

### Provenance

This reduction belongs to the **modern verification**, not to the recovered
2007 implementation or article Algorithm 3. A literature basis is Carl Bracken,
Eimear Byrne, Gary McGuire and Gabriele Nebe, *On the equivalence of quadratic
APN functions*, Designs, Codes and Cryptography **61** (2011), 261–272,
[DOI: 10.1007/s10623-010-9475-8](https://doi.org/10.1007/s10623-010-9475-8).
In the [2011 manuscript](https://mural.maynoothuniversity.ie/id/eprint/2690/1/CB_Equivalence.pdf)
([arXiv:1101.1508](https://arxiv.org/abs/1101.1508)), §2, Theorem 1 identifies
EA equivalence with the action of AGL(n,2) on the associated row codes; Lemma 1
characterizes equality of those codes by output transformations and affine
corrections. These statements apply to arbitrary functions despite the title.
Their trace-coordinate code is the same row code used here, after a choice
of binary bases. Theorem numbering here refers to that 13-page manuscript;
the earlier 16-page manuscript on Nebe's website numbers the theorem as 6.

The stabilizer formula below is a consequence of that correspondence, with
the full-rank condition making the lift unique. We give the proof explicitly
to state the hypothesis and the group convention needed by this implementation.
We do not attribute our precise lemma statement or Sage implementation to
that paper, or claim a new result. Brinkmann–Leander §6, Lemma 7 supplies a
related uniqueness criterion, and §6 supplies the EA action and orbit formula.

### Lemma: EA stabilizers as an intersection of permutation groups

Let V = F_2^n and s: V -> V. Let M_s be the binary matrix with columns
(1,x,s(x)), indexed by x in V, and let C_s be its row code. Assume

```text
rank(M_s) = 2n+1.
```

Equivalently, graph(s) affinely spans V × V. Let Aut(C_s) mean the
**coordinate permutation** automorphism group, and embed A = AGL(V) in the
same symmetric group using the input labels x. Define

```text
H = Aut(C_s) intersect A,
S_s = {(alpha,beta,gamma): alpha in A, beta in GL(V), gamma affine,
                         s = beta o s o alpha + gamma}.
```

Then projection onto alpha is a bijection from S_s onto H. In particular,
each alpha in H has exactly one pair (beta,gamma), and |S_s| = |H|.
With the article's group law (7) and usual function composition in H,
the map (alpha,beta,gamma) -> alpha^-1 is a group isomorphism S_s -> H.
The projection onto alpha itself reverses products; this distinction does
not change the subgroup, its order, or generation by the recorded witnesses.

**Proof.** Fix an affine permutation alpha and form M_alpha with columns
(1,alpha(x),s(alpha(x))). Thus M_alpha is a column permutation of M_s.
It has row code C_s exactly when alpha belongs to Aut(C_s); either inverse
convention for permuting code coordinates gives the same automorphism group.

Suppose first that (alpha,beta,gamma) is in S_s. Changing the input rows
from alpha(x) to x is invertible and affine. The equation
s(x) = beta(s(alpha(x))) + gamma(x) then changes the output rows using an
invertible linear output block plus combinations of the constant and input
rows. These are invertible row operations taking M_alpha to M_s. Their
row codes are equal, hence alpha belongs to H.

Conversely, let alpha belong to H. The equal row spaces and full row ranks
give a unique invertible matrix T such that T M_alpha = M_s. Write
alpha^-1(z) = a + A_0 z. The first n+1 rows of this equation are already
represented by the constant row and that affine inverse. Full row rank
makes these representations unique. Consequently T has block form

```text
       [ 1    0    0 ]
T  =   [ a   A_0   0 ],
       [ c    D    B ]
```

where B is invertible because T and A_0 are invertible. The last n rows give

```text
s(x) = c + D alpha(x) + B s(alpha(x)).
```

Thus beta(y) = B y and gamma(x) = c + D alpha(x) give the required EA
stabilizing triple. Uniqueness of T also makes beta and gamma unique.

Finally, article (7) makes the alpha component of g' g equal to
alpha o alpha'. Taking inverses yields alpha'^-1 o alpha^-1, which is the
product of the images of g' and g. This proves the isomorphism assertion. ∎

**Scope of the hypothesis.** No APN assumption is needed for this lemma,
but the full-rank condition must be checked. For example, for the zero
function with n >= 2, every invertible linear beta gives the same
stabilizing input permutation alpha when gamma = 0. Counting input
permutations alone would then undercount the triples. The implementation
rejects rank-deficient inputs for this stabilizer calculation; its separate
CCZ graph-lifting routine does support deficient rank.

For the normalized representatives here, the hypotheses of article Lemma 7
also imply full rank: an affine relation c + u(x) + v(s(x)) = 0 vanishes
on the affine basis in s^-1(0), forcing c = 0 and u = 0. The image of s
spans V, forcing v = 0 as well. Both the normalization/spanning conditions
and rank(M_s) are checked directly by the experiment.

### Computation and witnesses

Write the EA action as in article §6:

```text
(alpha, beta, gamma) . s = beta(s(alpha(x))) XOR gamma(x),
```

where alpha is affine invertible, beta is linear invertible, and gamma is affine.
Let A be AGL(n,2) acting on the q input positions, generated here by translations
and elementary transvections. Compute

```text
H = Aut(C_s) intersect A.
```

For each generator alpha of H, solve for the unique beta and gamma in
`s = beta(s alpha) XOR gamma`. Independently verify the resulting lookup
tables' affinity/invertibility and the equation at every input. The returned
alpha generators are checked to generate all of H.

Completeness of H uses a full code automorphism computation, not merely a
collection of verified automorphisms. Sage's Robert Miller partition-refinement
backend and Bliss applied to the spanning-word incidence graph independently
return the same full coordinate group. The graph group's restriction to
coordinates is faithful: distinct word vertices have distinct neighborhoods.
Both group orders and the actual generated groups are compared. Sage/GAP then
computes the exact intersection and its order.

This is a **modern independent computation** of the published stabilizers.
It does not reconstruct article Algorithm 3's iterative lexicographically
canonical generator search. That historical algorithm remains a separate
reconstruction obligation; these generators need not match its ordered list.
The code automorphism group is an affine graph stabilizer here because of full
graph span, and is generally larger than the EA stabilizer, as the table shows.

Source entry points in [code_classification.py](../lib/code_classification.py):
`graph_matrix` constructs M_s; `affine_input_group` constructs A;
`ea_stabilizer` computes the full groups and their intersection;
`lift_ea_input` solves for beta and gamma and checks every table entry;
`ea_group_order` supplies the action-group order for orbit–stabilizer.
The runnable experiment is [ccz_stabilizers.sage](../sage/ccz_stabilizers.sage),
and [verify_code_classification.py](../lib/verify_code_classification.py)
contains the independent exhaustive dimension-three stabilizer check.

## Orbit sizes and coverage

With q=2^n and L=product(q-2^i, i=0..n-1), the action group has order

```text
|G| = (q L) * L * q^(n+1).
```

The factors count alpha, beta, and gamma respectively. Each orbit has size
|G|/|G_s|. The distinct supplied EA orbits sum to:

- n=4: **18,940,805,775,360**. Together with the independently completed
  dimension-four classification, this reproduces the total.
- n=5: **110,823,678,910,407,691,468,800**. This reproduces the published sum
  for these seven pairwise inequivalent EA orbits. The claim that it counts
  *all* APN functions remains conditional on the pending exhaustive EA reduction.

## Independent checks and backend observations

The finite verification checks every function through n=2. For two or four
distinct graph points, affine-span rank determines their ambient affine orbit;
this supplies an oracle independent of codes and graph canonicalization.
All 260 functions receive verified affine graph lifts, including deficient
ranks. In n=3, all 225,792 alpha/beta pairs are enumerated, gamma is determined
pointwise and checked for affinity, and the resulting stabilizer order 1344
is compared with the group-intersection method.

Exploratory backend probes ran at low priority while the construction search
continued. Miller's positive code-equivalence calls and full automorphism
computations were fast. Its direct negative comparison of n=5 rows 1 and 2
hit a 20-CPU-second limit; Feulner code canonicalization of row 1 also hit that
limit. Those interrupted calls are inconclusive and are not used as negative
results. The spanning-word graph route finished quickly, with exact negative
cases and independent group comparisons, so it is the maintained backend.
GUAVA/Leon remains an optional future comparison; it was not needed or exercised.

A subsequent longer standard-library probe, requested by the author, completed
the row-1/row-2 inequivalence test in **83.140 CPU seconds (83.229 elapsed)**
with Sage 10.6. See [the simple script](../sage/ccz_standard_pair.sage) and
[completed record](../results/ccz-standard-pair.json). The earlier timeouts
therefore did not establish that the standard method was impractical. Walsh
spectra separate row 5, and positive witnesses connect the other four rows to
rows 1 and 2; this one negative comparison supplies the remaining distinction.
The graph backend remains a faster, separate modern verification method.

Backend references: [Sage linear-code operations](https://doc.sagemath.org/html/en/reference/coding/sage/coding/linear_code.html),
[Sage graph canonical labels](https://doc.sagemath.org/html/en/reference/graphs/sage/graphs/graph.html),
and [Sage codecan](https://doc.sagemath.org/html/en/reference/coding/sage/coding/codecan/codecan.html).
The running construction's code and inputs were left unchanged.
