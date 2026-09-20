# APN classification: thesis and reproducible artifacts

Research artifacts for Marcus Brinkmann's classification of almost perfect
nonlinear (APN) functions. The maintained reconstruction contains readable
SageMath experiments, optional Cython acceleration, mathematical method notes,
a claim ledger, and completed results with checked equivalence witnesses.

Start with [the artifact documentation](artifacts/README.md) and
[the claim ledger](artifacts/CLAIMS.md). They distinguish historical algorithm
reconstruction, independent checks, modern verification methods and work still
outstanding.

## Sources

- Marcus Brinkmann, *Classification of Almost Perfect Nonlinear Functions up
  to Dimension Five*, diploma thesis, March 2007.
  [Included thesis PDF](<Brinkmann - Classification of Almost Perfect Nonlinear Function.pdf>).
- Marcus Brinkmann and Gregor Leander, *On the classification of APN functions
  up to dimension five*, **Designs, Codes and Cryptography 49** (2008), 273–288.
  [Publisher reference, DOI: 10.1007/s10623-008-9194-6](https://doi.org/10.1007/s10623-008-9194-6).
  The Springer article is referenced here; its PDF is not included in this
  repository, in accordance with the author's copyright restriction.

## Reproduce and verify

SageMath and a C compiler are required for compiled experiments. From
`artifacts/`:

```sh
make reproduce             # Small-dimensional exhaustive baseline
make canonicity            # Dimension-four affine and EA classification
make reduce5 WORKERS=8      # Reduce the saved 11,768 dimension-five candidates
make verify-reduction5     # Replay all saved dimension-five EA witnesses
```

The full dimension-five search need not be repeated to check the saved
reduction. [Its completed output](artifacts/results/ea-candidates-5.json),
[candidate tables](artifacts/results/dimension-5-weak-ea-candidates.txt), and
[EA reduction](artifacts/results/ea-reduction-5.json) are retained. The reduction
recovers the seven published EA representatives and supplies the coverage step
for the separately verified three CCZ classes and orbit total.

See [the reduction method](artifacts/methods/ea-reduction.md) for the exact
algorithm, certificates, finite checks and reproduction commands. This is an
in-progress reconstruction, not a claim that every result or historical
algorithm in the publications has already been reproduced.

## Repository contents

- `artifacts/`: maintained source, methods, attributed inputs and completed
  computational evidence, including the final search logs.
- The diploma thesis PDF.

Build products, Sage-generated Python files, private backup/recovery material,
the Springer PDF and the separate `apn-lab/` project are excluded. The root
ignore rules use an explicit list of included paths to keep private workspace
material out of ordinary Git staging.
