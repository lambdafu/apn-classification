# Small-dimensional APN enumeration

This experiment supports ledger entries APN-001 through APN-004. It reproduces
the counts in thesis Examples 4.2, 4.4, and 4.7 and article Table 4 for dimensions
1–3, and checks the equivalence of the APN predicates on a finite test domain.

## Reproduce

From `artifacts/`:

```sh
make reference
make reproduce
```

Both commands run [the Sage script](../sage/apn_counts.sage). The second compiles and loads
[the Cython kernel](../cython/apn_counts.pyx) through Sage as well. Results go to
`build/apn-counts-reference.json` and `build/apn-counts.json`, respectively.
For an explicitly retained record:

```sh
sage sage/apn_counts.sage --cython --output results/apn-counts.json
```

This run is bounded to dimensions 1–3. It is suitable for an interactive local
check; actual timings are recorded, rather than assumed from the historical
machine. The full comparison temporarily holds several copies of roughly
5.5 MB of truth-table data. No enumeration files are saved.

## Representation and definition

A table `(s(0), ..., s(q-1))`, q=2^n, represents a function on F_2^n. The integer
x denotes the vector whose coordinate i is bit i of x. Vector addition is XOR.
No finite-field multiplication or choice of irreducible polynomial is involved.
An immutable prefix specifies exactly the input interval `[0,d)`; undefined
values are not confused with zero. We do not impose s(0)=0, bijectivity, or any
equivalence normalization.

The function is APN when, for every nonzero a and every b, the number of x
satisfying s(x+a)+s(x)=b is at most two. The two solutions x and x+a represent
one unordered pair. Consequently, APN is equivalent to saying that no two
distinct unordered pairs have the same input and output differences.

Two such pairs with the same nonzero input difference cannot share exactly
one endpoint. A collision is therefore precisely four distinct inputs with
zero input sum and zero output sum. This proves the four-point characterization
used by the reference search (thesis Theorem 4.3).

## Three computations

**Sage/Python reference.** [apn_reference.py](../lib/apn_reference.py) enumerates
affine planes as ordered four-element subsets with zero input sum. At depth d,
it excludes the output values that would make the output sum zero on a plane
whose largest input is d. All other values are tried, in increasing order.
The search passes immutable prefixes and has no rollback or difference table.

Every non-APN table violates some plane constraint and is rejected when the
largest input of that plane becomes defined. No APN table violates any such
constraint. Each table has a unique sequence of prefixes. These facts give
completeness, soundness, and absence of duplicates for the enumeration.

**Incremental Cython search.** For each nonzero input difference a, a packed bitmask
records output differences already obtained from unordered pairs in the
prefix. Appending s(d) examines the d new pairs `(x,d)` for x<d. A repeated bit
rejects the refinement. At this depth, the input differences `x XOR d` are all
different, so each attempted refinement writes at most one bit in a given row.

The program records how many writes succeeded, recurses only after all checks
pass, then removes exactly those writes. On a collision it leaves the existing
conflicting bit intact. Child calls restore their own changes before returning.
Thus siblings see the same parent state; all masks must be empty when the root
search finishes. Truth-table storage is shared, but deeper calls never modify
the parent prefix. Stale values beyond that prefix are never read.

This retains the original incremental filtering, compact state, and low-copy
rollback ideas in typed Cython with a state object owned by one search. It is
not a reproduction of every old architecture-specific optimization. Arrays
are sized for this baseline, and 64-bit counters suffice for its bounded work.

**Unpruned Cython enumeration.** A separate mode visits all q^q complete tables and
tests the derivative definition directly. It does not call the incremental
filter or prune prefixes. This provides a full dimension-three check independent
of both pruning implementations. Only traversal/output plumbing is shared with
the optimized Cython mode; the Sage reference is separate code.

## Verification and output

For every function in dimensions 1 and 2, the script compares a literal Sage
vector-space predicate, the integer derivative predicate, and the four-point
predicate. It also compares the reference search with that full enumeration.
These finite checks do not replace the mathematical argument for arbitrary n.

For each requested dimension, the reference counts APN functions and the
bijective subset. With Cython enabled, both compiled modes must produce exactly the same
serialized truth tables as the reference, byte for byte and in the same order.
Serialization is one byte per output, q bytes per table, without separators.
Strictly increasing tables establish absence of duplicates. The run record
stores SHA-256 hashes so future runs can compare outputs without storing them.

The Cython incremental and reference searches must also match per-depth statistics:
`attempted[d]` counts values considered at position d, `accepted[d]` counts
refinements passing the APN constraint, and `rejected[d]` counts failures.
The root is not counted as a refinement. An accepted leaf is a complete APN
function. These statistics are deterministic, unlike runtime measurements.

Expected values are attributed in [apn-counts.json](../data/apn-counts.json).
The search algorithms neither read nor use those values. The runner compares
computed results against them only after enumeration.

## Source discrepancy

The thesis, printed page 33, Example 4.7 (PDF page 39), says **668128** APN
functions in dimension three and **10752** APN permutations. The numeral
668128 was confirmed by visually inspecting the rendered page; it is not a
text-extraction error. Article Table 4 instead gives **688128** APN functions.

All three reconstructed searches produce **688128**, agreeing with the article,
and all produce **10752** permutations. See the
[completed run record](../results/apn-counts.json).
Both printed values remain in the input metadata. This discrepancy concerns
the total number of functions, not the count of equivalence classes. Its
editorial origin and any relationship to the author's recalled recursion bugs
are unknown; do not infer a connection.

## Recorded validation

The Cython migration was checked against the earlier standalone C run: counts,
output hashes, and all incremental search statistics were identical through
n=3. The redundant standalone C source, executable interface, and build-record
helper have been removed from the maintained artifact. The two distinct
compiled algorithms are retained because they supply independent verification.

The recorded Cython run took about 6.3 seconds inside the runner, including
module compilation/loading but excluding Sage startup. Dimension-three kernel
calls including serialized output took about 0.09 seconds (incremental) and
0.27 seconds (unpruned). These are observations, not controlled comparisons or
forecasts for dimension five. Consult the record for exact timings.

`lib/compiled.py` records the Cython version, source and extension hashes, and
Python's compiler configuration. The configuration is not a captured compiler
invocation; the source also requests `-O3`. Sage manages temporary build files.
The reference-only path does not load or compile Cython.

## Limits

This artifact does not reproduce affine, EA, or CCZ classification, stabilizer
orders, dimension-four nonexistence of APN permutations, or larger searches.
The raw search is deliberately not offered for dimensions above three. Later
artifacts will introduce normalization and canonicity filters, each with its
own correctness argument and tests against these small cases.

The direct Sage vector-space checks cover dimensions 1–2 exhaustively, not
all dimension-three functions. The dimension-three exhaustive definition check
is performed in Cython; the independent Sage/Python enumeration uses four-point
pruning. Neither implementation requires access to the original backup data.
