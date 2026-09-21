# Reproducing the APN classification

This directory is the research artifact: readable SageMath experiments,
optional Cython acceleration, explicit inputs, and evidence for Marcus
Brinkmann's 2007 diploma thesis and the 2008 Brinkmann–Leander article.
It is being built in stages. Start with the [claim ledger](CLAIMS.md).
The [2019 catalogue reproduction](methods/ea-ccz-catalogue-2019.md) extends
the scope to all vectorial Boolean functions through dimension four.
The [repository README](../README.md#sources) links the included diploma thesis
and the publisher reference for the article; the Springer PDF is not bundled.

The [algorithm provenance audit](methods/provenance.md) distinguishes historical
reconstruction from independent checks and modern replacements. In particular,
the supplied-table CCZ/stabilizer experiment uses modern methods. The separate
[Algorithm 3 and Note 9 reconstruction](methods/historical-stabilizers.md)
now supplies recursive generator discovery and the published orbit pruning.
An optional [historical C snapshot](historic/README.md) preserves a related
original counting program, its dependencies, and the surviving compiler flags.

## Run the experiments

Requirements: SageMath and Make. `make reproduce` also needs a working C
compiler for Sage's Cython integration. The recorded runs use SageMath 10.6
and Cython 3.0.11. No Magma, network access, private backups, or external
datasets are needed.

From this directory:

```sh
make reference    # Readable small-dimensional APN enumeration, no compilation
make reproduce    # Compare it with two independent Cython algorithms
make planes       # Plane counts; all input subsets through dimension four
make refinement   # Affine templates checked against Sage matrix enumeration
make canonicity   # Nested affine/EA searches; dimension-four classification
make permutations5-from-ea # Five affine APN permutation classes from complete EA coverage
make verify-permutations5 # Replay 67 correction assignments and 10 power/inverse witnesses
make permutations5 # Direct permutation-tree search; completed records at cutoffs 14 and 16
make verify-permutations5-direct # Replay both saved direct-search records
make candidates5  # Compiled dimension-five weak EA search; potentially long
make reduce5 WORKERS=8  # Exact reduction of the saved 11,768 candidates
make verify-reduction5 # Replay every saved EA assignment certificate
make powers      # Power functions and trace-family EA witnesses in n=4,5
make verify-powers # Replay their saved certificates (no search)
make historical-stabilizers # Algorithm 3 and Note 9, n=4,5 (several minutes)
make verify-historical-stabilizers # Replay generator certificates and orbit totals
make catalogue2019 # All EA/CCZ classes through dimension four
make verify-catalogue2019 # Replay witnesses and compare archived Magma results
```

`make` defaults to `make reproduce`. Use `make SAGE=/path/to/sage ...` to select
an installation. Each target writes a completed JSON record under `build/`.
Selected completed runs are retained under `results/`. Later stages consume
explicitly documented records and candidate lists from that directory; a new
run writes to `build/` without replacing the retained evidence.
Methods, scope, and recorded evidence are linked in the ledger.

The baseline compares every accepted table, in order, across an immutable
plane-based reference, incremental difference-table backtracking, and an
unpruned derivative-definition enumeration. The latter visits all 8^8
functions in dimension three. Expected totals:

| Dimension | APN functions | APN permutations |
| --- | ---: | ---: |
| 1 | 4 | 2 |
| 2 | 192 | 0 |
| 3 | 688128 | 10752 |

See [the baseline method](methods/apn-counts.md) for the different total printed
in the thesis. These are complete function counts, not equivalence classes.
For a smaller comparison:

```sh
sage sage/apn_counts.sage --max-dimension 2 --cython --output build/small.json
```

The Sage entry points also support `sage -python`. Cython compilation is
handled by Sage; there is no separate executable protocol or maintained
standalone C version. The two compiled algorithms retain their independent
checks. Their readable reference remains separate code.

`make canonicity` reconstructs the nested template searches, verifies the
small cases independently, and reproduces the two dimension-four EA classes
and their exact representatives. **Its weak candidate count is 15, whereas
both publications report 16.** That historical intermediate stage remains
unresolved. See [the method and discrepancy](methods/affine-canonicity.md).
The [standalone candidate list](results/dimension-four-weak-ea-candidates.txt)
contains the 15 computed tables, one per line. `make canonicity` regenerates
it under `build/`, alongside the run record and its checksum.
The same run reproduces one affine APN permutation class in dimension three
and none in dimension four. It currently needs no compiled acceleration.

The [dimension-five experiment](methods/ea-candidates.md) uses a compiled
version of the recursive search, first verified against the dimension-four
reference. It compares the completed count with the published 11,768 and
exports its candidate tables separately. The [completed record](results/ea-candidates-5.json)
now confirms exactly 11,768 candidates; its tables and full log are preserved
in `results/`. Progress alone is not a completed result.
Use `make candidates5 CUTOFF=20` to skip affine tests at defined depths 20–31
and restore them at 32 known entries. [APN propagation](methods/apn-propagation.md)
now fills forced later positions and exposes them to the affine filter. Cutoff
counts known entries after propagation; the log shows the full template with
`None` for unknown positions. Omitting `CUTOFF` checks after every successful
extension and closure. The setting 20 came from Marcus's comparison before
propagation was added. Use `--no-propagation` on the Sage entry point to compare
with that earlier search. The method records the conventions and validation.

The [seven published dimension-five inputs](data/dimension-five.json) are
transcribed and independently checked for APN, normalization, degrees, and
Walsh spectra. The [input verification and completed classification stages](methods/dimension-five.md)
separate the small supplied-input checks from the full classification and record
a Walsh-spectrum convention mismatch in the article.

The [CCZ and EA-stabilizer experiment](methods/ccz-stabilizers.md) is a modern
independent verification: Bliss canonicalizes spanning-codeword incidence
graphs for CCZ, and code automorphism groups intersected with affine input
permutations give EA stabilizers. It reproduces the supplied representatives' CCZ
partition, all nine published n=4,5 EA stabilizer orders, and explicit witness
maps. Run `sage -python sage/ccz_stabilizers.sage --output build/ccz-stabilizers.json`.
The separate [historical reconstruction](methods/historical-stabilizers.md)
recovers all nine stabilizers by recursive three-template search. It discovers
exactly the three Note 9 generators, in order, starting from the identity, and
constructs the filter from just the known generators fixing earlier positions.
The method includes a short command for running only that example. The full
record took about 6½ minutes; the readable n=4 run took about four seconds.
Both have completed certificate replays. The author abandoned the direct CCZ
approach; it remains historical context, not required reconstruction.
The [completed EA reduction](methods/ea-reduction.md) now assigns all 11,768
saved candidates to the seven published representatives, with checked maps
and all 21 exact pairwise inequivalence tests. This supplies the coverage step
for the existing CCZ classification and orbit total. It does not reconstruct
the historical stabilizer algorithm. The
[power and trace-family experiment](methods/power-correspondences.md) now
supplies 32 checked EA transformations and exhausts all power exponents in
dimensions four and five. Its saved certificates can also be replayed with
ordinary Python.

The standard Sage code-equivalence call also completes the remaining n=5
row-1/row-2 inequivalence test in about **83 seconds**. Run
`sage -python sage/ccz_standard_pair.sage --cpu-limit 300 --output build/ccz-standard-pair-300s.json`;
the [completed record](results/ccz-standard-pair.json) is retained separately.
This probe uses no graph canonicalization. Walsh separation and the positive
equivalence witnesses handle the other distinctions among the supplied tables.

## What belongs here

```text
artifacts/
  CLAIMS.md                  Claims, source locations, status, commands
  methods/                   Definitions, algorithms, correctness, limitations
  sage/                      Readable Sage entry points
  lib/                       Mathematical code and optional kernel loader
  cython/                    Optional typed recursive kernels
  data/                      Small inputs and attributed expected values
  results/                   Selected completed run records
  build/                     Local generated files and new records (ignored)
```

Each implemented experiment supplies:

1. A precise statement and source location, including discrepancies.
2. Exact inputs and conventions, mathematical justification, and limits.
3. Reproduction commands and expected resource scale.
4. Appropriate evidence: witnesses, exhaustive coverage, independent checks,
   or explicitly bounded numerical illustrations.
5. A machine-readable record with configuration, software versions, source
   hashes, results, completion status, and timings. Compiled runs additionally
   record Cython and extension provenance.

A script that merely invokes compiled code is not an independent reference.
Use distinct mathematical checks where feasible. The baseline's largest
serialized output is about 5.5 MB per method; full table lists are not saved.

A run replaces its output record only after the documented checks pass.
Failure may leave an older record in place: inspect exit status, configuration,
source hashes, and any explicitly recorded unresolved publication claims.
Timings describe the recorded machine, not guaranteed performance.

## Scope

The first iteration reconstructs the original effective single-CPU methods,
with readable mathematics and verification. It covers the thesis first, then
the article's extensions. Recursive control flow is part of this reconstruction.
Parallel search, explicit search frames, checkpointing, and the later distributed
experiments are deferred; their motivation belongs in the retrospective.
Dimension four is the complete practical verification case before dimension
five. Raw 16^16 enumeration is not required.

Original backup directories are private evidence and are not bundled here.
The artifact should remain runnable independently of them.
