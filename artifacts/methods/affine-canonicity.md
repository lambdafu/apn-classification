# Affine canonicity and dimension-four classification

Run `make canonicity` from `artifacts/`. This uses the readable Python/Sage
path; compiled acceleration is unnecessary at this scale. The entry point is
[affine_canonicity.sage](../sage/affine_canonicity.sage), and the completed
evidence is [affine-canonicity.json](../results/affine-canonicity.json).
The [candidate tables](../results/dimension-four-weak-ea-candidates.txt) are
also available separately, one function per line with decimal values at inputs
0 through 15. Lines starting with `#` describe the format and discrepancy.
The command regenerates this file beside its JSON output and records its hash.

The run reconstructs the two dimension-four EA classes, with exactly the
published representatives and degrees, and the APN permutation classification
in dimensions three and four. **The intermediate candidate count is not yet
historically reproduced:** the current affine filter gives 15, whereas both
publications report 16. This discrepancy does not disappear in the final
classification record; it is recorded explicitly alongside the successful
class calculation. No cause has been established.

The article states 16 explicitly on printed page 279 in the paragraph above
Theorem 5. Footnote 1 on that page gives the consistent accounting: 14 rejected
and 2 remaining. The reconstruction currently has 15 candidates, of which 13
are nonminimal in their EA classes and 2 are the final representatives.

## Partial comparisons and the nested search

[affine_canonicity.py](../lib/affine_canonicity.py) reconstructs thesis §4.2.2,
using the independently tested immutable affine refinement operations. A
prefix fixes `s(0), ..., s(k-1)`; other values are unknown. For a given affine
input permutation alpha and output permutation beta, compare

```text
beta(s(alpha(d)))   with   s(d),   d = 0,1,...,k-1.
```

Stop at the first difference. A smaller output is a rejection witness; a
larger output cannot reject this prefix. If `alpha(d)` is outside the defined
prefix before finding a difference, this transformation is inconclusive.
Never skip an unknown position and compare a later one.

The filter also accepts templates with holes: any defined S-box position can
be an image under alpha, including positions beyond the first hole. Comparison
stops at an unknown on either side. The prefix-only experiment here retains its
original search; the separate [propagated search](apn-propagation.md) uses this
more general interface and verifies it against complete affine actions.

The two mutually recursive stages determine alpha(d), then beta at the
dependent position `s(alpha(d))`. A determined entry bypasses guessing. A new
assignment is propagated across its affine hull, subject to injectivity. Only
defined S-box positions are relevant input guesses, and only output values at
most s(d) can lead to a lexicographically smaller result while previous
positions are equal. A witness is completed to two affine permutations before
returning it to the caller.

Soundness follows because every value through the first strict inequality is
fixed in the prefix and in the two affine templates. All completions of s keep
that strict inequality under the completed transformations. Exhaustiveness
for this partial-comparison test follows by following any witnessing pair:
every required input guess and output guess appears in its loop, forced affine
values agree, and no injective witnessing map is discarded. At a complete s,
there are no unknown values, so this is an exact affine canonicity test.

The outer search uses independent plane constraints for APN filtering, followed
by this test at every depth. There is no cutoff, timeout, restart, or manually
skipped subtree. The reference retains recursive control flow and immutable
state. The separate compiled experiment uses mutable masked buffers and
propagation; this experiment remains the prefix-only reference.

## From normalized candidates to EA classes

For the weak EA search, constrain s to vanish at zero and the standard basis
vectors, as in thesis §4.2.4. Every EA class has a minimum in the integer-table
lexicographic order. That minimum must vanish on this basis: otherwise an
affine correction removes its first nonzero basis value while preserving the
earlier zeros, producing a smaller function. It must also be affine canonical,
since affine equivalence is contained in EA equivalence. The sound APN and
affine-prefix filters therefore cannot discard an EA minimum.

The complete dimension-four search produces 15 candidates. For every candidate
the runner checks APN by derivatives and checks full affine canonicity again
by enumerating all 322,560 affine input permutations. For each input map, a
separate greedy output minimization translates the first output to zero and
maps successive independent output differences to the least available basis
images. This enumerates full input maps, without using the recursive template
filter. It confirms that the survivors are affine canonical; completeness of
the candidate search rests on the pruning argument above, not on survivor
checks alone.

[ea_equivalence.py](../lib/ea_equivalence.py) implements the three-template
equivalence search described in thesis §4.2.4:

```text
target(x) = beta(source(alpha(x))) XOR gamma(x).
```

Alpha is affine bijective, beta is linear bijective, and gamma is affine.
Restricting beta to fix zero loses no EA equivalences: its translation can be
absorbed into gamma. At each position equality determines gamma's required
value. When gamma is already determined, it also forces beta's next value.
Refinement checks and propagates these constraints. A completed exact search
can return failure; no timeout is interpreted as inequivalence.

Candidates are processed in lexicographic order and grouped by witnessed EA
equivalence; published representatives are not supplied to the classifier.
There are three candidates in the degree-two class and twelve in the
degree-three class. Every assignment includes full alpha, beta, gamma tables,
validated with Sage matrix arithmetic and the complete transformation equation.
The different degrees prove the two representatives inequivalent. For degrees
at least two, invertible affine substitutions preserve degree and adding an
affine correction cannot alter its highest-degree terms. This argument is not
applied to distinguish degree-zero and degree-one functions.

Coverage of all EA minima, witnessed membership of every candidate, and
inequivalence of the two classes establish the complete dimension-four EA
classification. The least candidate in each class is also its global EA
minimum. The resulting tables agree with thesis Table 4.4 / article Table 2.
The recorded degree is computed by a coordinatewise Mobius transform.

## Independent finite checks

- Enumerate every affine map by Sage matrices in dimensions one and two, and
  compare the resulting affine permutation groups with the independent
  ordered-basis enumerator.
- Compare the prefix filter with all pairs of full affine permutations on
  every prefix: 7 prefixes in dimension one, 341 in dimension two. Validate
  every returned witness. On complete tables, also check the greedy output
  minimization against the full group action.
- Independently partition every function under the complete EA action in
  dimensions one and two. Test the three-template search against every function
  and every oracle class representative: 4 and 512 cases, including failures.
- In dimension three, enumerate all 8! permutations and test APN directly.
  Their set agrees exactly with the full affine orbit of the published
  representative (10,752 functions). The pruned search returns that minimum.
- Complete the pruned permutation search in dimension four; it returns none.
- Complete the normalized dimension-four search and the checks described above.

The first recorded full run took about 14 seconds after Sage startup. All
tables, witnesses, search statistics, source hashes, and the intermediate-count
discrepancy are saved. This is not a reproduction of dimension five, CCZ
classification, the historical candidate list, or stabilizer orders.
