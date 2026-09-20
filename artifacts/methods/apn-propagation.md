# APN propagation on partially defined templates

The dimension-five search now enables singleton propagation by default. Run
`make candidates5 CUTOFF=20` from `artifacts/`. For a completed small verification
record, run:

```sh
sage sage/ea_candidates.sage --dimension 4 --cutoff 11 --output build/ea-candidates-4-propagation.json
```

The readable implementation is [apn_propagation.py](../lib/apn_propagation.py);
the compiled implementation is [affine_search.pyx](../cython/affine_search.pyx).
Both retain recursion. This reconstructs Marcus Brinkmann's recollection of
keeping an exclusion mask at every position and assigning singleton domains.
The surviving original construction driver has not been recovered; no claim
of identical historical source or instruction order is made.

## Constraint and closure

For three distinct known positions a, b, c, set d = a XOR b XOR c. These four
points form an **affine plane**, which need not contain zero. The APN criterion
requires their four output values to have nonzero XOR. Thus the value
s(a) XOR s(b) XOR s(c) is forbidden at d. Every triple of known positions must
contribute its constraint, regardless of the current backtracking position.

Each unknown position has a bitmask of remaining values. An empty mask rejects
the branch. A mask with one bit forces its value; assign it and process the
additional triples. Repeat until there are no pending singleton assignments.
These domains express currently visible constraints, not the complete set of
values with an APN completion. Nonempty masks alone do not prove extendibility.

Zero normalization initially restricts zero and every standard basis position
to the singleton {0}; these entries are filled before branching. In permutation
mode, each assignment also excludes its value at every other unknown position.
Permutation mode and zero normalization cannot be combined. Branch at the least
unknown position and try its remaining values in increasing order.

The immutable reference recomputes constraints by enumerating all four-point
affine planes and filling singleton domains in rounds. The compiled version
processes only new triples: after assigning p, enumerate pairs of previously
known positions i, j and constrain p XOR i XOR j if it remains unknown. All
triples not involving p have already been processed. A chosen value has passed
the constraints from triples whose fourth position is p, so already complete
planes remain valid. Forced assignments use exactly the same update routine.

## Shared state and rollback

The S-box has its own domain mask. Its values, the remaining-value masks, and
the alpha/beta buffers belong to one search object. The parent S-box domain is
passed by value. Assignments write only previously unknown S-box positions;
returning to the parent hides child assignments without clearing their bytes.
The allowed-value mask at a known position is ignored until rollback makes
that position unknown again.

Every effective bit removal is appended to a linear undo trail as a position
and a removed bit. A recursive branch saves the trail offset and restores each
removed bit on return. Repeated exclusions of the same bit add no trail entry.
Along one active branch, at most q squared distinct bits can be removed, so
1024 entries suffice for q at most 32. No whole S-box or domain table is copied
at a recursive call. A local pending-position mask schedules forced assignments;
a contradiction discards the remaining pending work with that branch.

This kernel uses incremental exclusion masks instead of also maintaining the
pair-difference table. The earlier prefix-only difference-table search remains
available with `--no-propagation` for comparison. The reference intentionally
uses neither the mutable masks nor the undo trail.

## Affine filtering and the cutoff

The affine filter accepts full templates with `None` at unknown positions.
When refining alpha, it can use any known S-box position, including positions
beyond the first hole. Lexicographic comparison still stops when either side
is unknown before a strict difference: unknown positions cannot be skipped.
A completed alpha/beta witness therefore proves a strict decrease for every
completion of the template. The finite checks include witnesses unavailable
when only the initial defined prefix is exposed.

All propagated values are necessary for any completion of the current branch.
Consequently propagation and the stronger partial affine test preserve every
complete affine-canonical APN function. Least-unknown branching partitions the
remaining completions without duplication; forced assignments do not create
extra branches. Every complete function receives the exact affine test,
including completions reached entirely by propagation.

The cutoff continues to mean **number of known entries**, now counted after
singleton closure. Skip affine checks when `cutoff <= known_entries < q`;
always check complete functions. Known-entry count, explicit decision count,
and the next unknown position can now differ. A closure can jump across several
known-entry counts without testing intermediate states. The earlier local
cutoff-20 calibration used the prefix-only search and is not a calibration of
this implementation.

## Verification and records

[verify_propagation.py](../lib/verify_propagation.py) checks:

- All 9 dimension-one and 625 dimension-two templates, including holes, under
  unrestricted, normalized, and permutation constraints. Compare closures and
  every remaining mask against the plane reference. Exhaustive APN completions
  independently verify that no forced assignment removes a valid completion.
- All such sparse affine comparisons against complete affine group actions,
  including completed witnesses and several stale-buffer initial values.
- 384 dimension-three templates against complete affine input maps with an
  independently constructed minimal output map; closure checks in all modes.
- 80 dimension-five templates with a directly verified APN completion, including
  bit 31 and multiple forced later positions.
- Complete propagated and prefix-only candidate lists through dimension four,
  including permutation searches in dimensions three and four, and repeated
  compiled runs with different stale-buffer values.
- Every cutoff in dimensions two and three and cutoffs 1, 11, 12, 15, 16 in
  dimension four. Cutoff 1 checks only complete functions and exercises extensive
  rollback. Verify candidate-list invariance, scheduling by known-entry count,
  and unconditional final affine checks.

The runner performs these checks before searching; allow roughly twenty seconds
for verification on the development machine, in addition to Sage startup and
compilation. Its schema-3 record identifies propagation, normalization timing,
and the different meanings of the position and known-entry profiles.
`forced_assignments` includes initial normalization and assignments on branches
subsequently rejected; `propagation_exclusions` counts effective bit removals.
Outer attempts now count only explicitly tried available values, excluding
forced assignments and values already removed by propagation. These attempt
counts are not directly comparable to the prefix-only counters. The
[completed dimension-four record](../results/ea-candidates-4-propagation.json)
contains the checks and their examples. All variants still emit the same 15
candidates; the historical intermediate count of 16 remains unresolved.

The dimension-five smoke test was deliberately bounded at about 20 seconds. It
exercised sparse progress reporting, including a defined position 29 beyond
unknown positions 22–28. It was not a completed classification or a measurement
of total runtime. No full dimension-five search was restarted as part of this
change.
