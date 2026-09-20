"""Affine canonicity of partial templates, based on thesis Algorithm 7.

Readable immutable reference. Composition: beta(s(alpha(x))). A rejection
returns completed affine permutations witnessing a smaller comparable prefix.
"""

from itertools import combinations
from affine_refinement import refine, complete


def smaller_witness(prefix, n):
    """Return (alpha, beta) witnessing noncanonicity, or None.

    Input may be a short prefix or a full template containing None holes.
    Comparison stops at an unknown on either side; known positions beyond
    the first hole are nevertheless usable as images under alpha.

    None means no smaller *comparable template* exists. On a complete table
    this is an exact affine canonicity test. On a partial table it is a sound
    pruning test, not a claim about every possible completion's canonicity.
    """
    q = 1 << n
    prefix = tuple(prefix)
    if not 1 <= n <= 5 or len(prefix) > q or any(
            y is not None and (not isinstance(y, int) or not 0 <= y < q) for y in prefix):
        raise ValueError("invalid dimension or prefix")
    empty = (None,) * q
    prefix += (None,) * (q - len(prefix))
    known = tuple(p for p, value in enumerate(prefix) if value is not None)

    def finish(alpha, beta):
        return complete(alpha, injective=True), complete(beta, injective=True)

    def input_step(d, alpha, beta):
        if d == q or prefix[d] is None:
            return None
        if alpha[d] is not None:
            if prefix[alpha[d]] is None:
                return None
            return output_step(d, alpha, beta)
        for value in known:
            if value in alpha:
                continue
            extended = refine(alpha, d, value, injective=True)
            if extended is not None:
                witness = output_step(d, extended, beta)
                if witness is not None:
                    return witness
        return None

    def output_step(d, alpha, beta):
        u = prefix[alpha[d]]
        if beta[u] is not None:
            if beta[u] < prefix[d]:
                return finish(alpha, beta)
            if beta[u] > prefix[d]:
                return None
            return input_step(d + 1, alpha, beta)
        for value in range(prefix[d] + 1):
            if value in beta:
                continue
            extended = refine(beta, u, value, injective=True)
            if extended is None:
                continue
            if value < prefix[d]:
                return finish(alpha, extended)
            witness = input_step(d + 1, alpha, extended)
            if witness is not None:
                return witness
        return None

    return input_step(0, empty, empty)


def search_apn(n, *, normalized=False, permutations=False, stats=None):
    """APN search with the affine filter at every depth, no cutoff.

    normalized fixes zero and the standard basis to zero, yielding weak EA
    candidates; it does not turn the affine filter into a full EA filter.
    """
    if not isinstance(n, int) or not 1 <= n <= 4:
        raise ValueError("reference classification supports n=1..4")
    if normalized and permutations:
        raise ValueError("EA zero normalization is incompatible with permutations")
    q = 1 << n
    triples = tuple(tuple((a, b, c) for a, b, c in combinations(range(d), 3)
                          if a ^ b ^ c == d) for d in range(q))
    if stats is None:
        stats = {}
    stats.update(attempted=[0] * q, apn_rejected=[0] * q,
                 affine_rejected=[0] * q, accepted=[0] * q)

    def extend(prefix):
        d = len(prefix)
        if d == q:
            yield prefix
            return
        forbidden = {prefix[a] ^ prefix[b] ^ prefix[c] for a, b, c in triples[d]}
        values = (0,) if normalized and (d == 0 or d & (d - 1) == 0) else range(q)
        for value in values:
            if permutations and value in prefix:
                continue
            stats['attempted'][d] += 1
            if value in forbidden:
                stats['apn_rejected'][d] += 1
                continue
            child = prefix + (value,)
            if smaller_witness(child, n) is not None:
                stats['affine_rejected'][d] += 1
                continue
            stats['accepted'][d] += 1
            yield from extend(child)

    yield from extend(())
