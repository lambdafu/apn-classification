"""Article Algorithm 3: recursive EA search and stabilizer-chain pruning.

We write T = beta(S compose alpha) + gamma. Position orbits therefore use
self-equivalences of T and act by alpha -> alpha compose h. For Algorithm 3
S=T, so both sides use the same stabilizer. No code automorphisms are used.
"""
from affine_refinement import refine, complete
from apn_reference import validate_table
from ea_equivalence import verify_ea_witness


def orbit_filter(alpha, orbits):
    """Necessary conditions for a partial permutation to be right-orbit least.

O[x] is the orbit of x under K fixing positions 0,...,x-1 pointwise.
At completion these conditions are sufficient too. The cardinality bound
uses that |O[x]| distinct values cannot all exceed q-|O[x]|.
"""
    q = len(alpha)
    for x, value in enumerate(alpha):
        if value is None:
            continue
        if len(orbits[x]) == q - x and all(y is not None for y in alpha[:x]):
            minimum = next(y for y in range(q) if y not in alpha[:x])
            if value != minimum:
                return False
        if any(alpha[y] is not None and alpha[y] < value for y in orbits[x]):
            return False
    return True


def search(source, target, orbits=None, exclude_identity=False, propagation=False):
    """Lexicographic three-template search; return (witness, work counts).

Only use orbits from a certified subgroup of the TARGET input stabilizer.
Identity exclusion is for the self-equivalence generator search only.
"""
    n = validate_table(source)
    if validate_table(target) != n:
        raise ValueError('dimensions differ')
    q = len(source)
    if orbits is None:
        orbits = [(x,) for x in range(q)]
    empty = (None,) * q
    counts = dict(input_nodes=0, beta_attempts=0, input_filter_rejections=0)
    best = None

    def can_improve(alpha):
        if best is None:
            return True
        for x, value in enumerate(alpha):
            if value is None:
                return True
            if value != best[0][x]:
                return value < best[0][x]
        return False

    def input_step(x, alpha, beta, gamma):
        nonlocal best
        counts['input_nodes'] += 1
        if x == q:
            if exclude_identity and alpha == tuple(range(q)):
                return None
            best = alpha, complete(beta, injective=True), gamma
            return None
        if alpha[x] is not None:
            return output_step(x, alpha, beta, gamma)
        for value in range(q):
            if value in alpha:
                continue
            extended = refine(alpha, x, value, injective=True)
            if not can_improve(extended):
                counts['input_filter_rejections'] += 1
                continue
            if not orbit_filter(extended, orbits):
                counts['input_filter_rejections'] += 1
                continue
            output_step(x, extended, beta, gamma)
        return None

    def output_step(x, alpha, beta, gamma):
        if propagation:
            while True:
                previous = beta, gamma
                for point, image in enumerate(alpha):
                    if image is None:
                        continue
                    u = source[image]
                    if beta[u] is not None:
                        gamma = refine(gamma, point, target[point] ^ beta[u])
                        if gamma is None:
                            return None
                    elif gamma[point] is not None:
                        beta = refine(beta, u, target[point] ^ gamma[point], injective=True)
                        if beta is None:
                            return None
                if (beta, gamma) == previous:
                    break
        u = source[alpha[x]]
        if beta[u] is not None:
            return correction_step(x, alpha, beta, gamma)
        values = range(q) if gamma[x] is None else (target[x] ^ gamma[x],)
        for value in values:
            if value in beta:
                continue
            counts['beta_attempts'] += 1
            extended = refine(beta, u, value, injective=True)
            correction_step(x, alpha, extended, gamma)
        return None

    def correction_step(x, alpha, beta, gamma):
        value = target[x] ^ beta[source[alpha[x]]]
        extended = refine(gamma, x, value)
        if extended is None:
            return None
        return input_step(x + 1, alpha, beta, extended)

    input_step(0, empty, refine(empty, 0, 0, injective=True), empty)
    result = best
    if result is not None:
        verify_ea_witness(source, target, result)
    return result, counts


def permutation_group(generators, q):
    from sage.all import PermutationGroup
    return PermutationGroup([[y + 1 for y in g] for g in generators] or
                            [list(range(1, q + 1))], domain=list(range(1, q + 1)))


def stabilizer_orbits(group, q):
    """Independent comparison only: orbits of the full point stabilizers."""
    result = []
    subgroup = group
    for x in range(q):
        result.append(tuple(sorted(int(y) - 1 for y in subgroup.orbit(x + 1))))
        subgroup = subgroup.stabilizer(x + 1)
    return result


def generator_orbits(generators, q):
    """Literal article construction: retain only generators fixing y<x.

Forward closure under the retained permutations computes their generated
subgroup's orbit. No Schreier generators or full stabilizer routine is used.
"""
    orbits = []
    for x in range(q):
        selected = [g for g in generators if all(g[y] == y for y in range(x))]
        reached = {x}
        pending = [x]
        while pending:
            point = pending.pop()
            for g in selected:
                image = g[point]
                if image not in reached:
                    reached.add(image)
                    pending.append(image)
        orbits.append(tuple(sorted(reached)))
    return orbits


def printed_note9_filter(alpha):
    """The three printed rules, checked on all currently defined positions."""
    if alpha[0] is not None and alpha[0] != 0:
        return False
    if alpha[1] is not None and alpha[1] != 1:
        return False
    if alpha[2] is not None:
        for x in (17, 22, 25, 28):
            if alpha[x] is not None and alpha[x] < alpha[2]:
                return False
    return True


def canonical_generators(table, backend=search, progress=None):
    """Discover H from identity; terminate only after an exhausted search."""
    validate_table(table)
    q = len(table)
    # Lemma 7's hypotheses, checked directly in our normalized coordinates.
    if any(table[x] for x in [0] + [1 << i for i in range(q.bit_length() - 1)]):
        raise ValueError('requires the standard affine basis in the zero fiber')
    span = {0}
    for y in table:
        span |= {v ^ y for v in span}
    if len(span) != q:
        raise ValueError('requires the image to span the output space')
    generators, steps = [], []
    group = permutation_group(generators, q)
    while True:
        orbits = generator_orbits(generators, q)
        witness, counts = backend(table, table, orbits, True)
        step = dict(subgroup_order=int(group.order()), orbits=orbits,
                    work=counts, exhausted=witness is None)
        if witness is None:
            steps.append(step)
            if progress:
                progress(step)
            return group, generators, steps
        verify_ea_witness(table, table, witness)
        alpha = tuple(witness[0])
        # Membership is a check of the filter, not a substitute for it.
        from sage.all import SymmetricGroup
        if SymmetricGroup(q)([y + 1 for y in alpha]) in group:
            raise RuntimeError('search returned a member of the known subgroup')
        generators.append(alpha)
        new_group = permutation_group(generators, q)
        if new_group.order() <= group.order():
            raise RuntimeError('subgroup did not grow')
        step.update(alpha=list(alpha), beta=list(witness[1]), gamma=list(witness[2]),
                    next_subgroup_order=int(new_group.order()))
        steps.append(step)
        if progress:
            progress(step)
        group = new_group
