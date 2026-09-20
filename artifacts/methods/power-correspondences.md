# Power functions and trace-family correspondences

This experiment completes the power-function part of thesis Theorem 4.20,
Tables 4.4–4.5, and article Theorem 5, Tables 2–3. It also verifies the three
small-dimensional instances of article equations (5)–(6). It uses the existing
[normalized EA search](ea-reduction.md); it introduces no new equivalence
algorithm and does not reconstruct a historical finite-field driver.

From `artifacts/`:

```sh
make powers
make verify-powers
# Certificate replay also works without Sage or a compiler:
python3 sage/power_correspondences.sage \
  --verify-record results/power-correspondences.json \
  --output build/power-correspondences-python-verification.json
```

The [Sage entry point](../sage/power_correspondences.sage) constructs the
functions using Sage finite fields and finds EA witnesses with the existing
Cython kernel. `--reference` selects the readable normalized EA search;
the full dimension-five reference search can take substantially longer.
The compiled recorded experiment takes approximately four seconds after
startup and kernel loading. It is single-process and needs no cluster.

The [completed record](../results/power-correspondences.json) contains all
32 witnesses, complete source and target tables, explicit field moduli,
source hashes, software versions, and timings. The
[independent replay record](../results/power-correspondences-verification.json)
was generated with ordinary Python.

## Coordinates and arithmetic

Integer bit i denotes the coefficient of z^i in the polynomial basis. Use
GF(16) with modulus z^4+z+1 and GF(32) with modulus z^5+z^2+1. Sage verifies
irreducibility. A separate [integer implementation](../lib/field_functions.py)
uses XOR, polynomial multiplication and reduction; every field product is
compared with Sage, as are every power and family table used in the run.
Changing the field basis changes the printed tables but only conjugates
the relevant maps by invertible binary linear transformations.

For each saved source P and published target T the certificate satisfies

```text
T(x) = beta(P(alpha(x))) XOR gamma(x).
```

Replay reconstructs P from the formula using integer arithmetic. It checks
that alpha is an affine permutation, beta a linear permutation, gamma affine,
and the equation holds at every input. Both the derivative and affine-plane
APN predicates are checked on every assigned source. Replay does not invoke
Sage, the Cython kernel, or an equivalence search.
The generation run also redoes all five dimension-four searches with the
readable Python EA routine and checks those returned maps independently.

## Exhausting power functions

For positive d, the function x^d depends on d modulo q-1 for x nonzero,
and always takes zero to zero. Thus d=1,...,q-1 exhausts all positive power
functions, including the residue-zero exponent q-1. Exponent zero under the
constant-polynomial convention is constant and is not APN here. Coefficients
c*x^d add no nonzero-coefficient EA classes, since multiplication by c is an
invertible binary linear output map. The zero coefficient is also constant.

The two APN predicates agree for every tested exponent. Every APN power
receives a verified assignment:

| Dimension | Published EA row | APN exponents |
| ---: | ---: | --- |
| 4 | 1 | 3, 6, 9, 12 |
| 5 | 1 | 5, 9, 10, 18, 20 |
| 5 | 2 | 3, 6, 12, 17, 24 |
| 5 | 5 | 15, 23, 27, 29, 30 |
| 5 | 6 | 11, 13, 21, 22, 26 |
| 5 | 7 | 7, 14, 19, 25, 28 |

In particular, the specific published correspondences are x^3 in n=4,
and x^5, x^3, x^15, x^11, x^7 for n=5 rows 1,2,5,6,7.

The negative statement uses separate evidence: the published representatives
are pairwise EA inequivalent, established by the completed n=4 classification
and the [n=5 exact pair tests](ea-reduction.md). Since every APN power has
been assigned to the listed rows, the remaining rows cannot contain a power
function. APN is preserved by EA equivalence, so non-APN powers cannot supply
an omitted example. The replay checks positive certificates and exponent
coverage; it does **not** re-execute those separately recorded negative tests.

## Trace-family instances

With Tr the absolute field trace, the article specifies

```text
n=4, i=1:   x^(2^i+1) + (x^(2^i)+x+1) Tr(x^(2^i+1)),
n=5, i=1,2: x^(2^i+1) + (x^(2^i)+x)   Tr(x^(2^i+1)+x).
```

These formulas were checked visually against article printed p. 279,
equations (5)–(6). No publisher page image is bundled with the artifact.
The certificates identify the n=4 instance with row 2, and the n=5
instances i=1 and i=2 with rows 4 and 3 respectively. This verifies the
three finite instances and their EA correspondences, not the cited general
infinite-family theorems.
