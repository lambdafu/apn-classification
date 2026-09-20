"""Exhaustive APN permutation classification under affine equivalence."""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from itertools import product
from pathlib import Path
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from affine_canonicity import search_apn
from affine_equivalence import equivalence_witness, verify_witness
from affine_oracle import affine_permutations, affine_orbit
from apn_reference import is_apn_derivatives
from ea_equivalence import algebraic_degree
from field_functions import power_table
from compiled import load_kernel


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dimension', type=int, choices=[3, 4, 5], default=5)
    parser.add_argument('--reference', action='store_true')
    parser.add_argument('--cutoff', type=int, help='skip intermediate affine tests at this known-entry count; always test leaves')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.cutoff is not None and (args.reference or not 1 <= args.cutoff <= (1 << args.dimension)):
        parser.error('--cutoff requires the compiled path and a value in 1..2^n')
    start = time.perf_counter()
    published = json.loads((ROOT / 'data/permutations-five.json').read_text())
    small = json.loads((ROOT / 'data/dimension-four.json').read_text())
    kernel, build = (None, None) if args.reference else load_kernel('affine_search')
    checks = []
    # Independent complete affine-action oracle, including nonbijective inputs.
    for n in (1, 2):
        q = 1 << n
        group = tuple(affine_permutations(n))
        remaining = set(product(range(q), repeat=q))
        pairs = 0
        while remaining:
            target = min(remaining)
            orbit = affine_orbit(target, group)
            for source in product(range(q), repeat=q):
                witness = equivalence_witness(source, target)
                require((witness is not None) == (source in orbit), 'affine oracle differs')
                if witness is not None:
                    verify_witness(source, target, witness)
                pairs += 1
            remaining -= orbit
        checks.append(dict(check='complete_small_affine_orbits', dimension=n, pairs=pairs))
    if kernel is not None:
        for n in (3, 4):
            reference = b''.join(bytes(t) for t in search_apn(n, permutations=True))
            for propagation in (False, True):
                actual, _, _ = kernel.search(n, normalized=False, permutations=True,
                                             propagation=propagation, poison=255)
                require(actual == reference, 'permutation search disagrees with reference')
            checks.append(dict(check='complete_permutation_reference_comparison', dimension=n))
    n = args.dimension
    q = 1 << n
    started = time.perf_counter()
    last = started
    def progress(state):
        nonlocal last
        now = time.perf_counter()
        if now - last >= 20:
            print('n={}: {:.1f}s, {} attempts, {} affine nodes, {} representatives; {}'.format(
                n, now - started, state['attempts'], state['inner_nodes'],
                state['candidates'], state['template']), file=sys.stderr, flush=True)
            last = now
    print('Starting complete n={} APN permutation search'.format(n), file=sys.stderr, flush=True)
    if kernel is None:
        stats = {}
        rows = list(search_apn(n, permutations=True, stats=stats))
        data = b''.join(bytes(t) for t in rows)
        work = None
    else:
        data, stats, work = kernel.search(n, normalized=False, permutations=True,
                                         progress=progress, cutoff=args.cutoff)
    search_seconds = time.perf_counter() - started
    rows = [list(data[i:i+q]) for i in range(0, len(data), q)]
    require(len(data) % q == 0 and rows == sorted(rows) and
            len({tuple(t) for t in rows}) == len(rows), 'invalid search output')
    expected = {3: [small['permutation_n3']], 4: [], 5: published['representatives']}[n]
    require(rows == expected, 'published representatives differ')
    witnesses = []
    for i, table in enumerate(rows):
        require(sorted(table) == list(range(q)) and is_apn_derivatives(table), 'not an APN permutation')
        if n != 5:
            continue
        require(algebraic_degree(table) == published['degrees'][i], 'degree differs')
        for kind, source in [('power', power_table(n, published['power_exponents'][i])),
                             ('inverse', [table.index(x) for x in range(q)])]:
            target_row = i + 1 if kind == 'power' else published['inverse_rows'][i]
            target = rows[target_row - 1]
            witness = equivalence_witness(source, target)
            verify_witness(source, target, witness)
            witnesses.append(dict(kind=kind, row=i+1, target_row=target_row,
                                  source=source, alpha=witness[0], beta=witness[1]))
    inputs = ['sage/apn_permutations.sage', 'lib/affine_equivalence.py',
              'lib/affine_canonicity.py', 'lib/affine_refinement.py', 'lib/affine_oracle.py',
              'lib/apn_reference.py', 'lib/ea_equivalence.py', 'lib/field_functions.py',
              'lib/compiled.py', 'cython/affine_search.pyx', 'data/permutations-five.json',
              'data/dimension-four.json']
    record = dict(schema=1, artifact='apn-permutations', completed=True,
                  finished_utc=datetime.now(timezone.utc).isoformat(), dimension=n,
                  configuration=dict(permutations=True, normalized=False, cutoff=args.cutoff,
                                     propagation=not args.reference,
                                     implementation='reference' if args.reference else 'Cython'),
                  environment=dict(sage=SAGE_VERSION, python=platform.python_version(),
                                   system=platform.system(), machine=platform.machine()),
                  source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in inputs},
                  build=build, checks=checks, representatives=rows, witnesses=witnesses,
                  search=stats, work=work, tables_sha256=hashlib.sha256(data).hexdigest(),
                  search_seconds=search_seconds, elapsed_seconds=time.perf_counter()-start)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix('.tmp')
    temporary.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    temporary.replace(args.output)
    print('{} representatives, {} checked witnesses; search {:.3f}s'.format(
        len(rows), len(witnesses), search_seconds), file=sys.stderr, flush=True)


if __name__ == '__main__':
    main()
