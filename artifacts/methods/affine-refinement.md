# Refining affine templates

Run `make refinement` from `artifacts/`. The readable implementation is
[affine_refinement.py](../lib/affine_refinement.py), exercised by
[affine_refinement.sage](../sage/affine_refinement.sage). The completed record
is [affine-refinement.json](../results/affine-refinement.json).

This reconstructs thesis §4.2.1, Algorithms 5 and 6, before introducing
canonicity tests. It is a reference implementation using immutable state;
packed state and rollback can later accelerate equivalent operations.

## State and refinement

A template is a tuple indexed by F_2^n, with `None` for an undefined value.
The domain must be empty or an affine subspace, and the determined map must
be affine. Start with `empty_template(n)` and use `refine` to maintain this
invariant. The low-level kernel assumes an already valid template rather than
rechecking all affine relations on every call; arbitrary partial truth tables
are not valid inputs.

To add p -> y to a nonempty affine domain D, choose o in D. If p is outside D,
the affine hull is the disjoint union

```text
D  union  {o+x+p : x in D}.
```

The forced values on the second coset are `f(o)+f(x)+y`. This follows by writing
D=o+U and using the linear part of f on U. The extension is unique on the
new hull and has no further forced values outside it. An empty template first
becomes a singleton. A repeated assignment to a determined point must agree
with its current value; otherwise refinement fails. Zero is an ordinary value,
not an undefined marker.

With `injective=True`, an already noninjective template is rejected. For an
injective template, its image is itself an affine subspace; extending by a
value outside that image produces a disjoint image coset and preserves
injectivity. A value inside it creates a collision. The reference checks the
result directly for repeated images, without relying on an optimized rank test.

## Completion

`complete` repeatedly chooses the least missing input and least unused output,
then refines. An incomplete affine domain has fewer than q elements, so an
unused output exists. Every step grows the domain; the process terminates.
If the initial template is injective, the image-coset argument shows that this
constructs an affine permutation. Noninjective templates can still be completed
as affine maps when injectivity is not required.

No completion heuristic is a canonicity test: this chooses one extension,
not a lexicographically minimal representative of an equivalence class.

## Independent verification

The Sage script enumerates all matrices M over GF(2) and translations b, and
forms complete maps x -> M*x+b using Sage vector arithmetic. It checks the
expected affine-map count q^(n+1) and affine-permutation count
`q * product(q-2^i, i=0..n-1)`.

- In dimensions 1 and 2, enumerate every affine domain (including empty),
  every restriction of every affine map, every proposed input/output assignment,
  and both injectivity modes. Compare accepted/rejected refinements and their
  exact sets of compatible full maps against the independent matrix oracle.
  Independently intersect all enclosing affine subspaces to check that the
  refined domain is exactly the affine hull. Check greedy completion against
  the same full-map oracle.
- Through dimension 3, reconstruct every affine map from both the standard
  affine basis and its translate by the all-one vector. The translated basis
  tests the displacement term and domains initially not containing zero.

The completed run checked 9 templates and 72 assignment/mode combinations in
dimension one; 177 templates and 5,664 combinations in dimension two; and
8,192 basis reconstructions covering all 4,096 affine maps in dimension three.
It took about 0.32 seconds after Sage startup. These are finite tests alongside
the algebraic justification, not exhaustive dimension-four classification.

The [affine canonicity experiment](affine-canonicity.md) now builds on this
reference and completes the dimension-four classification checks before
dimension five, with a documented intermediate-count discrepancy.

## Use inside the canonicity search

The APN backtracker invokes a second backtracking search over affine templates.
In thesis Algorithm 7 the composition convention is `t = beta ∘ s ∘ alpha`.
At comparison position d, first determine `alpha(d)`, then read
`u = s(alpha(d))`, then determine `beta(u)`. Each guessed affine assignment
propagates to its affine hull, so subsequent positions may already be forced.
Compare the resulting output with `s(d)` in lexicographic order. An undefined
value along the composition cannot be treated as a numerical comparison result.

The full EA variant adds an affine template gamma and compares
`beta(s(alpha(d))) XOR gamma(d)` with `s(d)` (thesis §4.2.4). The historical
candidate search instead used the weaker affine filter together with vanishing
on the affine standard basis, followed by EA reduction. These are distinct
filtering obligations even though they reuse affine refinement.

The nested searches can share the same refinement implementation while owning
separate state and rollback records. A typed Cython implementation should keep
the calls between the outer search and the inner recursive helpers at C level;
the nesting introduces no requirement for a Python callback at each node.
The readable recursive tests are now implemented; the typed mutable version
remains an acceleration option.

## Reusable value buffers and defined-position masks

The reference uses `None`. The author recalls a further optimization supported
by recovered affine-search code: store values in a reusable buffer and let a
separate domain mask determine which positions are defined. Values outside
that domain have no meaning and need not be cleared when backtracking.

The representation invariant is: a buffer entry represents a template value
exactly when its domain bit is set. Refinement preserves all currently defined
values and writes newly determined values only outside the old domain. Each
recursive branch carries its own domain mask and, for injective templates,
image mask. Returning to the parent masks restores the logical template even
though the value buffer still contains descendant assignments. This applies
to failed branches as well as completed branches. Each newly defined slot must
be written before it can be read as defined in another branch.

This is sufficient because affine extension grows a closed domain by a disjoint
coset. No ancestor-defined entries are overwritten. If another operation does
overwrite such entries, it needs explicit restoration. The APN difference table
also has its own undo requirements; restoring affine masks does not undo it.
Materializing a reference template means selecting buffer values at set bits
and `None` elsewhere, never interpreting stale entries as assignments.

The author also recalls q=2^n as an undefined sentinel in optimized code. That
is a separate representation option, not a reason to clear masked-out slots.
A sentinel-based table needs a type wide enough to represent q (an unsigned
byte suffices through n=7, but not n=8) and must exclude the sentinel from
vector arithmetic. This recollection has not yet been tied to a source variant.

When implementing the mutable backend, verify it against the immutable reference
after refinement, rejection, and rollback. Deliberately vary the contents of
undefined slots, including plausible vector values, and require identical
logical results. This tests dependence on the mask rather than accidentally
relying on zeroed buffers or sentinels. These are planned checks; the present
implementation still uses immutable tuples.
