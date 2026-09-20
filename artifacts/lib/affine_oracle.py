"""Small independent oracles; do not call template refinement or the filters."""


def linear_permutations(n):
    """Enumerate ordered vector bases and expand each full linear map.

    Unlike refinement, this only enumerates complete maps. Lists are ordered
    by the integer input represented by the selected basis coefficients.
    """
    q = 1 << n

    def extend(images):
        if len(images) == q:
            yield tuple(images)
            return
        span = set(images)
        for image in range(1, q):
            if image not in span:
                yield from extend(images + [x ^ image for x in images])

    yield from extend([0])


def affine_permutations(n):
    for linear in linear_permutations(n):
        for shift in range(1 << n):
            yield tuple(x ^ shift for x in linear)


def comparable_smaller(prefix, alpha, beta):
    """Stop at the first unknown or unequal position, not at later positions."""
    for d, value in enumerate(prefix):
        if value is None or alpha[d] >= len(prefix) or prefix[alpha[d]] is None:
            return False
        transformed = beta[prefix[alpha[d]]]
        if transformed != value:
            return transformed < value
    return False


def exhaustive_smaller(prefix, permutations):
    return any(comparable_smaller(prefix, a, b)
               for a in permutations for b in permutations)


def output_minimum_smaller(table, alpha):
    """Minimize over all affine output maps greedily, for one full input map.

    Translate the first output to zero. Each first independent difference can
    take the smallest output outside the image span (the next power of two).
    Maintain an explicit full-span dictionary, not affine template recursion.
    """
    origin = table[alpha[0]]
    if origin is None:
        return False
    mapping = {0: 0}
    for d, value in enumerate(table):
        if value is None or table[alpha[d]] is None:
            return False
        vector = table[alpha[d]] ^ origin
        if vector not in mapping:
            image = len(mapping)
            mapping.update({u ^ vector: v ^ image for u, v in list(mapping.items())})
        output = mapping[vector]
        if output != value:
            return output < value
    return False


def affine_canonical_by_full_maps(table, n):
    return not any(output_minimum_smaller(table, a) for a in affine_permutations(n))


def affine_orbit(table, permutations):
    return {tuple(b[table[a[x]]] for x in range(len(table)))
            for a in permutations for b in permutations}


def ea_orbit(table, permutations, affine_maps):
    """Complete finite action oracle; used only through dimension two."""
    q = len(table)
    linear = [b for b in permutations if b[0] == 0]
    return {tuple(b[table[a[x]]] ^ c[x] for x in range(q))
            for a in permutations for b in linear for c in affine_maps}
