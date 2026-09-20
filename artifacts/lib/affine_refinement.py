"""Readable, immutable reconstruction of thesis Algorithms 5 and 6.

Tables use None for undefined values. A nonempty domain is an affine
subspace and the determined mapping is affine. Construct valid states with
empty_template/refine; the kernel assumes this invariant rather than checking
all triples at each call. No process-global mutable state is used.
"""


def empty_template(n):
    if not isinstance(n, int) or not 1 <= n <= 8:
        raise ValueError("dimension must be an integer from 1 through 8")
    return (None,) * (1 << n)


def refine(table, point, value, injective=False):
    """Close one assignment under affinity, or return None on conflict.

    The input must be an affinely closed template, as documented above.
    Existing assignments are checked; they are never overwritten on conflict.
    Requesting injectivity also rejects an already noninjective template.
    """
    q = len(table)
    if q < 2 or q & (q - 1):
        raise ValueError("template length must be a power of two, at least two")
    if not isinstance(point, int) or not 0 <= point < q:
        raise ValueError("point outside the input space")
    if not isinstance(value, int) or not 0 <= value < q:
        raise ValueError("value outside the output space")
    domain = [i for i, y in enumerate(table) if y is not None]
    if injective and len({table[i] for i in domain}) != len(domain):
        return None
    if table[point] is not None:
        return tuple(table) if table[point] == value else None
    result = list(table)
    if not domain:
        result[point] = value
    else:
        origin = domain[0]
        for x in domain:
            result[origin ^ x ^ point] = table[origin] ^ table[x] ^ value
    images = [y for y in result if y is not None]
    if injective and len(set(images)) != len(images):
        return None
    return tuple(result)


def complete(table, injective=False):
    """Extend greedily using the least missing input and least unused output.

    With injective=True, a valid injective affine template always has a
    completion to an affine permutation. Noninjective inputs are rejected.
    """
    table = tuple(table)
    if injective:
        images = [v for v in table if v is not None]
        if len(set(images)) != len(images):
            return None
    while None in table:
        point = table.index(None)
        value = next(v for v in range(len(table)) if v not in table)
        table = refine(table, point, value, injective=injective)
        if table is None:
            return None
    return table

