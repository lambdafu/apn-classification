"""CCZ code equivalence and EA stabilizers using Sage and checked witnesses.

Coordinates are (1, x_0,...,x_(n-1), s_0,...,s_(n-1)). Bit order is LSB first.
Code coordinates are indexed by x, and Sage permutation points by x+1.
"""
import hashlib
import json
from sage.all import GF, Graph, LinearCode, PermutationGroup, matrix, vector
from apn_reference import validate_table


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def binary_rank(words):
    basis = {}
    for value in words:
        value = int(value)
        while value:
            bit = value.bit_length() - 1
            if bit in basis:
                value ^= basis[bit]
            else:
                basis[bit] = value
                break
    return len(basis)


def bits(value, n):
    return [(int(value) >> i) & 1 for i in range(n)]


def encode(values):
    return sum(int(v) << i for i, v in enumerate(values))


def graph_matrix(table):
    n = validate_table(table)
    q = len(table)
    return matrix(GF(2), [[1] * q] +
                  [[(x >> i) & 1 for x in range(q)] for i in range(n)] +
                  [[(y >> i) & 1 for y in table] for i in range(n)])


def affine_input_group(n):
    """Translations and elementary transvections generate AGL(n,2)."""
    q = 1 << n
    gens = [[(x ^ (1 << i)) + 1 for x in range(q)] for i in range(n)]
    for i in range(n):
        for j in range(n):
            if i != j:
                gens.append([(x ^ (((x >> j) & 1) << i)) + 1 for x in range(q)])
    group = PermutationGroup(gens, domain=list(range(1, q + 1)))
    expected = q
    for i in range(n):
        expected *= q - (1 << i)
    require(int(group.order()) == expected, 'affine input group order fails')
    return group


def spanning_word_graph(code):
    """Invariant spanning word set encoded as a colored incidence graph.

    Include the all-one word if present, then whole positive-weight shells in
    increasing order until they span the code. Checking rank is essential:
    minimum-weight words alone need not span (published n=5 row 5 is a case).
    """
    q = int(code.length())
    if code.dimension() > 12:
        raise ValueError('this reference graph backend enumerates codes of dimension <=12')
    shells = {}
    for word in code:
        value = encode(word)
        if value:
            shells.setdefault(value.bit_count(), []).append(value)
    selected = set(shells.get(q, []))
    weights = []
    for weight in sorted(shells):
        if binary_rank(selected) == code.dimension():
            break
        selected.update(shells[weight])
        weights.append(weight)
    require(binary_rank(selected) == code.dimension(), 'selected words do not span code')
    words = sorted(selected)
    graph = Graph()
    graph.add_vertices(range(q + len(words)))
    graph.add_edges((i, q + j) for j, word in enumerate(words)
                    for i in range(q) if word & (1 << i))
    partition = [list(range(q)), list(range(q, q + len(words)))]
    partition = [cell for cell in partition if cell]
    return graph, partition, dict(word_count=len(words), selected_positive_weight_shells=weights,
                                 includes_all_one=(1 << q) - 1 in selected,
                                 spanning_rank=binary_rank(words))


def canonical_code(table):
    """Exact canonical code via an invariant colored spanning-word graph."""
    M = graph_matrix(table)
    code = LinearCode(M)
    graph, partition, selection = spanning_word_graph(code)
    canonical_graph, certificate = graph.canonical_label(
        partition=partition, certificate=True, algorithm='bliss')
    q = len(table)
    point_labels = [int(certificate[x]) for x in range(q)]
    require(sorted(point_labels) == list(range(q)), 'canonical graph mixes coordinate colors')
    inverse = [point_labels.index(x) for x in range(q)]
    canonical_matrix = M.matrix_from_columns(inverse).row_space().basis_matrix()
    fingerprint = hashlib.sha256(json.dumps(
        [q, graph.order(), sorted(tuple(sorted((int(a), int(b))))
                                 for a, b in canonical_graph.edge_iterator(labels=False))],
        separators=(',', ':')).encode()).hexdigest()
    return dict(matrix=M, code=code, graph=graph, partition=partition,
                canonical_graph=canonical_graph, point_labels=point_labels,
                canonical_matrix=canonical_matrix, fingerprint=fingerprint,
                selection=selection)


def equivalent_permutation(source_info, target_info):
    """Return source-coordinate -> target-coordinate bijection, or None."""
    if (len(source_info['point_labels']) != len(target_info['point_labels']) or
            source_info['canonical_graph'] != target_info['canonical_graph']):
        return None
    require(source_info['canonical_matrix'] == target_info['canonical_matrix'],
            'equal canonical graphs yielded different codes')
    inverse_target = {label: x for x, label in enumerate(target_info['point_labels'])}
    return [inverse_target[label] for label in source_info['point_labels']]


def lift_graph_permutation(source, target, permutation):
    """Extend the induced affine graph isomorphism to the ambient space.

    Works even for rank-deficient graph matrices: extend corresponding bases
    of difference spans independently to full ambient bases.
    """
    n = validate_table(source)
    require(validate_table(target) == n, 'dimension mismatch')
    q = len(source)
    require(sorted(permutation) == list(range(q)), 'invalid graph permutation')
    M, N = graph_matrix(source), graph_matrix(target).matrix_from_columns(permutation)
    require(M.row_space() == N.row_space(), 'permutation does not identify graph row codes')
    # Dual row spaces transform under the same coordinate permutation.
    require(M.right_kernel() == N.right_kernel(), 'dual code witness fails')
    z = [x | (int(source[x]) << n) for x in range(q)]
    w = [permutation[x] | (int(target[permutation[x]]) << n) for x in range(q)]
    left, right = [], []
    for x in range(q):
        a, b = z[x] ^ z[0], w[x] ^ w[0]
        if binary_rank(left + [a]) > len(left):
            left.append(a)
            right.append(b)
    require(binary_rank(right) == len(left), 'graph map collapses affine span')
    for basis in (left, right):
        for i in range(2 * n):
            if binary_rank(basis + [1 << i]) > len(basis):
                basis.append(1 << i)
    A = matrix(GF(2), [bits(v, 2 * n) for v in left]).transpose()
    B = matrix(GF(2), [bits(v, 2 * n) for v in right]).transpose()
    linear = B * A.inverse()
    offset = vector(GF(2), bits(w[0], 2 * n)) + linear * vector(GF(2), bits(z[0], 2 * n))
    T = matrix(GF(2), 1 + 2 * n, 1 + 2 * n)
    T[0, 0] = 1
    for i in range(2 * n):
        T[i + 1, 0] = offset[i]
        for j in range(2 * n):
            T[i + 1, j + 1] = linear[i, j]
    witness = [[int(v) for v in row] for row in T.rows()]
    verify_graph_witness(source, target, permutation, witness)
    return witness


def verify_graph_witness(source, target, permutation, augmented_matrix):
    """Pure integer verification, independent of Sage's code/matrix routines."""
    n = validate_table(source)
    require(validate_table(target) == n, 'dimension mismatch')
    q = len(source)
    size = 1 + 2 * n
    require(len(augmented_matrix) == size and all(len(row) == size for row in augmented_matrix),
            'invalid augmented matrix shape')
    require(all(v in (0, 1) for row in augmented_matrix for v in row), 'nonbinary matrix')
    require(augmented_matrix[0] == [1] + [0] * (2 * n), 'map is not affine')
    require(sorted(permutation) == list(range(q)), 'graph mapping is not a permutation')
    rows = [encode(row) for row in augmented_matrix]
    require(binary_rank([row >> 1 for row in rows[1:]]) == 2 * n, 'ambient map not invertible')
    for x in range(q):
        point = 1 | (x << 1) | (int(source[x]) << (n + 1))
        image = sum(((row & point).bit_count() & 1) << i for i, row in enumerate(rows))
        y = permutation[x]
        require(image == 1 | (y << 1) | (int(target[y]) << (n + 1)), 'graph-map equation fails')


def affine_table(table, *, invertible=False, linear=False):
    """Pure integer check of an affine lookup table."""
    n = validate_table(table)
    offset = table[0]
    if linear and offset != 0:
        return False
    columns = [table[1 << i] ^ offset for i in range(n)]
    for x, value in enumerate(table):
        predicted = offset
        for i in range(n):
            if x & (1 << i):
                predicted ^= columns[i]
        if value != predicted:
            return False
    return not invertible or len(set(table)) == len(table)


def lift_ea_input(table, alpha):
    """Solve uniquely for beta and gamma in table = beta(table(alpha)) + gamma."""
    n = validate_table(table)
    require(affine_table(alpha, invertible=True), 'EA input is not an affine permutation')
    q = len(table)
    composed = [table[alpha[x]] for x in range(q)]
    M = graph_matrix(composed)
    require(M.rank() == 1 + 2 * n, 'EA lifting requires full graph affine span')
    target = graph_matrix(table).matrix_from_rows(list(range(n + 1, 2 * n + 1)))
    columns = list(M.pivots())
    coefficients = target.matrix_from_columns(columns) * M.matrix_from_columns(columns).inverse()
    require(coefficients * M == target, 'EA correction does not extend to every input')
    B = coefficients.matrix_from_columns(list(range(n + 1, 2 * n + 1)))
    require(B.is_invertible(), 'EA output map is not invertible')
    correction = coefficients.matrix_from_columns(list(range(n + 1)))
    beta = [encode(B * vector(GF(2), bits(x, n))) for x in range(q)]
    gamma = [encode(correction * vector(GF(2), [1] + bits(x, n))) for x in range(q)]
    require(affine_table(beta, invertible=True, linear=True) and affine_table(gamma),
            'EA maps are not linear/affine')
    require(all(beta[table[alpha[x]]] ^ gamma[x] == table[x] for x in range(q)),
            'EA stabilizer equation fails')
    return dict(alpha=alpha, beta=beta, gamma=gamma)


def ea_stabilizer(table, info, affine_group):
    """Compute full code automorphisms, then intersect with affine inputs.

    Independently compare Miller's code automorphisms with Bliss automorphisms
    of the spanning-word graph. Full graph rank makes the EA lift unique.
    """
    n = validate_table(table)
    q = len(table)
    require(info['matrix'].rank() == 1 + 2 * n, 'EA stabilizer requires full graph affine span')
    code_group = info['code'].permutation_automorphism_group(algorithm='partition')
    graph_group = info['graph'].automorphism_group(partition=info['partition'], algorithm='bliss')
    restricted = PermutationGroup([[int(g(x)) + 1 for x in range(q)] for g in graph_group.gens()],
                                  domain=list(range(1, q + 1)))
    require(int(graph_group.order()) == int(restricted.order()), 'graph action has a kernel on coordinates')
    require(restricted == code_group, 'independent full code automorphism groups disagree')
    # All returned code generators have a directly checked affine graph lift.
    code_generators = []
    for g in code_group.gens():
        p = [int(g(x + 1)) - 1 for x in range(q)]
        T = lift_graph_permutation(table, table, p)
        code_generators.append(dict(permutation=p, augmented_graph_map=T))
    H = code_group.intersection(affine_group)
    witnesses = [lift_ea_input(table, [int(g(x + 1)) - 1 for x in range(q)]) for g in H.gens()]
    generated = PermutationGroup([[x + 1 for x in w['alpha']] for w in witnesses],
                                 domain=list(range(1, q + 1)))
    require(generated == H, 'EA witnesses do not generate the intersection')
    return dict(code_automorphism_order=int(code_group.order()),
                graph_automorphism_order=int(graph_group.order()),
                ea_stabilizer_order=int(H.order()),
                code_generators=code_generators, ea_generators=witnesses)


def ea_group_order(n):
    q = 1 << n
    gl = 1
    for i in range(n):
        gl *= q - (1 << i)
    return (q * gl) * gl * (q ** (n + 1))
