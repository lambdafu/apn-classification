# Dimension-five inputs and classification stages

The seven published representatives are now explicit inputs in
[dimension-five.json](../data/dimension-five.json). Each table contains s(0)
through s(31) as decimal labels in the existing binary-coordinate convention.
The article's Table 3 (printed p. 280, PDF p. 8) was inspected visually; all
224 entries and seven degrees were independently compared with the thesis's
Table 4.5 (printed p. 42, PDF p. 48). Source PDF hashes are recorded in the data.

Run the small input check from `artifacts/`:

```sh
sage -python sage/dimension_five_inputs.sage --output build/dimension-five-inputs.json
```

Ordinary `python3` can also run this entry point. No compiled kernel or
classification search is used. The [completed record](../results/dimension-five-inputs.json)
checks the supplied representatives, not the completeness of the published
classification. Its checks are:

- APN by both direct derivative multiplicities and all affine-plane constraints.
- Zero at zero and the standard basis; distinct tables in lexicographic order.
- Algebraic degree by both a Mobius transform and direct subset sums for ANF
  coefficients. The degrees are 2, 2, 3, 3, 4, 3, 3.
- Absolute Walsh spectra by both direct character sums and a fast Walsh
  transform, with both output-mask conventions. The fast transform also checks
  Parseval's identity; zero-function spectra provide an analytic test case.

The data also transcribe the published power-function correspondences, CCZ
class assignments, and EA stabilizer orders. Those are **verification targets**,
not results established by this input check. The separate
[power and trace-family experiment](power-correspondences.md) now supplies
explicit finite-field representations and verified EA transformations.

## Walsh convention discrepancy

Article §5, p. 280 defines the extended Walsh spectrum with nonzero output mask
b. There are then 32*31=992 coefficients. Its printed multiplicities instead
sum to 1024 and agree with including b=0. Both are recorded explicitly:

| Representatives | All a,b (printed multiplicities) | All a, nonzero b (printed definition) |
| --- | --- | --- |
| 1, 2, 3, 4, 6, 7 | (0:527), (8:496), (32:1) | (0:496), (8:496) |
| 5 | (0:217), (4:465), (8:310), (12:31), (32:1) | (0:186), (4:465), (8:310), (12:31) |

The b=0 row contributes exactly 31 zeros and one coefficient of magnitude 32,
independently of the function. Thus the convention mismatch does not change
which functions have equal spectra. It does affect a literal comparison of
the formula and multiplicities, so it must not be silently hidden.
The two resulting spectrum groups do not establish all three CCZ classes.

## Completed classification and its evidence

Each stage has a distinct record and scope:

1. **Construction:** the [completed search](../results/ea-candidates-5.json)
   exhausts normalized APN functions with partial affine pruning, singleton
   propagation, and a cutoff of 20. It produces exactly 11,768 weak candidates.
2. **EA reduction:** [exact reduction and certificate replay](ea-reduction.md)
   assign every candidate to one of the seven published representatives.
   Every assignment has a checked map; all 21 representative pairs receive
   completed exact negative tests. Each representative is the first candidate
   in its class. The search coverage argument then establishes global EA
   minimality and completeness.
3. **CCZ classification:** the [CCZ experiment](ccz-stabilizers.md) supplies
   checked graph witnesses and exact negative distinctions for the blocks
   {1,3,7}, {2,4,6}, {5}. Combined with EA coverage, these are all three
   dimension-five CCZ classes. The standard Sage row-1/row-2 negative test
   also completed; its narrower record is retained separately.
4. **Stabilizers and total:** the same group experiment computes full EA
   stabilizers of orders 4960,4960,160,160,155,155,155. Summing their distinct
   orbit sizes, with the completed coverage argument, gives
   110823678910407691468800 APN functions. This uses the explicitly documented
   modern group-intersection method. The separate
   [historical Algorithm 3 reconstruction](historical-stabilizers.md) now
   computes the same full groups by recursive search and reproduces the orbit
   total, including the exact Note 9 generator sequence.
5. **Power and family identifications:** the
   [field-function experiment](power-correspondences.md) checks all APN power
   exponents and the two trace-family instances. Exactly five of the seven
   EA classes contain powers; the remaining two contain the article's
   equation (6) instances.

The supplied-input checks retain their original limited scope. They do not
individually establish completeness; that conclusion combines the completed
construction, sound pruning, exact reduction, and pairwise inequivalence.

## Remaining historical accounting

The article's p. 279 footnote reports rejection of 11,760 out of
11,768 candidates, followed by five remaining candidates; subtraction gives
eight, and the final EA class count is seven. These historical stage counts
remain unresolved source accounting. The maintained reduction assigns every
candidate explicitly and does not claim to reconstruct the missing intermediate
filter or to resolve the footnote's accounting.

The original search output and logs remain preserved. The separate
self-equivalence and Algorithm 3 reconstruction did not repeat or modify the
completed APN construction or candidate reduction.
