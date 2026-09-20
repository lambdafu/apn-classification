# Compiled weak EA candidate search

`make candidates5` runs the dimension-five experiment. It first checks the
compiled kernel against the existing reference, then performs the complete
search. By default APN singleton propagation is enabled, and affine canonicity is
checked after each successful extension and propagation closure. Its published
comparison target is 11,768 weak EA candidates (thesis §4.2.5; article §4,
printed page 279). These are not the final seven EA classes.

To watch progress and retain a log, run from `artifacts/`:

```sh
mkdir -p build
set -o pipefail
make candidates5 2>&1 | tee build/ea-candidates-5.log
```

After the initial verification checks, progress reports show elapsed search
time, outer attempts, inner affine nodes, candidates found, and the current
full template (`None` marks unknown entries), branch position, explicit decision
count, and total defined entries. Reports are emitted at work milestones when
at least 20 seconds have elapsed since the previous report; they are not a fixed-rate heartbeat or a
percentage complete. Another terminal can follow the saved log with
`tail -f build/ea-candidates-5.log`. The command replaces the previous log.
Ctrl-C stops the search. There is no checkpoint: a subsequent invocation
starts over, and completed candidate/result files are written only at the end.

## Optional affine cutoff

```sh
make candidates5 CUTOFF=20 2>&1 | tee build/ea-candidates-5-cutoff20.log
```

Equivalently, pass `--cutoff 20` to `sage/ea_candidates.sage`. Depth means the
number of defined S-box entries **after** trying the new value and propagating
all forced assignments. It is not the number of explicit branching decisions. A cutoff C
skips the affine test exactly when `C <= depth < 2^n`. APN checks still run at
every extension. Complete APN functions always receive the full affine test
before they can be emitted. Thus C=20 in dimension five checks depths 1–19 and
32, skipping 20–31. Omit the option to check every depth; C=2^n is equivalent
to omitting it. Valid explicit cutoffs are 1 through 2^n.

The working setting 20 comes from Marcus Brinkmann's local comparison on
2026-09-19: among the cutoffs he tried, it reached the furthest lexicographic
search position by the first progress report, nominally after 20 seconds.
This is an author-reported observation for the opening search region, not a
completed benchmark or a full-run optimum. Compare the printed elapsed times,
since reports can arrive later than 20 seconds. Outer attempts and inner
affine nodes help explain the cost balance; neither count alone measures
progress through the search space. The default remains no cutoff. That
comparison preceded singleton propagation; it is not a calibration of the
updated search.

Thesis §4.2.3 describes skipping degrees *greater than*
its quoted cutoff; this interface uses the author's requested inclusive `>=`
boundary. Translate that convention before comparing historical settings.

Deferring these sound partial rejections preserves the final affine-canonical
candidate set because every leaf is tested. It changes work counts and the
number of APN completions reaching the final check. The record distinguishes
`apn_completions` (before that check) from emitted `candidates`, and records
affine checks and skips by known-entry count (index i means i+1 known entries).
The outer search profiles instead use the position of the explicit assignment.
`complete_affine_rejected` counts final rejections regardless of which decision
position led to completion. The selected cutoff and its precise convention are
also recorded.

The earlier prefix-only [completed cutoff verification](../results/ea-candidates-4-cutoff11.json)
checks all cutoffs in dimensions two and three and cutoffs 11, 12, 15, 16 in
dimension four against the no-cutoff reference. All produce identical final
tables. It verifies the inclusive boundary and that every complete function
is checked. Dimension-four pre-check APN completions number 1216, 432, 35, 16,
respectively; all four schedules emit 15 candidates. The 16 pre-check
completions with no checks skipped are a clue for the historical discrepancy,
not proof that the publication counted at this stage.

The entry point is [ea_candidates.sage](../sage/ea_candidates.sage), backed by
[affine_search.pyx](../cython/affine_search.pyx). The readable algorithms and
their pruning arguments are in [affine-canonicity.md](affine-canonicity.md).
The affine filter now also accepts templates with holes, retaining inconclusive
comparisons at undefined positions. The [propagation method](apn-propagation.md)
gives the additional readable reference, invariants, and completed checks.
Use `--no-propagation` to select the earlier prefix-only search for comparison.

## State and control flow

The outer APN recursion and the inner alpha/beta recursion both remain.
There is an optional affine cutoff, but no checkpoint, manually skipped subtree,
or explicit frame machine. A search owns compact fixed-capacity arrays for its S-box, affine
maps, and constraint masks. Dimensions are runtime inputs through n=5; users
do not edit and rebuild a dimension-specific source file.

Affine-map values live in reusable buffers. Domain and image masks are
64-bit integers passed by value. Refinement writes the new affine coset and
preserves entries in the old domain. On returning, the caller's masks make
descendant entries undefined; their bytes are left stale. The output-map
refinement chooses an origin from its existing domain, which need not include
zero. Image masks enforce injectivity. All mask shifts use explicitly unsigned
64-bit values, including positions and images at index 31.

With propagation enabled, per-position value masks collect plane constraints;
singleton masks assign positions beyond the backtracking frontier. A linear
trail restores removed bits, while the parent's S-box domain mask hides forced
assignments on return. See the propagation method for the closure and trail
invariants. No full table is copied during recursion.

In the prefix-only comparison mode, the APN difference table uses a different
restoration rule: each attempted assignment records the number of successful pair writes, then removes exactly
those writes after rejection or recursion. It never removes the pre-existing
bit that caused a collision. No complete table is copied at each search node.
Only complete candidate output is serialized.

The Boolean compiled filter is checked against the reference that returns
affine witnesses. The compiled inner calls are typed Cython calls. Python is
used for setup, validation, candidate serialization, and occasional progress
reports. Signal checks allow an interrupted run to stop; interruption does not
produce a completed record or imply resumability.

## Verification before the search

[verify_affine_search.py](../lib/verify_affine_search.py) checks the prefix-only
baseline as follows. [verify_propagation.py](../lib/verify_propagation.py) adds
the sparse-template and propagation checks described in the propagation method.

The baseline checks:

- Every affine-template assignment through n=2, with and without injectivity,
  compared against the already independently checked immutable reference.
- Every left-defined prefix through n=2, comparing the compiled Boolean
  canonicity answer with the reference's witness result.
- Both checks with undefined buffers filled with zero, q-1, and 255. A
  plausible vector value and an out-of-range byte must both remain irrelevant
  outside the domain mask.
- Translated affine-basis refinements through n=5, including the highest
  supported domain and image mask bits.
- Complete normalized searches through n=4, and complete APN permutation
  searches in n=3,4, comparing every candidate byte and every outer per-depth
  statistic with the reference. Repeating with different initial buffer values
  exercises stale data across sibling branches and successive filter calls.

The compiled dimension-four run also gives 15 candidates, so changing the
implementation language does not resolve the historical count of 16.
Dimension five supplies a separate comparison point; its result must be read
from a completed record rather than inferred from partial progress.

## Output and limits

On completion the command writes `build/ea-candidates-5.json` and
`build/dimension-5-weak-ea-candidates.txt`. The latter contains one decimal truth
table per line. The record gives source and extension hashes, finite checks,
published and computed counts, table hashes, depth profiles, outer and inner
work counts, and elapsed time. Every candidate is checked against the direct
derivative definition and the zero-on-basis normalization. Tables must be
unique and ordered. A mismatch with the published count is recorded explicitly.

Progress messages are observations of an unfinished run, not estimates of the
remaining fraction. The search does not classify candidates under full EA or
CCZ equivalence or compute their stabilizers. Those are subsequent experiments.

## Completed dimension-five run

The [saved run record](../results/ea-candidates-5.json) confirms **11,768**
candidates, matching the published count. The candidate text and full progress
log are preserved beside it in `results/`. The subsequent [exact EA reduction](ea-reduction.md)
checks every assignment and recovers the seven published representatives.
