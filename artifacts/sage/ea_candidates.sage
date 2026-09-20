"""Compute weak EA candidates with recursive APN and affine filtering."""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from compiled import load_kernel
from verify_affine_search import verify_kernel, require
from verify_propagation import verify_propagation
from apn_reference import is_apn_derivatives


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dimension', type=int, choices=[3, 4, 5], default=5)
    parser.add_argument('--cutoff', type=int,
                        help='skip affine tests at this many defined entries and deeper, except complete functions')
    parser.add_argument('--no-propagation', action='store_true',
                        help='use the earlier prefix-only search for comparison')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    n = int(args.dimension)
    q = int(1 << n)
    if args.cutoff is not None and not 1 <= args.cutoff <= q:
        parser.error('--cutoff must be in 1..2^n; omit it to check every depth')
    start = time.perf_counter()
    kernel, build = load_kernel('affine_search')
    print('Verifying prefix search, propagation, and sparse affine filtering...',
          file=sys.stderr, flush=True)
    checks = verify_kernel(kernel) + verify_propagation(kernel)
    print('Compiled refinement, sparse propagation, rollback, and complete n<=4 comparisons passed',
          file=sys.stderr, flush=True)
    started = time.perf_counter()
    last_report = started

    def progress(state):
        nonlocal last_report
        now = time.perf_counter()
        if now - last_report >= 20:
            print('n={}: {:.1f}s, {} attempts, {} affine nodes, {} candidates; '
                  'branch position {}, decisions {}, defined {}; template {}'.format(
                n, now - started, state['attempts'], state['inner_nodes'],
                state['candidates'], state['depth'], state['decision_depth'],
                state['defined'], state['template']), file=sys.stderr, flush=True)
            last_report = now

    data, stats, work = kernel.search(n, progress=progress, cutoff=args.cutoff,
                                     propagation=not args.no_propagation)
    search_seconds = time.perf_counter() - started
    candidates = [tuple(data[i:i + q]) for i in range(0, len(data), q)]
    require(len(data) % q == 0 and len(candidates) == work['candidates'], 'truncated candidate output')
    require(candidates == sorted(set(candidates)), 'unordered or duplicated candidates')
    basis = [int(0)] + [int(1 << i) for i in range(n)]
    require(all(all(s[x] == 0 for x in basis) for s in candidates), 'normalization fails')
    require(all(is_apn_derivatives(s) for s in candidates), 'derivative APN check fails')
    published = {4: 16, 5: 11768}.get(n)
    discrepancy = dict(reported=published, computed=len(candidates),
                       matches=None if published is None else len(candidates) == published,
                       source='Thesis section 4.2.5; article section 4, printed page 279')
    inputs = ['sage/ea_candidates.sage', 'cython/affine_search.pyx', 'lib/compiled.py',
              'lib/verify_affine_search.py', 'lib/affine_canonicity.py',
              'lib/affine_refinement.py', 'lib/apn_reference.py', 'lib/affine_oracle.py',
              'lib/apn_propagation.py', 'lib/verify_propagation.py']
    tables = ('# Dimension {}: reconstructed weak EA candidates, not final EA classes.\n'
              '# Computed: {}. Published: {}.\n'
              '# Each row gives s(0) through s({}), in decimal.\n').format(
                  n, len(candidates), published, q - 1)
    tables += ''.join(' '.join(str(v) for v in row) + '\n' for row in candidates)
    record = dict(schema=3, artifact='ea-candidates', completed=True,
                  finished_utc=datetime.now(timezone.utc).isoformat(),
                  environment=dict(sage=SAGE_VERSION, python=platform.python_version(),
                                   system=platform.system(), machine=platform.machine()),
                  configuration=dict(dimension=n, normalized=True, canonicity_cutoff=args.cutoff,
                                     cutoff_rule='skip when cutoff <= known_entries_after_propagation < 2^n; always test complete functions',
                                     propagation=not args.no_propagation,
                                     normalization='zero and basis positions fixed before branching' if not args.no_propagation else 'zero and basis positions fixed when reached',
                                     search_profiles='indexed by explicit assignment position',
                                     affine_profiles='indexed by number of known entries minus one',
                                     control_flow='recursive', implementation='Cython'),
                  source_sha256={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                 for name in inputs},
                  build=build, checks=checks, count=discrepancy, work=work, search=stats,
                  derivative_checks=len(candidates), tables_sha256=hashlib.sha256(data).hexdigest(),
                  search_seconds=search_seconds, elapsed_seconds=time.perf_counter() - start)
    if args.output:
        candidate_path = args.output.with_name('dimension-{}-weak-ea-candidates.txt'.format(n))
        record['outputs'] = dict(candidate_tables=dict(filename=candidate_path.name,
            count=len(candidates), sha256=hashlib.sha256(tables.encode('utf8')).hexdigest()))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = candidate_path.with_name(candidate_path.name + '.tmp')
        temporary.write_text(tables, encoding='utf8')
        temporary.replace(candidate_path)
    rendered = json.dumps(record, indent=2, sort_keys=True, default=int) + '\n'
    if args.output:
        temporary = args.output.with_name(args.output.name + '.tmp')
        temporary.write_text(rendered)
        temporary.replace(args.output)
    else:
        print(rendered, end='')
    print('n={}: {} weak EA candidates; published {}; search {:.3f}s'.format(
        n, len(candidates), published, search_seconds), file=sys.stderr, flush=True)


if __name__ == '__main__':
    main()
