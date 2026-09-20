"""Independent finite action checks for the normalized EA kernel."""
from itertools import product
from random import Random
from affine_oracle import affine_permutations, linear_permutations
from ea_equivalence import (equivalence_witness, normalized_equivalence_witness,
                            verify_ea_witness)


def verify_kernel(kernel):
    checks=[]
    tables=list(product(range(4),repeat=4))
    # For two-bit functions the sole nonlinear ANF coefficient is the XOR of
    # all four values. Output GL acts transitively on its nonzero choices;
    # affine corrections freely identify the other coefficients.
    pairs=0
    for source in tables:
        for target in tables:
            expected=(source[0]^source[1]^source[2]^source[3]==0)==(target[0]^target[1]^target[2]^target[3]==0)
            result,_=kernel.witness(source,target)
            assert (result is not None)==expected,(source,target)
            if result is not None:verify_ea_witness(source,target,result)
            pairs+=1
    checks.append(dict(check='all_n2_ordered_pairs_against_ANF_orbit_oracle',pairs=pairs))
    for source in tables:
        for target in ((0,0,0,0),(0,0,0,1)):
            original=equivalence_witness(source,target)
            readable=normalized_equivalence_witness(source,target)
            compiled,_=kernel.witness(source,target,translation_reduction=False)
            assert (original is not None)==(readable is not None)==(compiled is not None)
            for result in (original,readable,compiled):
                if result is not None:verify_ea_witness(source,target,result)
    checks.append(dict(check='n2_both_readable_methods_and_unreduced_compiled_search',pairs=512))
    rng=Random(2007)
    alphas=list(affine_permutations(3));betas=list(linear_permutations(3))
    for _ in range(64):
        source=tuple(rng.randrange(8) for x in range(8))
        a,b=rng.choice(alphas),rng.choice(betas)
        columns=[rng.randrange(8) for _ in range(4)]
        gamma=tuple(columns[0] ^ (columns[1] if x&1 else 0) ^
                    (columns[2] if x&2 else 0) ^ (columns[3] if x&4 else 0) for x in range(8))
        target=tuple(b[source[a[x]]] ^ gamma[x] for x in range(8))
        result,_=kernel.witness(source,target)
        assert result is not None
        verify_ea_witness(source,target,result)
        reference=normalized_equivalence_witness(source,target)
        assert reference is not None
        verify_ea_witness(source,target,reference)
    checks.append(dict(check='seeded_n3_affine_action_positive_witnesses',pairs=64,seed=2007))
    return checks
