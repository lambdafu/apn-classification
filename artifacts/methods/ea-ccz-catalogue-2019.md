# All EA and CCZ classes through dimension four

This experiment reproduces the finite tables of Marcus Brinkmann,
[*Extended Affine and CCZ Equivalence up to Dimension 4*, ePrint 2019/316](https://eprint.iacr.org/2019/316).
It checks all functions' classes, not only APN classes. The published
[repository](https://github.com/lambdafu/ext-affine-and-ccz-classes-up-to-dim-4)
is pinned at commit `b44f031ed121ab198354010b07c924e8504bca6f`.

From `artifacts/`:

```sh
make catalogue2019
make verify-catalogue2019
# Entire readable experiment through dimension three:
sage -python sage/ea_ccz_catalogue.sage --reference --max-dimension 3 \
  --output build/ea-ccz-catalogue-2019-reference3.json
```

The [completed result](../results/ea-ccz-catalogue-2019.json) and
[certificate replay](../results/ea-ccz-catalogue-2019-verification.json) give:

| Dimension | EA classes | CCZ classes | EA classes containing permutations | Distinct orbit sizes | Distinct Walsh spectra | Sum of EA orbit sizes |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 1 | 1 | 1 | 1 | 4 |
| 2 | 2 | 2 | 1 | 2 | 2 | 256 |
| 3 | 7 | 7 | 4 | 7 | 7 | 16777216 |
| 4 | 4713 | 4151 | 194 | 71 | 481 | 18446744073709551616 |

Every published representative is checked to be its **global lexicographic
EA minimum**. Every stabilizer order, degree, Walsh spectrum, permutation flag,
and EA-to-CCZ assignment agrees. Distinct EA minima and the exact orbit sum
`(2^n)^(2^n)` prove exhaustiveness; the input list is not assumed complete.
The full recorded run took 44.559 seconds after interpreter startup, including
small reference checks. This is a development-machine measurement, not a
comparison with the archived Magma hardware or identical workloads.

## Provenance and scope

This is **independent verification of the published catalogue**, rather than
a reconstruction of its original depth-first construction of all functions.
It uses full affine-input enumeration and greedy output normalization, with
a [readable Python implementation](../lib/ea_catalogue.py) and optional
[Cython acceleration](../cython/ea_catalogue.pyx). It does not apply the APN
predicate or assume full output rank. CCZ classification reuses the already
documented exact code/Bliss backend from [the APN verification](ccz-stabilizers.md).

The [attributed input JSON](../data/ea-ccz-2019.json) contains the tables,
expected properties, pinned revision, and hashes of upstream source files.
[The importer](../sage/import_ea_ccz_2019.py) reads the paper's TeX tables and
checks them against the raw datasets; it does not execute the old Python 2
formatter. Repeat the import from a checkout of the pinned revision with:

```sh
python3 sage/import_ea_ccz_2019.py /path/to/upstream-checkout \
  --output build/ea-ccz-2019-import.json
```

Normal reproduction uses the included JSON and needs no network or private
backup. All 16 shared raw text datasets in the author's
`apn-4/ea-and-ccz-classes/` match the uploaded files byte for byte. The older
`apn-data/ccz-classes/EA-4-sizes.txt` is a different snapshot; the published
version is the input for this verification.

On 20 September 2026, Marcus Brinkmann recalled using direct permutation
search in 2006/2007 and the linear-addition trick in 2019. The saved
`apn-4/ea-and-ccz-classes/EA-4-bijective.txt` supports the latter method:
each of its 194 positive cases contains tables s, L and s+L. All 194 were
checked to have linear L and bijective s+L. This establishes the use of
linear addition in the surviving data; the 2019 dating is the author's
recollection. The current correction search reconstructs that mathematical
approach, with newly written enumeration and verification code.

The [historical Magma package](../historic/magma/README.md) preserves the
code-equivalence scripts, input files and completed output log. Its 4,713
dimension-four inputs and CCZ assignments agree with the paper; the final
list has 4,151 representatives. The [audit](../results/historical-magma-data-audit.json)
distinguishes comparing old output from running Magma anew. The log reports
Magma V2.11-2 on 16 March 2008, 33723.769 seconds and 43.28 MB. It does not
identify the hardware. That 2008 date concerns the CCZ computation and does
not date the later permutation tests. No Magma license is used for the new
reproduction.

## EA minimality by full affine-input enumeration

All supplied tables s vanish at zero and the standard basis. For each affine
input permutation alpha, subtract the unique affine interpolation ell of
`s(alpha(x))` on that basis, giving `u(x)=s(alpha(x)) XOR ell(x)`.

Any EA minimum must vanish on this basis: an affine correction can remove its
first nonzero basis value without changing earlier values. Thus it suffices
to consider normalized tables beta(u), for every invertible linear beta and
every affine input alpha.

For fixed u, find the least beta-image greedily. The first output outside
the span already encountered is mapped to the least unused independent image,
`2^r` when that span has rank r. Extend linearly on the enlarged span;
dependent outputs are forced. Every injective map on a subspace extends to
an invertible linear map on the full space, so this produces the least table.
Compare it with s, stopping at the first difference. Any smaller image rejects
canonicity; otherwise enumerate the remaining alpha.

The compiled code enumerates ordered input bases and all translations, exactly
`q * product(q-2^i, i=0..n-1)` maps (322,560 for n=4). It checks that count for
each accepted row. The Python reference constructs each complete map and
normalized table explicitly.

## Rank-deficient stabilizers and completeness

Let s be a checked normalized EA minimum and r the rank of its image.
An affine input alpha occurs in a self-equivalence exactly when the least
linear output image of its normalized u equals s. Count these alpha to obtain
the input projection order H.

For each such alpha, beta is fixed on the r-dimensional image span of u by
beta(u)=s. The number of invertible linear extensions to the full output is
`K=product(q-2^i, i=r..n-1)`: extend a basis of that span to a full basis,
choosing each new image outside the preceding images' span. For each extension
gamma is uniquely fixed by the affine interpolation. Hence the **full EA
stabilizer has order H*K**. This also handles the zero function: in n=4 its
stabilizer has order `322560*20160=6502809600`.

Divide the action-group order `q * |GL(n,2)|^2 * q^(n+1)` by H*K for the orbit
size. The distinct verified EA minima represent disjoint orbits. Their sizes
sum to the cardinality of the entire function space, proving that no EA class
is missing. This coverage argument replaces a new traversal of all `16^16`
functions; it does not claim that such a traversal was performed here.

## Classes containing permutations

It suffices to seek a linear L such that s+L is bijective. If beta(s(alpha))+gamma
is bijective, composing with the inverses of alpha and beta produces s+ell
bijective for affine ell. Removing ell's constant term preserves injectivity.
The converse is immediate.

Enumerate all linear maps by their n arbitrary output columns (not necessarily
independent). The readable reference checks all q^n maps. The compiled version
assigns one column at a time and rejects a branch if two determined values of
s+L coincide. Every completion preserves that collision, so the pruning is
exact. Positive cases retain L; negative cases exhaust the search. Replay
checks all 200 positive witnesses through n=4, including 194 in dimension four.

## CCZ classes, invariants and verification

The code-equivalence backend processes EA minima lexicographically and retains
the first representative of each CCZ class. It checks every positive coordinate
permutation and its invertible affine lift on function graphs. There are 562
nontrivial witnesses in n=4. Complete canonical graphs make the decisions;
fingerprints only index buckets. Full EA coverage means that the smallest EA
minimum in each CCZ group is its global CCZ minimum. All row labels agree with
the publication.

Degree is computed independently by Mobius transform and subset sums. The
affine class is labelled degree 1 by the paper's convention. Walsh multiplicities
exclude b=0 and are checked by direct sums and a fast transform. Uploaded raw
spectra include b=0; the importer removes q-1 zeros and one coefficient of
magnitude q to match the printed tables.

Finite checks compare native EA minima and orbit sizes against the full EA
action in n=1,2, and all seven n=3 representatives against Python full-map
enumeration and brute-force linear corrections. A separate
[readable n<=3 run](../results/ea-ccz-catalogue-2019-reference3.json) repeats the
small catalogue without Cython. Replay checks source hashes, positive witnesses,
properties and arithmetic; it does **not** repeat negative searches or EA
minimality. Rerun the main experiment for those obligations.

The methodology sentence “CCZ equivalence implies EA equivalence” reverses the
implication. The valid statement used here, consistent with the introduction
and the paper's merging of EA classes, is **EA implies CCZ**. This textual
discrepancy does not affect the verified tables.
