# Historical Magma code-equivalence experiments

The nine `.mgm` files, `CCZ-4-out.txt`, and `EA-cmd.txt` are unmodified copies
from the author's `apn-data/ccz-classes/` backup, included during the September
2026 reconstruction. They relate directly to the data published in
[ePrint 2019/316](https://eprint.iacr.org/2019/316) and its
[repository](https://github.com/lambdafu/ext-affine-and-ccz-classes-up-to-dim-4).

Each `dim-N-ea-class.mgm` loads the corresponding `dim-N-ea.mgm` input tables
and `convertFkt.mgm`. The active `generateExtendedCode` constructs the dual of
the binary row code with columns `(1,x,f(x))`. The final loop tests each input
against already accepted representatives with Magma `IsEquivalent`, retaining
the first representative in each class. Gamma-rank and automorphism-group
calculations are present but disabled. The unused Dillon examples and older
code constructor are preserved as found.

With an appropriate Magma installation, run from this directory, for example:

```text
magma dim-4-ea-class.mgm
```

This reconstruction has **not** rerun Magma or certified compatibility with
current Magma versions. The maintained, license-free reproduction is
`make catalogue2019` from `artifacts/`; its methods are documented separately.

The archived log identifies **Magma V2.11-2, 16 March 2008**, and reports
33723.769 seconds. These are archived observations, not new timings. All 4,713
input tables and all recorded CCZ assignments agree with the published 2019
dataset; the final list has 4,151 representatives. Dimension-two and -three
input tables also agree exactly. Dimension one includes an additional `[0,1]`
identity table, EA-equivalent to the sole published representative `[0,0]`.

Recheck these comparisons without Magma:

```sh
# From artifacts/:
python3 sage/audit_historical_magma.py --output build/historical-magma-data-audit.json
```

`EA-cmd.txt` preserves a command invoking the unrecovered `apn-4` constructor
with `--no-apn --ext-affine --count 1`. It is provenance evidence, not a runnable
build recipe for a program included here. Filenames and leftover comments in
the scripts do not by themselves date every source revision.
