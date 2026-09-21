"""Replay certificates, coverage arithmetic and recorded stage counts.

Does not repeat the level-2/3/4 exhaustive extension enumeration or its
negative completion decisions. Rerun reproduce.sage for that evidence.
"""
import argparse
import hashlib
import json
import sys
import time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'lib'))
from components import *
from code_equivalence import canonical


def require(value, message):
    if not value:
        raise ValueError(message)


def apn_derivatives(words):
    values=table(words,5)
    for a in range(1,32):
        images=[values[x]^values[x^a] for x in range(32) if x<(x^a)]
        require(len(set(images))==16,'APN derivative collision')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--records',type=Path,default=ROOT/'results')
    parser.add_argument('--output',type=Path,default=ROOT/'build/verification.json')
    parser.add_argument('--compare-artifacts',action='store_true',help='additional comparison after independent classification')
    args=parser.parse_args()
    start=time.monotonic()
    expected=json.loads((ROOT/'data/expected.json').read_text())
    records={i:json.loads((args.records/f'level{i}.json').read_text()) for i in range(1,6)}
    for i,r in records.items():
        require(r['completed'] is True and r['level']==i and r['dimension']==5,'invalid stage')
        for name,digest in r['source_sha256'].items():
            require(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,'source hash differs: '+name)
    checks={}
    # Independently recalculate the Boolean orbit partition and selection.
    first=records[1]
    boolean=parse_boolean_classes((ROOT/'data/class-2-5.txt').read_text())
    require(len(boolean)==48==len(first['boolean_classes']),'Boolean class count differs')
    total=0
    keys=set()
    good=set()
    for row,saved in zip(boolean,first['boolean_classes']):
        info=canonical([row['word']],marked=True,automorphisms=True)
        require(info['key'] not in keys,'duplicate Boolean class')
        keys.add(info['key'])
        require(info['order']==row['stabilizer']==saved['stabilizer'],'Boolean stabilizer differs')
        mass=319979520//info['order']
        require(saved['orbit_size']==mass and saved['word']==row['word'],'Boolean record differs')
        total+=mass
        score=character_sum(row['word'],planes(5))
        require(score==saved['character_sum'],'character sum differs')
        if score*31<=-1240:
            good.add(info['key'])
    require(total==1<<26 and first['mass']==total,'Boolean coverage fails')
    seeds=parse_seeds((ROOT/'data/sel-1-5.txt').read_text())
    require(seeds==first['selected_seeds'],'saved seeds differ')
    require({canonical([s['word']],marked=True)['key'] for s in seeds}==good and len(good)==6,'seed selection differs')
    checks['boolean_classes']=48
    checks['selected_seeds']=6
    checks['affine_cosets_covered']=total
    # Every positive partial-code equivalence, and distinctness of representatives.
    equivalent=0
    for level in range(2,6):
        r=records[level]
        classes=r['classes']
        class_keys=[canonical(words)['key'] for words in classes]
        require(len(set(class_keys))==len(classes),'duplicate CCZ class')
        require(len(classes)==expected[f'level{level}']['ccz_classes'],'CCZ class count differs')
        require(all(len(w)==level for w in classes),'wrong component count')
        represented=set()
        for item in r['assignments']:
            words=item['words']
            idx=item['representative']
            p=item['permutation']
            require(0<=idx<len(classes) and sorted(p)==list(range(32)),'invalid equivalence certificate')
            require(rref(affine_words(5)+words)==rref(transform(w,p) for w in affine_words(5)+classes[idx]),'code witness fails')
            represented.add(idx)
            equivalent+=1
        require(represented==set(range(len(classes))),'unrepresented CCZ class')
    counts2=records[2]['seed_counts']
    require(sum(r['orbit_extensions'] for r in counts2)==expected['level2']['orbit_extensions'],'level 2 extensions differ')
    require(sum(r['capacity_survivors'] for r in counts2)==len(records[2]['assignments'])==3537,'level 2 capacity differs')
    require(len(counts2)==6,'level 2 parents missing')
    for level in (3,4):
        r=records[level]
        counts=r['parent_counts']
        require(len(counts)==len(records[level-1]['classes']),'parents missing')
        require(sum(c['orbit_extensions'] for c in counts)==expected[f'level{level}']['extensions'],'extension count differs')
        require(sum(c['capacity_survivors'] for c in counts)==expected[f'level{level}']['capacity_survivors'],'capacity count differs')
    require(sum(c['feasible_survivors'] for c in records[3]['parent_counts'])==len(records[3]['assignments'])==288,'level 3 completion count differs')
    completions=records[3]['completion_witnesses']
    require(len(completions)==288,'completion witnesses missing')
    for w,item in zip(completions,records[3]['assignments']):
        require(w[:3]==item['words'],'completion parent differs')
        require(not unresolved(w,5),'plane collision')
        apn_derivatives(w)
    require(len(records[4]['assignments'])==42,'level 4 assignment count differs')
    # Last-component solving is small enough to repeat in full.
    finals=[]
    per_parent=[]
    for parent in records[4]['classes']:
        extensions=last_components(parent,5)
        per_parent.append(len(extensions))
        finals.extend(parent+[w] for w in extensions)
    require(per_parent==records[5]['parent_extension_counts'],'last-component counts differ')
    require(finals==[a['words'] for a in records[5]['assignments']] and len(finals)==5,'final enumeration differs')
    for w in finals:
        apn_derivatives(w)
    require(records[5]['representative_tables']==[table(w,5) for w in records[5]['classes']],'final tables differ')
    checks.update(partial_and_final_code_witnesses=equivalent,completion_witnesses=288,
                  ccz_classes_by_level=[len(records[i]['classes']) for i in range(2,6)],
                  final_completions=5)
    if args.compare_artifacts:
        path=ROOT.parent/'artifacts/data/dimension-five.json'
        data=json.loads(path.read_text())
        published=data['representatives']
        keys=[canonical(w)['key'] for w in records[5]['classes']]
        partition={}
        for i,row in enumerate(published,1):
            values=row['table']
            words=[sum((v>>j&1)<<x for x,v in enumerate(values)) for j in range(5)]
            key=canonical(words)['key']
            require(key in keys,'published representative missing')
            partition.setdefault(keys.index(key),[]).append(i)
        require(sorted(partition.values())==[[1,3,7],[2,4,6],[5]],'published CCZ partition differs')
        checks['comparison_with_published_EA_rows']=sorted(partition.values())
        checks['comparison_input_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    output=dict(completed=True,scope=__doc__,checks=checks,seconds=time.monotonic()-start,
                record_sha256={f'level{i}.json':hashlib.sha256((args.records/f'level{i}.json').read_bytes()).hexdigest() for i in records},
                verifier_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                expected_sha256=hashlib.sha256((ROOT/'data/expected.json').read_bytes()).hexdigest())
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps(checks),flush=True)


if __name__=='__main__':
    main()
