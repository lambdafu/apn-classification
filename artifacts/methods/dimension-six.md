# Dimension six: correction and deferred reproduction

The 2008 article, §7, printed page 285, states:

> All these classes contain quadratic functions.

This statement is **false**. The new dimension-six CCZ class found by
Brinkmann and Leander contains no quadratic function. The correction concerns
the entire CCZ class, not merely the degree of the displayed representative.

Yves Edel and Alexander Pott, *A new almost perfect nonlinear function which
is not quadratic*, Advances in Mathematics of Communications **3** (2009),
59–81, explicitly credit Brinkmann and Leander's independent discovery of an
equivalent function and correct the quadratic-equivalence claim.
See the [published paper and abstract](https://doi.org/10.3934/amc.2009.3.59)
and [author manuscript](https://www.yvesedel.de/Papers/switch.pdf), particularly
the discussion immediately before §3 and Theorems 7 and 11.

Their obstruction uses the CCZ-invariant **Delta-rank**. Theorem 7 bounds
that rank by `2^(n+1)` for functions CCZ-equivalent to a crooked function;
quadratic APN functions are crooked. Theorem 11 reports Delta-rank **152**
for the new example, exceeding **128** in dimension six. Thus it cannot be
CCZ-equivalent to any quadratic APN function. This is not the Gamma-rank
reported in the original article's Table 5.

The [self-archived article](https://www.nds.ruhr-uni-bochum.de/media/nds/veroeffentlichungen/2019/03/19/apn-self-archive.pdf)
also carries a first-page erratum referring to Edel and Pott. The correction
is therefore part of the subsequent historical record, not a new conclusion
of this reconstruction.

## Ledger treatment

`DIM6-ERRATUM-001` records the published correction, checked against the
literature on 21 September 2026 following the author's clarification.
It is not a completed computational reproduction. `DIM6-001` remains deferred:
the artifact has not yet transcribed and checked all Table 5 inputs, produced
an explicit equivalence witness to Edel–Pott's example, or recomputed the
Delta-rank obstruction. Any later implementation should retain those as
separate checks and distinguish Delta-rank from Gamma-rank.

The original dimension-six search was partial. Neither the fourteen listed
classes nor this correction establishes exhaustive classification in dimension
six. In particular, a search restricted to quadratic functions cannot cover
all dimension-six CCZ classes: the original search already supplied a
counterexample to that restriction.
