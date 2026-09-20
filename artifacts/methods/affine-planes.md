# Affine planes and prefix counts

Run `make planes` from `artifacts/`. The Sage entry point is
[affine_planes.sage](../sage/affine_planes.sage), with elementary integer
algorithms in [affine_geometry.py](../lib/affine_geometry.py). The completed
record is [affine-planes.json](../results/affine-planes.json). No C program is
needed for these small exact computations.

This experiment covers thesis Propositions 3.1, 3.2, and 3.7, Lemma 3.5,
Examples 3.3 and 3.12, the sequences in article equations (20)–(21), and a
finite check of thesis Theorem 3.13. Expected published data are transcribed in
[affine-planes.json](../data/affine-planes.json).

## Characterization and total count

Four distinct binary vectors form an affine plane exactly when their sum is
zero. A plane is a translate of `{0,u,v,u+v}`, with independent u,v. Conversely,
translate a zero-sum quadruple by one of its elements; the other two selected
nonzero vectors are distinct and therefore independent over F_2.

For q=2^n, any unordered triple of distinct points has a unique fourth point,
their sum. It is distinct from the other three. Each plane is obtained from
exactly four triples. Thus the total number of planes is `binomial(q,3)/4`.

The script compares two complete sets: zero-sum four-element subsets enumerated
using integer XOR, and cosets of rank-two linear subspaces constructed by Sage
over GF(2). These constructions agree through dimension five:

| Dimension | Affine planes |
| --- | ---: |
| 1 | 0 |
| 2 | 1 |
| 3 | 14 |
| 4 | 140 |
| 5 | 1240 |

For every nonzero linear functional and every plane in these dimensions, the
script checks that the number of points on either side is even. Algebraically,
the functional applied to the sum of the four points is zero, so a plane lies
entirely in one hyperplane or splits 2+2. Restricting this partition to planes
contained in any M proves the decomposition lemma for arbitrary subsets.

## Recurrences and indexing

Let A(k) count planes contained in `[0,k)`, and let Delta(k)=A(k)-A(k-1)
count those completed when input k-1 is added. Both functions are zero for
k=0,1,2,3. For k>=4, set h to the largest power of two strictly below k,
and r=k-h. Thesis Proposition 3.7 gives

```text
A(k)     = A(h) + A(r) + binomial(r,2) * h/2
Delta(k) = Delta(r) + (r-1) * h/2.
```

The lower half contributes A(h); the upper part, translated by h, contributes
A(r). A crossing plane is determined by an unordered pair of upper points
and one lower point. The other lower point is forced and still lies in the
lower half. Either lower point generates the same plane, producing the factor
h/2. For Delta, choose the other upper point in r-1 ways instead, and add
the planes wholly in the upper part. The base cases avoid fractional h/2
at h=1 without changing the mathematical recurrence.

The two recurrences are implemented separately. Every prefix and every
increment through q=32 is checked against the enumerated plane set. The
script also verifies `Delta(k)=A(k)-A(k-1)` and the two printed sequences
through k=16. In an APN search, Delta(k) counts newly completed plane
constraints; it does not count distinct forbidden output values, since
multiple constraints can forbid the same value.

## Extremal bound: finite verification

Thesis Theorem 3.13 states that no k-element subset contains more planes than
the initial interval `[0,k)`. The script enumerates **every subset** of F_2^n
for n<=4 and counts its planes directly by containment. It records the maximum
at each cardinality, plus a witnessing subset. Every maximum equals A(k).
In dimension four this examines 65,536 input subsets, not 16^16 functions.

The general theorem's proof uses saturation and the shuffle/sink construction.
That proof has not yet been fully reconstituted here. The finite verification
is deliberately recorded separately and must not be cited as a general proof.
The general characterization, total-count, and recurrence arguments above do
not depend on this extremal theorem.

## Reproduction limits

Default run: dimensions 1–5, all subsets through dimension 4. The recorded run
took approximately 1.14 seconds after Sage startup on arm64 macOS. Both limits
can be reduced with `--max-dimension` and `--subset-dimension`. The program
does not offer exhaustive subset enumeration above dimension four.
Run records include exact sequences, finite verification ranges, versions,
source hashes, and timings. Reproducing the plot and heuristic complexity
estimates is an optional investigation, separate from the exact geometry.

## Conflict model and the shape of the search tree

Article §3, Proposition 2 and Figure 1 (printed p. 277), and thesis Proposition
4.11 and Note 4.13 (pp. 34–35), connect the exact opportunity count to a
probabilistic model. With q=2^n, the independence hypothesis gives

```text
P(k) = 1 - (1 - 1/q)^Delta(k)
C(k) = q * P(k)
expected available values = q * (1 - 1/q)^Delta(k).
```

Delta counts plane constraints; C models distinct forbidden values, allowing
several constraints to exclude the same value. The independence and uniformity
assumptions are heuristic, unlike the exact affine-plane counts. The papers
compare modeled and measured conflicts in dimension six and explicitly warn
that multiplying estimated branching factors gives unreliable deep-tree and
full-function counts.

On 2026-09-20 Marcus confirmed that he used Knuth sampling to measure the
actual conflicts, consistent with the article's attribution preceding Figure 1.
Distinguish these sampled measurements from the independence-based prediction;
the plotted measurements were not an exhaustive census of the search tree.
The precise sampling configuration and aggregation details remain to be
recovered if this optional experiment is reproduced.

The recurrence explains structured rises and drops in pruning pressure, not
just an arbitrary uneven tree. For example, at defined-entry counts k=8..17,
Delta is `7, 0, 4, 8, 13, 16, 22, 28, 35, 0`. When the new input is 8 or 16,
a prefix gains no complete plane; constraints accumulate again as the new
binary block fills. Thesis Note 4.13 describes these as breathing holes and
also notes smaller dips associated with short sums of powers of two. This
structure does not by itself predict which output-value branch will be larger:
at a fixed prefix length the same number of constraints can exclude different
numbers of distinct values, depending on earlier assigned outputs.

The current propagation search has sparse domains D. For an unknown position
p, the exact analogous opportunity count is the number of unordered triples
{a,b,c} in D with a XOR b XOR c = p. Its available-value mask records the union
of their exclusions (with normalization/permutation restrictions distinguished
where applicable). Merely substituting the number of known entries into the
prefix recurrence would be incorrect. A future reproduction of Figure 1 should
state its sampling scheme and separate the APN-only model from selection by
normalization, propagation, and affine pruning. Current attempt/rejection
profiles count explicit branches and propagation failures, not samples of
C(k); they cannot be substituted directly for the figure's measured conflicts.

The exact Delta sequence is already reproduced. Reproducing the probabilistic
model's measurements and figure is optional SEARCH-002; it does not block the
classification reconstruction. The author clarified this scope on 2026-09-19.
