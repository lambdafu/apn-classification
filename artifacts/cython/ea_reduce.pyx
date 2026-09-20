# cython: language_level=3
# distutils: extra_compile_args = -O3
"""Exact EA equivalence by affine input refinement and forced output maps.

Gamma is eliminated using values at zero and the standard basis. The search
still enumerates affine alpha and refines injective linear beta; no code or
stabilizer machinery is used. Returned maps satisfy target=beta(source(alpha))+gamma.
"""
from libc.stdint cimport uint8_t, uint64_t
from cpython.exc cimport PyErr_CheckSignals

cdef class Solver:
    cdef unsigned q, n
    cdef uint8_t source[32]
    cdef uint8_t target[32]
    cdef uint8_t alpha[32]
    cdef uint8_t beta[32]
    cdef uint64_t nodes
    cdef bint quadratic

    cdef bint step(self, unsigned x, unsigned size, uint64_t a_images,
                   uint64_t b_domain, uint64_t b_images) except -1:
        cdef unsigned image, i, point, value, s, t, y
        cdef uint64_t domain, images
        self.nodes += 1
        if (self.nodes & 262143) == 0:
            PyErr_CheckSignals()
        if x == self.q:
            # Complete the determined injective linear output map.
            for point in range(self.q):
                if b_domain & (<uint64_t>1 << point):
                    continue
                value = 0
                while b_images & (<uint64_t>1 << value):
                    value += 1
                domain, images = b_domain, b_images
                for i in range(self.q):
                    if b_domain & (<uint64_t>1 << i):
                        y = self.beta[i] ^ value
                        self.beta[i ^ point] = y
                        domain |= <uint64_t>1 << (i ^ point)
                        images |= <uint64_t>1 << y
                b_domain, b_images = domain, images
            return True
        if x == size:
            # alpha is known on the prefix affine subspace [0,size).
            # Choose the image of the next basis vector, then close its coset.
            for image in range(self.q):
                if a_images & (<uint64_t>1 << image):
                    continue
                images = a_images
                for i in range(size):
                    y = self.alpha[0] ^ self.alpha[i] ^ image
                    self.alpha[i ^ size] = y
                    images |= <uint64_t>1 << y
                if self.step(x, size*2, images, b_domain, b_images):
                    return True
            return False
        # Source and target after removing their affine interpolation on the
        # input affine basis. beta must identify these normalized values.
        s = self.source[self.alpha[x]] ^ self.source[self.alpha[0]]
        t = self.target[x] ^ self.target[0]
        for i in range(self.n):
            if x & (1 << i):
                s ^= self.source[self.alpha[1 << i]] ^ self.source[self.alpha[0]]
                t ^= self.target[1 << i] ^ self.target[0]
        if b_domain & (<uint64_t>1 << s):
            if self.beta[s] != t:
                return False
            return self.step(x+1,size,a_images,b_domain,b_images)
        if b_images & (<uint64_t>1 << t):
            return False
        domain, images = b_domain, b_images
        for i in range(self.q):
            if b_domain & (<uint64_t>1 << i):
                y = self.beta[i] ^ t
                self.beta[i ^ s] = y
                domain |= <uint64_t>1 << (i ^ s)
                images |= <uint64_t>1 << y
        return self.step(x+1,size,a_images,domain,images)


def witness(source, target, translation_reduction=True):
    """Return (alpha,beta,gamma), or None after exhausting admissible inputs.

    For source degree <=2, input translation changes it by an affine map,
    absorbable in gamma. Fixing alpha(0)=0 is then exact, not heuristic.
    Disable this reduction for independent finite comparisons.
    """
    from apn_reference import validate_table
    from ea_equivalence import algebraic_degree
    n = validate_table(source)
    if n > 5 or validate_table(target) != n:
        raise ValueError('requires equal dimensions <=5')
    cdef Solver solver = Solver()
    solver.n, solver.q = n, 1 << n
    cdef unsigned x, origin
    for x in range(solver.q):
        solver.source[x], solver.target[x] = source[x], target[x]
    solver.quadratic = translation_reduction and algebraic_degree(source) <= 2
    for origin in range(1 if solver.quadratic else solver.q):
        solver.alpha[0] = origin
        solver.beta[0] = 0
        if solver.step(1,1,<uint64_t>1 << origin,1,1):
            a = tuple(solver.alpha[x] for x in range(solver.q))
            b = tuple(solver.beta[x] for x in range(solver.q))
            g = tuple(target[x] ^ b[source[a[x]]] for x in range(solver.q))
            return (a,b,g), int(solver.nodes)
    return None, int(solver.nodes)
