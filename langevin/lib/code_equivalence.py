"""Exact small binary-code canonicalization, with optional marked RM subcode.

This is a modern verification/backend choice, not Langevin's recovered software.
Whole weight shells are selected until they span; all permutation witnesses
are checked against the complete row space.
"""
from sage.all import Graph
from components import rref, span, affine_words, transform


def code_graph(words, n, marked=False):
    q = 1 << n
    rows = list(rref(affine_words(n) + list(words)).values())
    all_words = span(rows)
    if marked:
        affine = set(span(affine_words(n)))
        shells = [sorted(affine - {0}), sorted(set(all_words) - affine)]
    else:
        selected = []
        for weight in sorted({w.bit_count() for w in all_words if w}):
            selected += [w for w in all_words if w.bit_count() == weight]
            if len(rref(selected)) == len(rows):
                break
        shells = [sorted(selected)]
    graph = Graph()
    graph.add_vertices(range(q + sum(map(len, shells))))
    partition = [list(range(q))]
    offset = q
    for shell in shells:
        if shell:
            partition.append(list(range(offset, offset + len(shell))))
        for j, w in enumerate(shell):
            graph.add_edges((x, offset+j) for x in range(q) if w >> x & 1)
        offset += len(shell)
    return graph, partition, rows


def canonical(words, n=5, marked=False, automorphisms=False):
    graph, partition, rows = code_graph(words, n, marked)
    _, label = graph.canonical_label(partition=partition, certificate=True, algorithm='bliss')
    q = 1 << n
    inverse = sorted(range(q), key=lambda x: label[x])
    key = tuple(rref(transform(w, inverse) for w in rows).values())
    if marked:
        key = (key, tuple(rref(transform(w, inverse) for w in affine_words(n)).values()))
    result = dict(key=key, coordinate_order=inverse)
    if automorphisms:
        group = graph.automorphism_group(partition=partition, algorithm='bliss')
        generators = [[int(g(x)) for x in range(q)] for g in group.gens()]
        basis = rref(rows)
        for p in generators:
            assert sorted(p) == list(range(q))
            assert rref(transform(w, p) for w in rows) == basis
        result.update(order=int(group.order()), generators=generators)
    return result


def equivalence_certificate(source, target, left, right, n=5):
    """A source-position -> target-position permutation and exact code check."""
    p = [0] * (1 << n)
    for x, y in zip(left['coordinate_order'], right['coordinate_order']):
        p[x] = y
    source_basis = rref(affine_words(n) + list(source))
    assert source_basis == rref(transform(w, p) for w in affine_words(n) + list(target))
    return p
