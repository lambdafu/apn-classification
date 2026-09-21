# Component extension and exhaustive coverage

This reconstructs [Langevin's dimension-five experiment](https://langevin.univ-tln.fr/project/apn-5/apn-5.html).
The implementation builds Boolean output coordinates, quotients by affine and
already chosen components, and reduces partial maps by binary code equivalence.
It does not prescribe a lexicographically minimal full function table.

## The objects being extended

Put `q=2^n` and let `R=RM(1,n)` be the subspace of binary truth tables of affine
Boolean functions. For components `f_1,...,f_k`, retain the code

```
C_k = R + span(f_1,...,f_k) <= F_2^q.
```

The coordinates of this code are the input points. Appending a component adds
one row. Adding a word of `C_k` to the new row does not change the enlarged
code, so extensions are enumerated in `F_2^q/C_k`. Reduced row echelon form
with lowest-bit pivots supplies a complement: new rows vanish at all pivots.
With independent components modulo `R`, its dimension is `q-(n+1+k)`.
In dimension five this is 25, 24 and 23 at levels one, two and three.

There is no loss from using independent components in this dimension. If an
APN (5,5)-function had a nonzero affine component, an EA transformation would
make that component zero, giving an APN (5,4)-map. Each nonzero derivative
would then take every output value exactly twice. Every nonzero Boolean
component would have balanced derivatives in all nonzero directions, hence
Walsh coefficients of squared magnitude 32, impossible for integer Walsh
coefficients. This also rules out premature APN completion at lower levels.

## Unresolved affine planes and the extension inequality

An affine plane here is an unordered four-point set `P` with XOR of its input
points zero. For a Boolean word `b`, define

```
chi_P(b) = (-1)^(sum_{x in P} b(x)).
```

Let `U_k` contain the planes on which all chosen components sum to zero, and
put `N=|U_k|`. These are the APN conflicts that remaining components must resolve.
For `r=n-k` missing components, a valid completion requires a nonzero vector
of their parities on every `P in U_k`.

For any nonzero parity vector `v in F_2^r`, character orthogonality gives

```
sum_{u in F_2^r, u != 0} (-1)^(u dot v) = -1.
```

Summing over `U_k` shows that some nonzero combination `b` of the remaining
components must satisfy

```
(2^r - 1) * sum_{P in U_k} chi_P(b) <= -N.
```

One may choose that combination as the next output coordinate. The test is
necessary for at least one extension direction of every completion; it is
not a promise that every accepted component is extendable. The implementation
uses integer multiplication to avoid rounding a negative rational threshold.

The webpage prints a positive right-hand threshold. That sign is inconsistent
with the averaging argument and with its linked seed list. Among the 48
Boolean classes, the negative threshold selects exactly the six linked seeds;
the printed positive threshold selects 26. The negative rule is implemented
and this correction is recorded in `L-SIGN-001`. The printed quotient-dimension
expression also differs from `q-(n+1+k)`; the latter follows directly from the
rank of `C_k` and is checked by the implementation's echelon bases.

The fast Walsh transform evaluates the character sum for every quotient word.
Each unresolved plane gives a character mask on the free coordinates; its
multiplicity is accumulated before the transform. In these dimensions the
absolute value of every intermediate coefficient is bounded by 1,240, so
signed 16-bit buffers suffice. The reference computes character sums directly.

## The starting list is checked, not assumed complete

Langevin's `class-2-5.txt` supplies 48 Boolean representatives modulo affine
addition, with affine-input stabilizers. We independently compute equivalence
and stabilizers of the pairs `(C_1,R)`. Marking `R` restricts coordinate
permutations to the affine group on the input points. The 48 pairs are distinct,
the computed stabilizer orders match the data, and their orbit sizes sum to

```
sum |AGL(5,2)| / |Stab(f+R)| = 2^26,
|AGL(5,2)| = 319979520.
```

Distinct orbits and this exact mass prove coverage of all Boolean truth tables
modulo the six-dimensional affine subspace. The spectral criterion selects six
of these classes. The six tables in `sel-1-5.txt` belong exactly to those classes.
Each supplied affine generator fixes its seed modulo `R`; the generated group
orders equal the independently computed full stabilizer orders.

## Reducing extensions and the covering argument

At level two, the supplied seed stabilizers act linearly on the quotient of
possible new rows. Breadth-first traversal of each generator orbit retains
one word per orbit. Byte lookup tables accelerate the action; this changes
neither the group nor the orbit partition. The character test is invariant
under these generators, which is checked while traversing the orbits.

After filtering, the code-equivalence backend keeps one partial code per
coordinate-permutation class. This reduction is safe even when the permutation
does not preserve the distinguished original copy of `R`: if `p(C_k)=C'_k`,
then any completed code `D` containing `C_k` maps to `p(D)` containing `C'_k`.
The latter again contains the fixed `R`, so it has a function interpretation.
Coordinate permutation preserves the absence of weight-four words in the
dual code, which is the APN plane condition. Thus some extension of the retained
partial representative reaches the same final CCZ class.

Inductively, every full APN code has a path through the retained covering:
choose a component satisfying the averaging bound, move it into the selected
quotient orbit, then replace the enlarged code by its retained equivalent.
This proves coverage rather than merely membership of the output examples.

The implementation's code backend is a modern choice: enumerate codewords,
select whole positive-weight shells until they span, and encode incidence
between selected words and code coordinates in a colored graph. Sage's Bliss
canonical labeling gives a coordinate order. The corresponding reduced code
basis is the exact comparison key. Whole-shell selection is invariant, and
the spanning requirement ensures that graph isomorphism determines the entire
code. Every reported coordinate-permutation witness is checked on full row
spaces. For Boolean seed classification, the affine subcode receives its own
color. No hash fingerprint is used to decide equivalence.

## Capacity and completion filters

For each nonzero input difference `a`, group the `q/2` unordered pairs
`{x,x+a}` by their current output difference. With `r` output bits still
missing, each group can have at most `2^r` pairs, because their completed
differences must be distinct. The derivative-capacity test rejects larger
groups. It reproduces the webpage's counts for its otherwise unspecified
trivial-obstruction filter; no recovery of the original implementation is claimed.

At level three, two output bits remain. The new solver assigns a value in
`F_2^2` at each input, fixes the pivots of `C_3` to zero, and requires nonzero
XOR on every unresolved plane. Three assigned vertices exclude one value at
the fourth; singleton domains propagate. The next branch uses a smallest
remaining domain. A shared permutation of the three nonzero colors is an
invertible linear output change, so first uses of new colors are ordered to
remove this symmetry. Exhausting a search proves nonextendability; a success
retains two complete component words as a positive certificate.

This solver is recursive constraint backtracking, **not a reproduction of
Langevin's dancing-links code**. A separate immutable reference omits the
color-symmetry optimization. Small cases are checked against exhaustive pairs
of quotient words. The positive dimension-five completions are independently
checked with both plane constraints and derivative uniqueness.

At level four, one Boolean component remains. Every unresolved plane requires
parity one, so all completions are obtained from an affine linear system over
`F_2`. Pivot normalization removes affine and existing-component additions.
The final five-component codes are reduced under CCZ equivalence.

## Reproduction and replay have different scopes

The main run enumerates every quotient word required by the covering, and
exhausts every negative two-component search. Completed stage records retain
counts, parent representatives, source hashes and positive code/completion
witnesses. Per-parent checkpoints permit interruption recovery; they are a
new implementation facility, not part of the historical claim.

Certificate replay checks sources, the Boolean orbit mass and selection,
all positive code equivalences, distinct representative codes, all positive
completion witnesses and the published stage counts. It repeats the small
last-component linear systems in full. It does not rerun the much larger
quotient enumeration or the negative two-component searches. Repeating the
main run supplies that separate evidence.

The optional comparison with `../artifacts/data/dimension-five.json` is made
only after independent construction. It checks that the three final codes
give the expected partition of the seven published EA representatives.
Neither that table nor the earlier exhaustive search is a construction input.
