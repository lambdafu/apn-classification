"""Integer reference operations for output-component APN extension.

Bit x of a word is its value at input x; input variable a is the low bit.
No representatives from the earlier APN classification are used here.
"""
from itertools import combinations, product
import re


def planes(n):
    return [sum(1 << x for x in (a, b, c, a ^ b ^ c))
            for a, b, c in combinations(range(1 << n), 3) if a ^ b ^ c > c]


def affine_words(n):
    q = 1 << n
    return [(1 << q) - 1] + [sum(((x >> i) & 1) << x for x in range(q))
                             for i in range(n)]


def rref(words):
    """Unique reduced binary basis, pivoting from the lowest bit."""
    basis = {}
    for w in words:
        w = reduce(w, basis)
        if w:
            p = (w & -w).bit_length() - 1
            basis = {i: v ^ w if (v >> p) & 1 else v for i, v in basis.items()}
            basis[p] = w
    return dict(sorted(basis.items()))


def reduce(word, basis):
    for p, row in sorted(basis.items()):
        if word >> p & 1:
            word ^= row
    return word


def span(words):
    values = [0]
    for w in words:
        values += [x ^ w for x in values]
    return values


def table(words, n):
    return [sum(((w >> x) & 1) << i for i, w in enumerate(words)) for x in range(1 << n)]


def unresolved(words, n):
    return [p for p in planes(n) if all((p & w).bit_count() % 2 == 0 for w in words)]


def quotient(words, n):
    basis = rref(affine_words(n) + list(words))
    free = [x for x in range(1 << n) if x not in basis]
    return basis, free


def pack(word, positions):
    return sum(((word >> p) & 1) << i for i, p in enumerate(positions))


def unpack(index, positions):
    return sum(((index >> i) & 1) << p for i, p in enumerate(positions))


def character_sum(word, constraints):
    return sum(1 - 2 * ((word & p).bit_count() % 2) for p in constraints)


def good_extensions(words, n):
    constraints = unresolved(words, n)
    _, free = quotient(words, n)
    denominator = (1 << (n - len(words))) - 1
    for index in range(1, 1 << len(free)):
        word = unpack(index, free)
        if character_sum(word, constraints) * denominator <= -len(constraints):
            yield word


def capacity_ok(words, n):
    """Each derivative bin must fit into the remaining output bits."""
    values = table(words, n)
    capacity = 1 << (n - len(words))
    for a in range(1, 1 << n):
        counts = {}
        for x in range(1 << n):
            if x < x ^ a:
                b = values[x] ^ values[x ^ a]
                counts[b] = counts.get(b, 0) + 1
                if counts[b] > capacity:
                    return False
    return True


def transform(word, permutation):
    return sum(((word >> permutation[x]) & 1) << x for x in range(len(permutation)))


def parse_permutation(line, n=5):
    vectors = re.findall('[01]{%d}' % n, line)
    columns = [sum(int(c) << i for i, c in enumerate(v)) for v in vectors]
    assert len(columns) == n + 1
    result = []
    for x in range(1 << n):
        y = columns[-1]
        for i in range(n):
            if x >> i & 1:
                y ^= columns[i]
        result.append(y)
    assert sorted(result) == list(range(1 << n))
    return result


def parse_seeds(text):
    seeds = []
    for block in text.split('fct=')[1:]:
        lines = block.splitlines()
        values = list(map(int, lines[0].split()))
        assert len(values) == 32 and set(values) <= {0, 1}
        seeds.append(dict(word=sum(v << x for x, v in enumerate(values)),
                          generators=[parse_permutation(s) for s in lines[1:] if s.startswith('[')],
                          stabilizer=int(next(s[5:] for s in lines if s.startswith('size=')))))
    return seeds


def parse_boolean_classes(text):
    rows = []
    for block in text.split('hdr=')[1:]:
        lines = block.splitlines()
        anf = lines[0]
        terms = [] if anf == '0' else [sum(1 << (ord(c) - 97) for c in term) for term in anf.split('+')]
        word = sum((sum(x & m == m for m in terms) % 2) << x for x in range(32))
        rows.append(dict(anf=anf, word=word,
                         generators=[parse_permutation(s) for s in lines[1:] if s.startswith('[')],
                         stabilizer=int(next(s[4:] for s in lines if s.startswith('fix=')))))
    return rows


def last_components(words, n):
    """Solve every unresolved plane parity = 1, with quotient pivots fixed 0."""
    _, free = quotient(words, n)
    basis = {}
    width = len(free)
    for p in unresolved(words, n):
        equation = pack(p, free) | (1 << width)
        for pivot, row in sorted(basis.items()):
            if equation >> pivot & 1:
                equation ^= row
        lhs = equation & ((1 << width) - 1)
        if not lhs:
            if equation >> width:
                return []
        else:
            pivot = (lhs & -lhs).bit_length() - 1
            basis[pivot] = equation
    unbound = [i for i in range(width) if i not in basis]
    result = []
    for bits in product((0, 1), repeat=len(unbound)):
        value = sum(b << i for i, b in zip(unbound, bits))
        for pivot, row in sorted(basis.items(), reverse=True):
            rhs = ((row >> width) ^ (row & value).bit_count()) & 1
            value |= rhs << pivot
        result.append(unpack(value, free))
    return result


def complete_two(words, n):
    """Readable immutable constraint search, with no color-symmetry pruning."""
    constraints = [tuple(i for i in range(1 << n) if p >> i & 1)
                   for p in unresolved(words, n)]
    pivots = quotient(words, n)[0]
    initial = tuple(0 if x in pivots else None for x in range(1 << n))

    def visit(values):
        domains = [{0, 1, 2, 3} if v is None else {v} for v in values]
        for plane in constraints:
            missing = [x for x in plane if values[x] is None]
            parity = 0
            for x in plane:
                if values[x] is not None:
                    parity ^= values[x]
            if not missing and parity == 0:
                return None
            if len(missing) == 1:
                domains[missing[0]].discard(parity)
        unassigned = [x for x in range(1 << n) if values[x] is None]
        if not unassigned:
            return values
        x = min(unassigned, key=lambda i: (len(domains[i]), i))
        for v in sorted(domains[x]):
            result = visit(values[:x] + (v,) + values[x+1:])
            if result is not None:
                return result
        return None

    result = visit(initial)
    if result is None:
        return None
    return [sum(((v >> j) & 1) << x for x, v in enumerate(result)) for j in range(2)]
