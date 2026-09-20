# Surviving historical C snapshot

This directory preserves one selected source snapshot from Marcus Brinkmann's
private backups, with its dependencies. It accompanies the tested
[Algorithm 3 and Note 9 reconstruction](../../methods/historical-stabilizers.md).
It is not the recovered complete program used for the published experiments.

The following files are copied byte for byte from `apn-3/2019/`:

- `find-affine-aequivalent-allzero-fix-all-16.c~`
- `galois.c`, `galois.h`, and `bitmask.h`
- `Makefile`, preserved here as `Makefile.original`

The folder name `2019` does not establish when each piece of code was written.
The README and working Makefile in this directory were added in September 2026.
The original sources have not been cleaned up or corrected.

## Why the odd filename?

The trailing `~` identifies a surviving editor backup. It matters: the version
without that suffix has lost the affine gamma refinement and restricts the
input map at zero. This backup retains the three-template EA search and the
full EA group-order calculation. We keep its name to identify the exact
surviving variant; `-x c` tells the compiler to treat it as C despite the suffix.
The `16` denotes the 16 input points of dimension four (`#define N 4`).

The recursive functions refine input, output, and affine-correction templates,
using shared value arrays and masks to hide stale entries after backtracking.
The `verify_a` function also preserves handwritten orbit comparisons and
permutation cycles, currently disabled with `#if 0`. Some refer to dimension-five
experiments despite the active dimension-four configuration. They illustrate
the original pruning technique, but are not a ready-to-enable configuration
for Note 9. The active program enumerates self-equivalences without those filters;
it does not implement the complete iterative generator-discovery driver.

## Build and reproduce the two dimension-four examples

From this directory, with Make and a C compiler:

```sh
make
make check
```

The executable is `build/ea-stabilizer-16`. It expects **two 16-entry decimal
truth tables**. To count self-equivalences, supply the same table twice:

```sh
./build/ea-stabilizer-16 \
  0 0 0 1 0 2 4 7 0 4 6 3 8 14 10 13 \
  0 0 0 1 0 2 4 7 0 4 6 3 8 14 10 13
```

`make check` runs both article Table 2 representatives and checks the complete
output lines. Expected stabilizer orders are **5760** and **384**; their orbit
sizes are **1183800360960** and **17757005414400**. Outputs are retained in
`build/row1.txt` and `build/row2.txt`. These checks exercise the active counting
path, not the disabled pruning configurations. The legacy interface and final
division assume suitable inputs; use the maintained reconstruction for general
equivalence testing. In particular, simply changing N to five would overflow
the signed 64-bit group-order arithmetic.

## Compiler flags: recorded versus new

The surviving `Makefile.original` records:

```text
CFLAGS=-march=core2 -mfpmath=sse -fomit-frame-pointer -ffast-math -O3
#CFLAGS=-Wall -O3 -fomit-frame-pointer
#CFLAGS=-g -Wall

#ICC:
#icc -O3 -xN -tpp7 -ipo
```

These are authentic surviving build settings. That Makefile names `apn-8` and
`apn-16` targets, however: it does not prove which flags compiled this backup
or the exact 2007/2008 experiment. In particular, the Core 2 settings should
not be presented as a recovered Pentium 4 command.

The new default recipe uses `-O2 -x c` and compatibility options
`-Wno-implicit-function-declaration -Wno-asm-operand-widths`, following the
recovery build. These suppress diagnostics from old declarations and x86
inline-assembly helpers; they are not original optimization flags. The headers
still contain x86 assembly. The selected counting path builds on the development
Apple Silicon machine because those helpers are unused, not because the source
has been ported to ARM. Other compilers or configurations may need adjustments.

On an appropriate x86 GCC toolchain, `make historic-flags CC=gcc` shows how to
apply the recorded optimization flags to this snapshot. This uses a separate
executable and retains the explicit modern compatibility options. It is a new
recipe, not a recovered historical command. Command-line overrides such as
`make clean` followed by `make CC=clang CFLAGS=-O2` are supported.
