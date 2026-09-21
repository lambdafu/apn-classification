# Five affine classes of APN permutations in dimension five

This reproduces thesis Theorem 4.17 / Table 4.2 and article Theorem 3 / Table 1.
The 160 table entries were transcribed from the article's printed page 279,
including visual inspection, into [permutations-five.json](../data/permutations-five.json).

## Completed classification using the exhaustive EA result

From `artifacts/`:

```sh
make permutations5-from-ea
make verify-permutations5
```

The [completed record](../results/apn-permutations-from-ea-5.json) and
[witness replay](../results/apn-permutations-from-ea-5-verification.json)
reproduce all five exact published affine minima, degrees, power-function
identifications, and inverse relationships. The run took 15.002 seconds,
including finite reference checks and witness searches, after Sage startup.
It uses the retained exhaustive [EA classification](ea-reduction.md).

| Article Table 1 row | Degree | Affine-equivalent power | Affine class of inverse | Article Table 3 EA row |
| ---: | ---: | --- | ---: | ---: |
| 1 | 4 | x^15 | 1 | 5 |
| 2 | 3 | x^11 | 4 | 6 |
| 3 | 3 | x^7 | 5 | 7 |
| 4 | 2 | x^3 | 2 | 2 |
| 5 | 2 | x^5 | 3 | 1 |

The seven normalized EA representatives admit **32, 32, 0, 0, 1, 1, 1** linear
maps L, respectively, such that s+L is bijective. All 67 corrections are
retained with checked affine witnesses mapping to Table 1 representatives.
Ten further witnesses establish the power and inverse correspondences.

### Coverage and method

Every APN permutation f has `f=beta(s compose alpha)+gamma` for a representative
s of the completed seven-class EA classification. Composing with the inverses
of alpha and beta gives an affine-equivalent permutation s+ell for affine ell.
Removing ell's constant term is an output translation, leaving s+L for linear L.
Hence all affine permutation classes occur among the linear corrections of
the seven representatives.

Five arbitrary output columns specify a linear map, giving 32^5 possibilities
per representative. The compiled enumerator extends one column and its span
at a time. It rejects a branch only when two already determined values of
s+L coincide, a collision preserved by every completion. Negative cases
exhaust this search.

The [readable reference](../lib/permutation_corrections.py) explicitly checks
every linear map. The [Cython version](../cython/permutation_corrections.pyx)
is compared with it for all functions in dimensions one and two and all seven
dimension-three EA representatives. Replay independently checks linearity of
every correction and bijectivity of s+L.

Every corrected permutation has an affine witness to one of the five proposed
representatives. Each proposed representative passes the exact complete
recursive affine canonicity test from the already verified
[affine-search implementation](affine-canonicity.md). Distinct global affine
minima are inequivalent. Coverage and witnesses therefore establish exactly
five classes, without assuming that all permutations in an EA class belong
to one affine class.

The [readable affine equivalence search](../lib/affine_equivalence.py) refines
alpha, then forces beta at s(alpha(x)) by equality with the target. Both maps
are injective affine templates. The direct runner checks it against complete
affine-action orbits in dimensions one and two; the completed
[readable dimension-three run](../results/apn-permutations-reference3.json)
retains those checks. Power tables use the binary
polynomial representation from [the field-function checks](power-correspondences.md).

Marcus Brinkmann clarified on 20 September 2026 that his recollection is
**direct permutation search in 2006/2007, then linear addition in 2019**.
The thesis supports the earlier part explicitly: §4.2.3, printed page 39,
specifies the permutation, APN and affine-canonicity filters for Theorem 4.17.
The surviving 2019 catalogue data contain linear-addition witnesses; see
[the catalogue provenance](ea-ccz-catalogue-2019.md#provenance-and-scope).
The date of that later method is recorded as the author's recollection.

This completed dimension-five verification **reapplies the later historical
technique to the earlier result**. It does not reconstruct the original
2006/2007 permutation search. The existing EA construction and coverage
argument are explicit dependencies, with result hashes recorded.
Replay checks 77 positive witnesses, source/dependency hashes, degrees and table
properties. It does not repeat negative correction searches, affine minimality,
or the original EA enumeration. Rerun this experiment for the first two and
the EA experiments for the latter.

## Separate direct permutation-tree search

The historical-style direct search remains runnable:

```sh
make permutations5
# Or choose a separate output and retain the progress log:
sage -python sage/apn_permutations.sage --cutoff 16 \
  --output build/my-apn-permutations-5.json \
  2>&1 | tee build/my-apn-permutations-5.log
```

It uses the existing APN propagation, injectivity filter and recursive affine
canonicity. It does not impose zero-on-basis EA normalization, which would
exclude permutations. Intermediate affine tests are skipped when
`16 <= known entries < 32`; every completed function receives the exact test.
This is the inclusive form of the thesis's “greater than 15” cutoff, with the
reconstructed propagation counting all known entries, including holes.
Unpropagated and propagated runs through n=4 agree with the immutable search.
Use `--reference --dimension 3` or `4`, without the cutoff option, for a small
readable run. The n=5 reference is exposed but may be slow.

Two direct n=5 runs have now completed and were preserved on 21 September 2026.
Both exhaust the search and return the same five exact published affine minima,
independently of the completed EA classification used by the correction route.
Both also pass the runner's small-dimensional reference comparisons and ten
power/inverse witness checks.

| Cutoff | Recorded search seconds | Outer attempts | Affine nodes | APN permutation completions | Rejected by final affine test | Representatives |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 14 | 25615.522 | 44478637955 | 193807286 | 784 | 779 | 5 |
| 16 | 4967.236 | 7921345840 | 2753368016 | 224 | 219 | 5 |

These are elapsed search times from the two runs, not CPU timings or a
controlled performance comparison. Both records identify Sage 10.6, Python
3.12.5 and macOS arm64, with propagation enabled and EA normalization disabled.
The recorded completion times are 21 September 2026 at 05:56:19 UTC for cutoff
14 and 20 September 2026 at 22:34:21 UTC for cutoff 16.

- Cutoff 14: [record](../results/apn-permutations-5-cutoff14.json),
  [progress log](../results/apn-permutations-5-cutoff14.log),
  [certificate replay](../results/apn-permutations-5-cutoff14-verification.json).
  Copied unchanged from the author's `build/my-apn-permutations-5.json` and
  matching `.log`; the record establishes that this run used cutoff 14.
- Cutoff 16: [record](../results/apn-permutations-5-cutoff16.json),
  [progress log](../results/apn-permutations-5-cutoff16.log),
  [certificate replay](../results/apn-permutations-5-cutoff16-verification.json).
  Copied unchanged from `build/apn-permutations-5-cutoff16.json` and matching `.log`.

Both table digests are
`b7b407614a1520e6659dc1ef9b1a6e02fed9fff8af3b3b25ce77a12c28e46638`.
The tables also agree exactly with the independent linear-correction result.
The saved records retain source hashes, work counters and witnesses. Replay
checks those source hashes, the published tables, APN and permutation
properties, degrees and ten affine witnesses; it does not repeat the tree
exhaustion. Run both replays with:

```sh
make verify-permutations5-direct
```

Exploratory runs without a cutoff and with cutoffs 20 and 12 were interrupted
and are not completion evidence. Stopping and resumption remain deferred.
