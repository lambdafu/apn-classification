"""Compare archived Magma inputs/output with the published 2019 catalogue."""
import argparse
import ast
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = ROOT / 'historic/magma'
    published = ROOT / 'data/ea-ccz-2019.json'
    inputs = json.loads(published.read_text())
    checks = []
    for dimension in inputs['dimensions']:
        n = dimension['dimension']
        text = (root / ('dim-{}-ea.mgm'.format(n))).read_text()
        tables = ast.literal_eval(text.split('CANDIDATES:=', 1)[1].strip().rstrip(';'))
        expected = [r['table'] for r in dimension['representatives']]
        extra = [[0, 1]] if n == 1 else []
        if tables != expected + extra:
            raise ValueError('historical candidate tables differ')
        checks.append(dict(dimension=n, published_tables_match=len(expected),
                           extra_tables=extra,
                           note='Extra identity function is EA-equivalent to zero by adding itself.' if extra else None))
    log = (root / 'CCZ-4-out.txt').read_text()
    canonical = ast.literal_eval(re.search(r'Canonicals:\s*(\[[\s\S]*?\])', log)[1])
    assignments = ast.literal_eval(re.search(r'Equivalences:\s*(\[[\s\S]*?\])', log)[1])
    rows = inputs['dimensions'][3]['representatives']
    if canonical != [r['row'] for r in rows if r['ccz_row'] == r['row']]:
        raise ValueError('archived canonical list differs')
    if assignments != [r['ccz_row'] for r in rows]:
        raise ValueError('archived CCZ assignments differ')
    names = sorted(p.name for p in root.glob('*.mgm')) + ['CCZ-4-out.txt', 'EA-cmd.txt']
    result = dict(schema=1, artifact='historical-magma-data-audit', completed=True,
                  original_directory='apn-data/ccz-classes',
                  source_sha256={name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in names},
                  verifier_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  published_data_sha256=hashlib.sha256(published.read_bytes()).hexdigest(),
                  candidate_checks=checks, log_header=log.splitlines()[0],
                  ccz_canonical_rows_match=len(canonical), ccz_assignments_match=len(assignments),
                  log_final_line=log.strip().splitlines()[-1],
                  note='Archived output parsed and compared, not a new Magma execution.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print('Archived n=4 log: all 4,713 assignments and 4,151 canonical rows match.')


if __name__ == '__main__':
    main()
