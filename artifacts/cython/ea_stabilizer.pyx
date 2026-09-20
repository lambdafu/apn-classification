# cython: language_level=3
# distutils: extra_compile_args = -O3
"""Three-template recursive EA search with target-stabilizer orbit pruning.

Shared value buffers and copied masks preserve the historical storage design.
Gamma is explicitly refined; it is not eliminated by normalization here.
"""
from libc.stdint cimport uint8_t, uint64_t
from cpython.exc cimport PyErr_CheckSignals


cdef class Search:
    cdef unsigned q
    cdef uint8_t source[32]
    cdef uint8_t target[32]
    cdef uint8_t alpha[32]
    cdef uint8_t beta[32]
    cdef uint8_t gamma[32]
    cdef uint8_t best_alpha[32]
    cdef uint8_t best_beta[32]
    cdef uint8_t best_gamma[32]
    cdef uint64_t orbits[32]
    cdef unsigned orbit_size[32]
    cdef bint exclude_identity
    cdef bint found
    cdef bint propagation
    cdef uint64_t nodes, beta_attempts, rejections

    cdef uint64_t extend(self, uint8_t *values, unsigned point, unsigned value,
                         uint64_t domain) noexcept:
        cdef unsigned i
        cdef uint64_t result = domain | (<uint64_t>1 << point)
        values[point] = value
        if domain:
            for i in range(self.q):
                if domain & (<uint64_t>1 << i):
                    values[i ^ point] = values[0] ^ values[i] ^ value
                    result |= <uint64_t>1 << (i ^ point)
        return result

    cdef uint64_t images(self, uint8_t *values, uint64_t domain) noexcept:
        cdef unsigned i
        cdef uint64_t result = 0
        for i in range(self.q):
            if domain & (<uint64_t>1 << i):
                result |= <uint64_t>1 << values[i]
        return result

    cdef bint propagate(self, uint64_t ad, uint64_t *bd, uint64_t *bi,
                        uint64_t *cd) noexcept:
        """Close forced equations at all known alpha positions, to a fixed point."""
        cdef unsigned x, u, value
        cdef uint64_t before_b, before_c
        while True:
            before_b, before_c = bd[0], cd[0]
            for x in range(self.q):
                if not ad & (<uint64_t>1 << x):
                    continue
                u = self.source[self.alpha[x]]
                if bd[0] & (<uint64_t>1 << u):
                    value = self.target[x] ^ self.beta[u]
                    if cd[0] & (<uint64_t>1 << x):
                        if self.gamma[x] != value:
                            return False
                    else:
                        cd[0] = self.extend(self.gamma, x, value, cd[0])
                elif cd[0] & (<uint64_t>1 << x):
                    value = self.target[x] ^ self.gamma[x]
                    if bi[0] & (<uint64_t>1 << value):
                        return False
                    bd[0] = self.extend(self.beta, u, value, bd[0])
                    bi[0] = self.images(self.beta, bd[0])
            if bd[0] == before_b and cd[0] == before_c:
                return True

    cdef bint canonical(self, uint64_t domain) noexcept:
        cdef unsigned x, y, minimum
        cdef uint64_t used
        if self.found:
            for x in range(self.q):
                if not domain & (<uint64_t>1 << x):
                    break
                if self.alpha[x] < self.best_alpha[x]:
                    break
                if self.alpha[x] > self.best_alpha[x]:
                    return False
            else:
                return False
        for x in range(self.q):
            if not domain & (<uint64_t>1 << x):
                continue
            if self.orbit_size[x] == self.q - x:
                used = 0
                for y in range(x):
                    used |= <uint64_t>1 << self.alpha[y]
                minimum = 0
                while used & (<uint64_t>1 << minimum):
                    minimum += 1
                if self.alpha[x] != minimum:
                    return False
            for y in range(self.q):
                if self.orbits[x] & domain & (<uint64_t>1 << y):
                    if self.alpha[y] < self.alpha[x]:
                        return False
        return True

    cdef int input_step(self, unsigned x, uint64_t ad, uint64_t ai,
                       uint64_t bd, uint64_t bi, uint64_t cd) except -1:
        cdef unsigned value, i
        cdef uint64_t domain
        self.nodes += 1
        if (self.nodes & 262143) == 0:
            PyErr_CheckSignals()
        if x == self.q:
            if self.exclude_identity:
                if all(self.alpha[i] == i for i in range(self.q)):
                    return 0
            # Complete an injective beta if its domain has not yet spanned.
            for i in range(self.q):
                if bd & (<uint64_t>1 << i):
                    continue
                value = 0
                while bi & (<uint64_t>1 << value):
                    value += 1
                bd = self.extend(self.beta, i, value, bd)
                bi = self.images(self.beta, bd)
            for i in range(self.q):
                self.best_alpha[i] = self.alpha[i]
                self.best_beta[i] = self.beta[i]
                self.best_gamma[i] = self.gamma[i]
            self.found = True
            return 0
        if ad & (<uint64_t>1 << x):
            self.output_step(x, ad, ai, bd, bi, cd)
            return 0
        for value in range(self.q):
            if ai & (<uint64_t>1 << value):
                continue
            domain = self.extend(self.alpha, x, value, ad)
            if not self.canonical(domain):
                self.rejections += 1
                continue
            self.output_step(x, domain, self.images(self.alpha, domain), bd, bi, cd)
        return 0

    cdef int output_step(self, unsigned x, uint64_t ad, uint64_t ai,
                        uint64_t bd, uint64_t bi, uint64_t cd) except -1:
        cdef unsigned u = self.source[self.alpha[x]]
        cdef unsigned value, start = 0, end = self.q
        cdef uint64_t domain
        if self.propagation and not self.propagate(ad, &bd, &bi, &cd):
            return 0
        if bd & (<uint64_t>1 << u):
            self.correction_step(x, ad, ai, bd, bi, cd)
            return 0
        if cd & (<uint64_t>1 << x):
            start = self.target[x] ^ self.gamma[x]
            end = start + 1
        for value in range(start, end):
            if bi & (<uint64_t>1 << value):
                continue
            self.beta_attempts += 1
            domain = self.extend(self.beta, u, value, bd)
            self.correction_step(x, ad, ai, domain, self.images(self.beta, domain), cd)
        return 0

    cdef int correction_step(self, unsigned x, uint64_t ad, uint64_t ai,
                            uint64_t bd, uint64_t bi, uint64_t cd) except -1:
        cdef unsigned value = self.target[x] ^ self.beta[self.source[self.alpha[x]]]
        if cd & (<uint64_t>1 << x):
            if self.gamma[x] != value:
                return 0
        else:
            cd = self.extend(self.gamma, x, value, cd)
        self.input_step(x + 1, ad, ai, bd, bi, cd)
        return 0


def search(source, target, orbits=None, exclude_identity=False, propagation=True):
    from apn_reference import validate_table
    n = validate_table(source)
    if n > 5 or validate_table(target) != n:
        raise ValueError('requires equal dimensions at most five')
    cdef Search solver = Search()
    cdef unsigned i, y
    solver.q = len(source)
    solver.exclude_identity = exclude_identity
    solver.propagation = propagation
    if orbits is None:
        orbits = [(x,) for x in range(solver.q)]
    if len(orbits) != solver.q:
        raise ValueError('one orbit required per point')
    for i in range(solver.q):
        solver.source[i], solver.target[i] = source[i], target[i]
        if i not in orbits[i] or any(y < i or y >= solver.q for y in orbits[i]):
            raise ValueError('invalid prefix stabilizer orbit')
        solver.orbits[i] = sum(1 << int(y) for y in set(orbits[i]))
        solver.orbit_size[i] = len(set(orbits[i]))
    solver.beta[0] = 0
    solver.input_step(0, 0, 0, 1, 1, 0)
    witness = None
    if solver.found:
        witness = (tuple(solver.best_alpha[i] for i in range(solver.q)),
                   tuple(solver.best_beta[i] for i in range(solver.q)),
                   tuple(solver.best_gamma[i] for i in range(solver.q)))
    return witness, dict(input_nodes=int(solver.nodes), beta_attempts=int(solver.beta_attempts),
                         input_filter_rejections=int(solver.rejections))
