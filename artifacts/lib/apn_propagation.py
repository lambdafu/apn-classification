"""Readable APN propagation on templates with arbitrary defined positions.

Recompute constraints from four-point affine planes, independently of the
compiled incremental exclusion masks and rollback trail.
"""
from functools import lru_cache
from apn_reference import affine_planes
from affine_canonicity import smaller_witness


@lru_cache(None)
def planes(q):
    return affine_planes(q)


def available_values(table, *, normalized=False, permutations=False):
    """Return remaining value sets, or None for an already inconsistent table.

    A known position has the singleton containing its assigned value. Domains
    express the constraints visible now, not all possible APN completions.
    """
    q = len(table)
    if q < 2 or q > 32 or q & (q - 1) or any(
            v is not None and (not isinstance(v, int) or not 0 <= v < q)
            for v in table):
        raise ValueError('invalid APN template')
    if normalized and permutations:
        raise ValueError('zero normalization is incompatible with permutations')
    domains = [set(range(q)) if v is None else {v} for v in table]
    if normalized:
        for p in [0] + [1 << i for i in range(q.bit_length() - 1)]:
            domains[p].intersection_update({0})
    if permutations:
        known = [v for v in table if v is not None]
        if len(known) != len(set(known)):
            return None
        for p, v in enumerate(table):
            if v is None:
                domains[p].difference_update(known)
    for plane in planes(q):
        unknown = [p for p in plane if table[p] is None]
        if len(unknown) > 1:
            continue
        value = 0
        for p in plane:
            if table[p] is not None:
                value ^= table[p]
        if not unknown:
            if value == 0:
                return None
        else:
            domains[unknown[0]].discard(value)
    return domains if all(domains) else None


def close_template(table, *, normalized=False, permutations=False):
    """Fill singleton domains repeatedly; None denotes a contradiction."""
    table = tuple(table)
    while True:
        domains = available_values(table, normalized=normalized, permutations=permutations)
        if domains is None:
            return None
        child = tuple(next(iter(domains[p])) if v is None and len(domains[p]) == 1
                      else v for p, v in enumerate(table))
        if child == table:
            return table
        table = child


def search_propagated(n, *, normalized=False, permutations=False, cutoff=None):
    """Immutable search oracle with singleton closure and sparse affine tests."""
    if not isinstance(n, int) or not 1 <= n <= 4:
        raise ValueError('reference classification supports n=1..4')
    q = 1 << n
    if cutoff is not None and (not isinstance(cutoff, int) or isinstance(cutoff, bool)
                               or not 1 <= cutoff <= q):
        raise ValueError('invalid cutoff')
    cutoff = q if cutoff is None else cutoff

    def visit(table):
        closed = close_template(table, normalized=normalized, permutations=permutations)
        if closed is None:
            return
        known = sum(v is not None for v in closed)
        if (known < cutoff or known == q) and smaller_witness(closed, n) is not None:
            return
        if known == q:
            yield closed
            return
        point = closed.index(None)
        domains = available_values(closed, normalized=normalized, permutations=permutations)
        for value in sorted(domains[point]):
            yield from visit(closed[:point] + (value,) + closed[point + 1:])

    yield from visit((None,) * q)
