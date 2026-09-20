"""Import published tables from an explicit checkout, without executing its code."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

PIN = 'b44f031ed121ab198354010b07c924e8504bca6f'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('checkout', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = args.checkout
    revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != PIN:
        raise ValueError('unexpected upstream revision')
    hashes = {}
    def read(name):
        raw = (root / name).read_bytes()
        hashes[name] = hashlib.sha256(raw).hexdigest()
        return raw.decode()
    dimensions = []
    for n in range(1, 5):
        q = 1 << n
        tex = read({1:'020-dim-1.tex', 2:'030-dim-2.tex', 3:'040-dim-3.tex',
                    4:'051-dim-4-data.tex'}[n])
        spectra_text = read('052-dim-4-walsh.tex') if n == 4 else tex
        spectra = {}
        for line in spectra_text.splitlines():
            match = re.match(r'\$w_\{?(\d+)\}?\$\s*&', line)
            if match:
                spectra[int(match[1])] = [int(x.strip().replace('\\', '')) for x in line.split('&')[1:]]
        rows = []
        for line in tex.splitlines():
            if not re.match(r'^\d+\s*&', line):
                continue
            fields = [s.strip().replace('\\\\', '').strip() for s in line.split('&')]
            row = int(fields[0])
            assert row == len(rows) + 1 and len(fields) == q + 6
            spectrum = int(re.search(r'\d+', fields[q+3])[0])
            ccz = row if fields[q+5] == 'can.' else int(re.search(r'\d+', fields[q+5])[0])
            rows.append(dict(row=row, table=list(map(int, fields[1:q+1])),
                             stabilizer=int(fields[q+1]), degree=int(fields[q+2]),
                             walsh=spectra[spectrum], walsh_index=spectrum,
                             bijective=fields[q+4] == 'Y', ccz_row=ccz))
        ea_tables = [list(map(int, s.split())) for s in read('data/EA-{}.txt'.format(n)).splitlines() if s.strip()]
        ccz_tables = [list(map(int, s.split())) for s in read('data/CCZ-{}.txt'.format(n)).splitlines() if s.strip()]
        assert ea_tables == [r['table'] for r in rows]
        assert ccz_tables == [r['table'] for r in rows if r['ccz_row'] == r['row']]
        if n == 4:
            sizes = read('data/EA-4-sizes.txt').splitlines()
            walsh = read('data/EA-4-walsh.txt').splitlines()
            degree = read('data/EA-4-degree.txt').splitlines()
            assignments = read('data/ea-to-ccz-4.txt').splitlines()
            bijective = read('data/EA-4-bijective-summary.txt').splitlines()
            assert all(len(x) == len(rows) for x in (sizes, walsh, degree, assignments, bijective))
            for i, row in enumerate(rows):
                assert list(map(int, sizes[i].split()[:q])) == row['table']
                assert int(sizes[i].split()[-1]) * row['stabilizer'] == 6818690079129600
                spectrum = list(map(int, walsh[i].split()))
                spectrum[0] -= q - 1
                spectrum[q] -= 1
                assert spectrum == row['walsh']
                assert int(degree[i]) == row['degree'] and int(assignments[i]) == row['ccz_row']
                assert bijective[i].endswith('Found something:') == row['bijective']
        dimensions.append(dict(dimension=n, representatives=rows))
    result = dict(schema=1, source=dict(
        title='Extended Affine and CCZ Equivalence up to Dimension 4',
        paper='https://eprint.iacr.org/2019/316',
        repository='https://github.com/lambdafu/ext-affine-and-ccz-classes-up-to-dim-4',
        commit=revision, sha256=hashes,
        import_note='Tables transcribed from TeX and cross-checked against raw data; b=0 removed from raw Walsh spectra.'),
        dimensions=dimensions)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('Imported', [(d['dimension'], len(d['representatives'])) for d in dimensions])


if __name__ == '__main__':
    main()
