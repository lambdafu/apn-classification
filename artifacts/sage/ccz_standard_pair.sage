"""Standard Sage code-equivalence test for published n=5 representatives 1 and 2.

Run with sage -python. A CPU-limit termination is inconclusive and produces
no completed result file. This experiment uses no codeword graph backend.
"""
import argparse
import hashlib
import json
import resource
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from sage.all import GF, LinearCode, matrix
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from walsh import absolute_walsh_spectrum


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cpu-limit', type=int, default=300,
                        help='CPU seconds allowed for this process, including startup')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.cpu_limit < 1:
        parser.error('--cpu-limit must be positive')
    resource.setrlimit(resource.RLIMIT_CPU, (args.cpu_limit, args.cpu_limit + 2))
    data = json.loads((ROOT / 'data/dimension-five.json').read_text())
    tables = [r['table'] for r in data['representatives'][:2]]
    if absolute_walsh_spectrum(tables[0]) != absolute_walsh_spectrum(tables[1]):
        raise RuntimeError('Unexpected unequal Walsh spectra for this probe')
    codes = []
    for table in tables:
        rows = [[1] * 32]
        rows += [[(x >> i) & 1 for x in range(32)] for i in range(5)]
        rows += [[(y >> i) & 1 for y in table] for i in range(5)]
        codes.append(LinearCode(matrix(GF(2), rows)))
    print('Testing n=5 rows 1 and 2 with Sage is_permutation_equivalent; '
          'equal Walsh spectra; code dimensions {}; CPU limit {}s'.format(
              [int(c.dimension()) for c in codes], args.cpu_limit), flush=True)
    started = time.perf_counter()
    cpu_started = time.process_time()
    equivalent = bool(codes[0].is_permutation_equivalent(codes[1]))
    record = dict(
        artifact='ccz-standard-pair', completed=True, dimension=5, pair=[1, 2],
        equivalent=equivalent, sage_version=SAGE_VERSION,
        backend='Sage LinearCode.is_permutation_equivalent (Miller)',
        code_convention='row code of columns (1,x,s(x)), LSB-first',
        equal_absolute_walsh_spectra=True, cpu_limit_seconds=args.cpu_limit,
        call_cpu_seconds=time.process_time() - cpu_started,
        call_elapsed_seconds=time.perf_counter() - started,
        finished_utc=datetime.now(timezone.utc).isoformat(),
        source_sha256={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                       for name in ['sage/ccz_standard_pair.sage',
                                    'data/dimension-five.json', 'lib/walsh.py',
                                    'lib/apn_reference.py']})
    rendered = json.dumps(record, indent=2, sort_keys=True) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    print(rendered, flush=True)


if __name__ == '__main__':
    main()
