"""Readable exact affine equivalence: target = beta(source(alpha))."""
from affine_refinement import refine, complete


def equivalence_witness(source, target):
    q = len(source)
    if q != len(target) or q < 2 or q & (q - 1):
        raise ValueError('incompatible table lengths')
    if any(not isinstance(v, int) or not 0 <= v < q for v in (*source, *target)):
        raise ValueError('invalid table entry')

    def visit(d, alpha, beta):
        if d == q:
            return complete(alpha, injective=True), complete(beta, injective=True)
        values = range(q) if alpha[d] is None else (alpha[d],)
        for value in values:
            a = refine(alpha, d, value, injective=True)
            if a is None:
                continue
            b = refine(beta, source[value], target[d], injective=True)
            if b is not None:
                result = visit(d + 1, a, b)
                if result is not None:
                    return result
        return None

    return visit(0, (None,) * q, (None,) * q)


def verify_witness(source, target, witness):
    if witness is None:
        raise ValueError('missing affine witness')
    q = len(source)
    for table in witness:
        if len(table) != q or sorted(table) != list(range(q)):
            raise ValueError('not a permutation')
        for x in range(q):
            value = table[0]
            for i in range(q.bit_length() - 1):
                if x & (1 << i):
                    value ^= table[1 << i] ^ table[0]
            if value != table[x]:
                raise ValueError('not affine')
    a, b = witness
    if any(target[x] != b[source[a[x]]] for x in range(q)):
        raise ValueError('affine equation fails')
    return True
