"""Reproduce Langevin's component-extension covering in dimension five."""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from components import (affine_words, capacity_ok, character_sum, good_extensions,
                        last_components, parse_boolean_classes, parse_seeds, planes,
                        quotient, reduce, rref, table, transform, unresolved)
from code_equivalence import canonical, equivalence_certificate
from compiled import load_kernel
from sage.all import PermutationGroup
from sage.env import SAGE_VERSION


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
    temporary.replace(path)


def source_hashes():
    paths = sorted(p for folder in ('lib', 'cython', 'data')
                   for p in (ROOT / folder).iterdir() if p.is_file() and p.suffix in ('.py', '.sage', '.pyx', '.txt'))
    paths.append(Path(__file__).resolve())
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def classify(rows):
    classes, infos, assignments = [], [], []
    lookup = {}
    for words in rows:
        info = canonical(words)
        key = info['key']
        if key not in lookup:
            lookup[key] = len(classes)
            classes.append(words)
            infos.append(info)
        idx = lookup[key]
        p = equivalence_certificate(words, classes[idx], info, infos[idx])
        assignments.append(dict(words=words, representative=idx, permutation=p))
    return dict(classes=classes, assignments=assignments)


def seed_audit():
    rows = parse_boolean_classes((ROOT / 'data/class-2-5.txt').read_text())
    seeds = parse_seeds((ROOT / 'data/sel-1-5.txt').read_text())
    all_planes = planes(5)
    group_order = 32
    for i in range(5):
        group_order *= 32 - (1 << i)
    seen, selected, records = set(), set(), []
    total = 0
    for row in rows:
        word = row['word']
        info = canonical([word], marked=True, automorphisms=True)
        assert info['key'] not in seen, 'duplicate Boolean EA class'
        seen.add(info['key'])
        assert info['order'] == row['stabilizer'], 'published stabilizer differs'
        orbit = group_order // info['order']
        total += orbit
        score = character_sum(word, all_planes)
        if score * 31 <= -len(all_planes):
            selected.add(info['key'])
        records.append(dict(anf=row['anf'], word=word, stabilizer=info['order'],
                            orbit_size=orbit, character_sum=score))
    assert len(rows) == 48 and total == 1 << 26
    assert len(selected) == 6
    seed_keys = set()
    for seed in seeds:
        word = seed['word']
        info = canonical([word], marked=True, automorphisms=True)
        seed_keys.add(info['key'])
        assert info['order'] == seed['stabilizer']
        affine = rref(affine_words(5))
        for p in seed['generators']:
            assert reduce(transform(word, p) ^ word, affine) == 0
        group = PermutationGroup([[x+1 for x in p] for p in seed['generators']])
        assert int(group.order()) == seed['stabilizer']
    assert seed_keys == selected
    return dict(boolean_classes=records, mass=total, selected_seeds=seeds,
                positive_threshold_selects=sum(r['character_sum'] * 31 <= len(all_planes) for r in records))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'build/run')
    parser.add_argument('--through-level', type=int, choices=range(1, 6), default=5)
    args = parser.parse_args()
    directory = args.output_dir
    sources = source_hashes()
    kernel, build = load_kernel()
    start = time.monotonic()

    def save_stage(level, payload, seconds):
        result = dict(schema=1, artifact='langevin-component-covering', completed=True,
                      level=level, dimension=5, source_sha256=sources, build=build,
                      finished_utc=datetime.now(timezone.utc).isoformat(),
                      environment=dict(sage=SAGE_VERSION, python=platform.python_version(),
                                       system=platform.system(), machine=platform.machine()),
                      seconds=seconds, **payload)
        write(directory / ('level%d.json' % level), result)
        return result

    def cached(level):
        path = directory / ('level%d.json' % level)
        if not path.exists():
            return None
        record = json.loads(path.read_text())
        if record['source_sha256'] != sources:
            raise ValueError('checkpoint sources changed: use a new output directory')
        assert record['completed'] is True
        return record

    audit = cached(1)
    if audit is None:
        then = time.monotonic()
        print('Auditing all 48 Boolean classes and the six starting functions', flush=True)
        checks = []
        for n, words in [(2, []), (3, []), (3, [128])]:
            expected = list(good_extensions(words, n))
            actual = kernel.enumerate_extensions(words, n, capacity=False)['words']
            assert actual == expected
            checks.append(dict(dimension=n, words=words, extensions=len(actual)))
        audit = save_stage(1, dict(**seed_audit(), reference_checks=checks), time.monotonic()-then)
        print('Level 1: 48 distinct classes cover all 2^26 affine cosets; six selected', flush=True)
    if args.through_level == 1:
        return
    level2 = cached(2)
    if level2 is None:
        then = time.monotonic()
        rows, counts = [], []
        for i, seed in enumerate(audit['selected_seeds']):
            t = time.monotonic()
            r = kernel.enumerate_extensions([seed['word']], generators=seed['generators'])
            rows += [[seed['word'], w] for w in r.pop('words')]
            r.pop('witnesses')
            counts.append(r)
            print('Level 2 seed %d: %d orbit extensions, %d pass capacity (%.2fs)' %
                  (i+1, r['orbit_extensions'], r['capacity_survivors'], time.monotonic()-t), flush=True)
        print('Classifying %d level-2 maps' % len(rows), flush=True)
        classified = classify(rows)
        level2 = save_stage(2, dict(**classified, seed_counts=counts), time.monotonic()-then)
        print('Level 2: %d CCZ classes' % len(level2['classes']), flush=True)
    if args.through_level == 2:
        return
    level3 = cached(3)
    if level3 is None:
        then = time.monotonic()
        rows, counts, completions = [], [], []
        parent_hash = hashlib.sha256((directory/'level2.json').read_bytes()).hexdigest()
        for i, parent in enumerate(level2['classes']):
            path = directory/'level3-parts'/('%04d.json' % i)
            if path.exists():
                r = json.loads(path.read_text())
                assert r['parent_sha256'] == parent_hash and r['source_sha256'] == sources
            else:
                t = time.monotonic()
                r = kernel.enumerate_extensions(parent, finish_two=True)
                r.update(parent_sha256=parent_hash, source_sha256=sources, parent=parent,
                         seconds=time.monotonic()-t, completed=True)
                write(path, r)
            rows += [parent + [w] for w in r['words']]
            completions += [parent + [w] + tail for w, tail in zip(r['words'], r['witnesses'])]
            counts.append({k:v for k,v in r.items() if k not in ('words','witnesses','source_sha256')})
            print('Level 3 parent %d/%d: %d candidates, %d capacity, %d extendable (%.2fs)' %
                  (i+1,len(level2['classes']),r['orbit_extensions'],r['capacity_survivors'],r['feasible_survivors'],r['seconds']), flush=True)
        classified = classify(rows)
        level3 = save_stage(3, dict(**classified, parent_counts=counts, completion_witnesses=completions),time.monotonic()-then)
        print('Level 3: %d CCZ classes' % len(level3['classes']), flush=True)
    if args.through_level == 3:
        return
    level4 = cached(4)
    if level4 is None:
        then = time.monotonic()
        rows, counts = [], []
        for parent in level3['classes']:
            r = kernel.enumerate_extensions(parent)
            rows += [parent+[w] for w in r.pop('words')]
            r.pop('witnesses')
            counts.append(r)
        classified = classify(rows)
        level4 = save_stage(4, dict(**classified,parent_counts=counts),time.monotonic()-then)
        print('Level 4: %d CCZ classes' % len(level4['classes']),flush=True)
    if args.through_level == 4:
        return
    if cached(5) is None:
        then = time.monotonic()
        rows, counts = [], []
        for parent in level4['classes']:
            extensions = last_components(parent,5)
            counts.append(len(extensions))
            for w in extensions:
                assert not unresolved(parent+[w],5)
            rows += [parent+[w] for w in extensions]
        classified = classify(rows)
        save_stage(5,dict(**classified,parent_extension_counts=counts,
                         representative_tables=[table(w,5) for w in classified['classes']]),time.monotonic()-then)
        print('Level 5: %d completions, %d CCZ classes; total %.2fs' %
              (len(rows),len(classified['classes']),time.monotonic()-start),flush=True)


if __name__ == '__main__':
    main()
