# Langevin's dimension-five APN classification

An independent reconstruction of Philippe Langevin's
[July 2011 experiment](https://langevin.univ-tln.fr/project/apn-5/apn-5.html)
(page last modified 29 March 2012). This project builds output components,
whereas the earlier reproduction in `../artifacts/` builds function values.
The original APN representative lists do not supply search candidates here.

The completed run reproduces **every published intermediate count** and all
three final CCZ classes in about **10 minutes 26 seconds** on the development
machine. [Saved records and verification scope](CLAIMS.md) are included.

The implementation is newly written Sage/Python and Cython. Langevin's two
linked input datasets are retained unchanged in `data/`; his seven original
programs are not linked on that page. The mathematical extension and covering
strategy is reconstructed, with explicit implementation differences in
[the method notes](methods/component-covering.md). In particular, the current
two-component solver uses constraint backtracking rather than dancing links,
and code equivalence uses Sage's Bliss graph backend.

## Run

With SageMath and a C compiler, from this directory:

```sh
make check
make reproduce
make verify
```

The main run writes `build/run/level1.json` through `level5.json` and a progress
log at `build/run.log`. Each three-component parent has a checkpoint in
`build/run/level3-parts/`. Repeat the command after interruption to reuse
completed stages and parents; the unfinished parent is recomputed. Checkpoints
require the same source hashes. Use a new output directory after source changes.

```sh
sage -python sage/reproduce.sage --output-dir build/my-run
tail -f build/run.log
```

`--through-level 1`, `2`, `3`, or `4` stops at the corresponding completed stage.
The default runs through level five. For a final comparison with the seven
published EA representatives, without using them during construction:

```sh
sage -python sage/verify.sage --records results --compare-artifacts
```

`results/` contains inspected completed evidence; routine runs write to `build/`.
See the [claim ledger](CLAIMS.md) for results and the scope of certificate replay.

## Files

- `lib/components.py`: readable integer reference operations and completion solvers.
- `cython/extensions.pyx`: Walsh transforms, stabilizer-orbit reduction, derivative
  capacity filtering and two-component feasibility search.
- `lib/code_equivalence.py`: exact code comparison with checked coordinate permutations.
- `sage/reproduce.sage`: staged enumeration and checkpoints.
- `sage/check_algorithms.sage`: finite exhaustive checks against reference algorithms.
- `sage/verify.sage`: certificate and recorded-count replay.
- `data/expected.json`: source URLs, dates and expected intermediate counts.

An integer word stores a Boolean truth table: bit `x` is the value at input `x`.
Input variable `a` is the least significant input bit. In a component list,
the first word is the least significant output coordinate.
