# cython: language_level=3
# distutils: extra_compile_args = -O3
"""Recursive APN/affine search with shared buffers and branch-local masks.

Supports dimensions 1..5, with an optional affine-check cutoff. No checkpoints.
Independent immutable references: lib/affine_canonicity.py and
lib/apn_propagation.py. Singleton propagation is enabled by default.
"""
from libc.stdint cimport uint8_t, uint64_t
from cpython.exc cimport PyErr_CheckSignals

cdef extern from *:
    """
    static unsigned apn_lowest(uint64_t x) { return __builtin_ctzll(x); }
    static unsigned apn_popcount(uint64_t x) { return __builtin_popcountll(x); }
    """
    unsigned lowest "apn_lowest"(uint64_t x) noexcept
    unsigned popcount "apn_popcount"(uint64_t x) noexcept


cdef void extend_map(uint8_t *table, unsigned point, unsigned value,
                     uint64_t domain, uint64_t images, unsigned q,
                     uint64_t *new_domain, uint64_t *new_images) noexcept:
    """Extend a closed affine template at an undefined point.

    Caller checks any injectivity constraint. Only new-domain slots are written.
    Parent masks remain unchanged; child values may remain stale on return.
    """
    cdef unsigned origin, i, position, image
    new_domain[0] = domain | (<uint64_t>1 << point)
    new_images[0] = images | (<uint64_t>1 << value)
    table[point] = value
    if domain == 0:
        return
    origin = 0
    while not (domain & (<uint64_t>1 << origin)):
        origin += 1
    for i in range(q):
        if domain & (<uint64_t>1 << i):
            position = origin ^ i ^ point
            image = table[origin] ^ table[i] ^ value
            table[position] = image
            new_domain[0] |= <uint64_t>1 << position
            new_images[0] |= <uint64_t>1 << image


cdef class Search:
    cdef unsigned q, defined, cutoff
    cdef uint64_t s_domain, full_mask
    cdef uint64_t allowed[32]
    # Each of at most q*q available bits can be removed only once on an
    # active branch. Store removals, not copies of the whole domain table.
    cdef uint8_t trail_position[1024]
    cdef uint64_t trail_bit[1024]
    cdef unsigned trail_top, current_position, current_decisions
    cdef uint64_t forced_assignments, exclusions, propagation_conflicts
    cdef uint64_t complete_affine_rejected
    cdef uint8_t sbox[32]
    cdef uint8_t alpha[32]
    cdef uint8_t beta[32]
    cdef uint64_t differences[32]
    cdef uint64_t attempted[32]
    cdef uint64_t apn_rejected[32]
    cdef uint64_t affine_rejected[32]
    cdef uint64_t accepted[32]
    cdef uint64_t affine_checks[32]
    cdef uint64_t affine_skips[32]
    cdef uint64_t outer_attempts, inner_nodes, count, apn_completions
    cdef bint normalized, permutations
    cdef bytearray output
    cdef object progress

    cdef int input_step(self, unsigned d, uint64_t a_domain, uint64_t a_images,
                        uint64_t b_domain, uint64_t b_images) except -1:
        cdef unsigned value
        cdef uint64_t domain, images
        self.inner_nodes += 1
        if (self.inner_nodes & 262143) == 0:
            PyErr_CheckSignals()
            self.report()
        if d == self.q or not (self.s_domain & (<uint64_t>1 << d)):
            return 0
        if a_domain & (<uint64_t>1 << d):
            if not (self.s_domain & (<uint64_t>1 << self.alpha[d])):
                return 0
            return self.output_step(d, a_domain, a_images, b_domain, b_images)
        for value in range(self.q):
            if not (self.s_domain & (<uint64_t>1 << value)) or a_images & (<uint64_t>1 << value):
                continue
            extend_map(self.alpha, d, value, a_domain, a_images, self.q, &domain, &images)
            if self.output_step(d, domain, images, b_domain, b_images):
                return 1
        return 0

    cdef int output_step(self, unsigned d, uint64_t a_domain, uint64_t a_images,
                         uint64_t b_domain, uint64_t b_images) except -1:
        cdef unsigned u = self.sbox[self.alpha[d]]
        cdef unsigned value
        cdef uint64_t domain, images
        if b_domain & (<uint64_t>1 << u):
            if self.beta[u] < self.sbox[d]:
                return 1
            if self.beta[u] > self.sbox[d]:
                return 0
            return self.input_step(d + 1, a_domain, a_images, b_domain, b_images)
        for value in range(self.sbox[d] + 1):
            if b_images & (<uint64_t>1 << value):
                continue
            extend_map(self.beta, u, value, b_domain, b_images, self.q, &domain, &images)
            if value < self.sbox[d]:
                return 1
            if self.input_step(d + 1, a_domain, a_images, domain, images):
                return 1
        return 0

    cdef void report(self) except *:
        if self.progress is not None:
            self.progress(dict(attempts=self.outer_attempts, inner_nodes=self.inner_nodes,
                candidates=self.count, depth=self.current_position,
                decision_depth=self.current_decisions, defined=popcount(self.s_domain),
                template=[self.sbox[i] if self.s_domain & (<uint64_t>1 << i) else None
                          for i in range(self.q)],
                forced_assignments=self.forced_assignments))

    cdef bint exclude(self, unsigned point, uint64_t bit, uint64_t *pending) noexcept:
        """Remove one available value and record its inverse operation."""
        if not (self.allowed[point] & bit):
            return True
        self.trail_position[self.trail_top] = point
        self.trail_bit[self.trail_top] = bit
        self.trail_top += 1
        self.allowed[point] &= ~bit
        self.exclusions += 1
        if self.allowed[point] == 0:
            return False
        if (self.allowed[point] & (self.allowed[point] - 1)) == 0:
            pending[0] |= <uint64_t>1 << point
        return True

    cdef void undo(self, unsigned marker) noexcept:
        while self.trail_top > marker:
            self.trail_top -= 1
            self.allowed[self.trail_position[self.trail_top]] |= self.trail_bit[self.trail_top]

    cdef bint assign(self, unsigned point, unsigned value, uint64_t *domain,
                     uint64_t *pending) noexcept:
        cdef unsigned i, j, fourth
        cdef uint64_t old_domain = domain[0]
        cdef uint64_t first, second, unknown, bit = <uint64_t>1 << value
        if not (self.allowed[point] & bit):
            return False
        self.sbox[point] = value
        domain[0] |= <uint64_t>1 << point
        unknown = self.full_mask & ~domain[0]
        if self.permutations:
            first = unknown
            while first:
                i = lowest(first)
                first &= first - 1
                if not self.exclude(i, bit, pending):
                    return False
        # Each pair of OLD known positions and the NEW position completes a
        # triple on an affine plane. Other triples were handled previously.
        first = old_domain
        while first:
            i = lowest(first)
            first &= first - 1
            second = first
            while second:
                j = lowest(second)
                second &= second - 1
                fourth = point ^ i ^ j
                if unknown & (<uint64_t>1 << fourth):
                    bit = <uint64_t>1 << (value ^ self.sbox[i] ^ self.sbox[j])
                    if not self.exclude(fourth, bit, pending):
                        return False
        return True

    cdef bint close(self, uint64_t *domain, uint64_t pending) noexcept:
        cdef unsigned point, value
        while pending:
            point = lowest(pending)
            pending &= pending - 1
            if domain[0] & (<uint64_t>1 << point):
                continue
            # Every pending unknown has a singleton mask unless a conflict
            # has already stopped this branch.
            value = lowest(self.allowed[point])
            self.forced_assignments += 1
            if not self.assign(point, value, domain, &pending):
                return False
        return True

    cdef void emit(self) except *:
        self.count += 1
        self.output.extend((<char *>self.sbox)[:self.q])

    cdef bint test_closed(self, uint64_t domain, unsigned position) except -1:
        """Cutoff uses known entries AFTER propagation, not decision depth."""
        cdef unsigned known = popcount(domain)
        cdef bint rejected = False
        self.s_domain = domain
        if known == self.q:
            self.apn_completions += 1
        if known < self.cutoff or known == self.q:
            self.affine_checks[known - 1] += 1
            rejected = self.input_step(0, 0, 0, 0, 0)
            if rejected:
                if position < self.q:
                    self.affine_rejected[position] += 1
                if known == self.q:
                    self.complete_affine_rejected += 1
        else:
            self.affine_skips[known - 1] += 1
        return not rejected

    cdef void walk_propagated(self, uint64_t domain, unsigned decisions) except *:
        cdef unsigned point = lowest(self.full_mask & ~domain)
        cdef unsigned value, marker
        cdef uint64_t values = self.allowed[point]
        cdef uint64_t child, pending
        while values:
            value = lowest(values)
            values &= values - 1
            self.attempted[point] += 1
            self.outer_attempts += 1
            self.current_position = point
            self.current_decisions = decisions + 1
            self.s_domain = domain
            if (self.outer_attempts & 16383) == 0:
                PyErr_CheckSignals()
                self.report()
            marker = self.trail_top
            child = domain
            pending = 0
            if not self.assign(point, value, &child, &pending) or not self.close(&child, pending):
                self.apn_rejected[point] += 1
                self.propagation_conflicts += 1
            elif self.test_closed(child, point):
                self.accepted[point] += 1
                if child == self.full_mask:
                    self.emit()
                else:
                    self.walk_propagated(child, decisions + 1)
            self.undo(marker)
            # S-box bytes stay stale; the parent's domain hides assignments
            # made in this branch, including every propagated assignment.

    cdef void walk(self, unsigned depth, uint64_t s_images) except *:
        cdef unsigned value, limit, written, a, b
        cdef uint64_t bit
        cdef bint rejected
        if depth == self.q:
            self.count += 1
            self.output.extend((<char *>self.sbox)[:self.q])
            return
        limit = 1 if self.normalized and (depth == 0 or (depth & (depth - 1)) == 0) else self.q
        for value in range(limit):
            if self.permutations and (s_images & (<uint64_t>1 << value)):
                continue
            self.attempted[depth] += 1
            self.outer_attempts += 1
            if (self.outer_attempts & 1048575) == 0:
                PyErr_CheckSignals()
                self.s_domain = (<uint64_t>1 << depth) - 1
                self.current_position = depth
                self.current_decisions = depth + 1
                self.report()
            self.sbox[depth] = value
            written = 0
            while written < depth:
                a = depth ^ written
                b = value ^ self.sbox[written]
                bit = <uint64_t>1 << b
                if self.differences[a] & bit:
                    break
                self.differences[a] |= bit
                written += 1
            if written < depth:
                self.apn_rejected[depth] += 1
            else:
                self.defined = depth + 1
                self.s_domain = (<uint64_t>1 << self.defined) - 1
                self.current_position = depth
                self.current_decisions = depth + 1
                if self.defined == self.q:
                    self.apn_completions += 1
                # Cutoff depth counts defined entries AFTER this assignment.
                # Complete functions always receive the full affine test.
                if self.defined < self.cutoff or self.defined == self.q:
                    self.affine_checks[depth] += 1
                    rejected = self.input_step(0, 0, 0, 0, 0)
                else:
                    self.affine_skips[depth] += 1
                    rejected = False
                if rejected:
                    self.affine_rejected[depth] += 1
                    if self.defined == self.q:
                        self.complete_affine_rejected += 1
                else:
                    self.accepted[depth] += 1
                    self.walk(depth + 1, s_images | (<uint64_t>1 << value))
            # Only the APN difference table needs undo writes. Affine domains
            # are passed by value; their shared buffers can remain stale.
            while written > 0:
                written -= 1
                a = depth ^ written
                b = value ^ self.sbox[written]
                self.differences[a] &= ~(<uint64_t>1 << b)


def search(n, normalized=True, permutations=False, progress=None, poison=0, cutoff=None,
           propagation=True):
    """Skip affine tests at cutoff <= defined depth < q; always test leaves.

    None (default) checks every APN-passing extension after singleton closure.
    Cutoff depth is the number of known entries, not the number of decisions.
    Set propagation=False to use the earlier prefix/difference-table search.
    Return serialized candidates, position profiles, and work counters.
    """
    if not isinstance(n, int) or not 1 <= n <= 5:
        raise ValueError('dimension must be in 1..5')
    if normalized and permutations:
        raise ValueError('zero normalization is incompatible with permutations')
    if cutoff is not None and (not isinstance(cutoff, int) or isinstance(cutoff, bool)
                               or not 1 <= cutoff <= (1 << n)):
        raise ValueError('cutoff must be None or an integer in 1..2^n')
    if not isinstance(poison, int) or not 0 <= poison <= 255:
        raise ValueError('poison must be a byte value')
    cdef Search s = Search()
    cdef uint64_t domain = 0, pending = 0
    s.q = 1 << n
    s.full_mask = (<uint64_t>1 << s.q) - 1
    s.cutoff = s.q if cutoff is None else cutoff
    s.normalized = normalized
    s.permutations = permutations
    s.output = bytearray()
    s.progress = progress
    for i in range(32):
        s.alpha[i] = s.beta[i] = s.sbox[i] = poison
    if propagation:
        for i in range(s.q):
            s.allowed[i] = s.full_mask
            if normalized and (i == 0 or (i & (i - 1)) == 0):
                s.allowed[i] = 1
                pending |= <uint64_t>1 << i
        if s.close(&domain, pending):
            if domain == s.full_mask:
                if s.test_closed(domain, s.q):
                    s.emit()
            else:
                s.walk_propagated(domain, 0)
        s.undo(0)
        for i in range(s.q):
            expected = 1 if normalized and (i == 0 or (i & (i - 1)) == 0) else s.full_mask
            if s.allowed[i] != expected:
                raise RuntimeError('exclusion rollback invariant failed')
    else:
        s.walk(0, 0)
    if any(s.differences[i] != 0 for i in range(s.q)):
        raise RuntimeError('APN rollback invariant failed')
    stats = {key: [getattr_values(s, key, i) for i in range(s.q)]
             for key in ('attempted', 'apn_rejected', 'affine_rejected', 'accepted')}
    return bytes(s.output), stats, dict(candidates=s.count, inner_nodes=s.inner_nodes,
        outer_attempts=s.outer_attempts, apn_completions=s.apn_completions,
        complete_affine_rejected=s.complete_affine_rejected,
        forced_assignments=s.forced_assignments, propagation_exclusions=s.exclusions,
        propagation_conflicts=s.propagation_conflicts,
        affine_checks_by_depth=[s.affine_checks[i] for i in range(s.q)],
        affine_skips_by_depth=[s.affine_skips[i] for i in range(s.q)])


cdef uint64_t getattr_values(Search s, str key, unsigned i):
    if key == 'attempted': return s.attempted[i]
    if key == 'apn_rejected': return s.apn_rejected[i]
    if key == 'affine_rejected': return s.affine_rejected[i]
    return s.accepted[i]


def smaller(prefix, n, poison=0):
    """Boolean filter entry point for independent reference comparisons."""
    if not isinstance(n, int) or not 1 <= n <= 5:
        raise ValueError('dimension must be in 1..5')
    if len(prefix) > (1 << n) or any(v is not None and
            (not isinstance(v, int) or not 0 <= v < (1 << n)) for v in prefix):
        raise ValueError('invalid prefix')
    if not isinstance(poison, int) or not 0 <= poison <= 255:
        raise ValueError('poison must be a byte value')
    cdef Search s = Search()
    s.q = 1 << n
    s.defined = len(prefix)
    for i in range(32):
        s.alpha[i] = s.beta[i] = s.sbox[i] = poison
    for i, value in enumerate(prefix):
        if value is not None:
            s.sbox[i] = value
            s.s_domain |= <uint64_t>1 << i
    return bool(s.input_step(0, 0, 0, 0, 0))


def refine_table(table, point, value, injective=False, poison=0):
    """Expose the masked refinement kernel for exhaustive small-state checks.

    Like the reference, assumes an already closed affine input template.
    """
    cdef unsigned q = len(table)
    if q < 2 or q > 32 or (q & (q - 1)):
        raise ValueError('table length must be 2,4,8,16,32')
    if not isinstance(point, int) or not 0 <= point < q or not isinstance(value, int) or not 0 <= value < q:
        raise ValueError('invalid assignment')
    if not isinstance(poison, int) or not 0 <= poison <= 255:
        raise ValueError('poison must be a byte value')
    cdef uint8_t buffer[32]
    cdef uint64_t domain = 0, images = 0, new_domain, new_images
    cdef unsigned i
    for i in range(q):
        buffer[i] = poison
        if table[i] is not None:
            if not isinstance(table[i], int) or not 0 <= table[i] < q:
                raise ValueError('invalid template value')
            if injective and images & (<uint64_t>1 << table[i]): return None
            buffer[i] = table[i]
            domain |= <uint64_t>1 << i
            images |= <uint64_t>1 << buffer[i]
    if domain & (<uint64_t>1 << point):
        return tuple(table) if buffer[point] == value else None
    if injective and images & (<uint64_t>1 << value): return None
    extend_map(buffer, point, value, domain, images, q, &new_domain, &new_images)
    return tuple(buffer[i] if new_domain & (<uint64_t>1 << i) else None for i in range(q))


def propagate(table, normalized=False, permutations=False, poison=0):
    """Expose singleton closure and remaining masks for independent checks.

    Returns None on contradiction, otherwise (template, masks), with None
    masks at assigned positions. This diagnostic entry point is not a search
    start/resume interface.
    """
    q = len(table)
    if q < 2 or q > 32 or q & (q - 1) or any(v is not None and
            (not isinstance(v, int) or not 0 <= v < q) for v in table):
        raise ValueError('invalid APN template')
    if normalized and permutations:
        raise ValueError('zero normalization is incompatible with permutations')
    if not isinstance(poison, int) or not 0 <= poison <= 255:
        raise ValueError('poison must be a byte value')
    cdef Search s = Search()
    cdef uint64_t domain = 0, pending = 0
    cdef bint valid = True
    s.q = q
    s.full_mask = (<uint64_t>1 << s.q) - 1
    s.permutations = permutations
    for i in range(q):
        s.sbox[i] = poison
        s.allowed[i] = s.full_mask
        if normalized and (i == 0 or (i & (i - 1)) == 0):
            s.allowed[i] = 1
            pending |= <uint64_t>1 << i
    for i, value in enumerate(table):
        if value is not None:
            if not s.assign(i, value, &domain, &pending):
                valid = False
                break
    if valid:
        valid = s.close(&domain, pending)
    result = None
    if valid:
        result = (tuple(s.sbox[i] if domain & (<uint64_t>1 << i) else None for i in range(q)),
                  tuple(None if domain & (<uint64_t>1 << i) else int(s.allowed[i]) for i in range(q)))
    s.undo(0)
    for i in range(q):
        expected = 1 if normalized and (i == 0 or (i & (i - 1)) == 0) else s.full_mask
        if s.allowed[i] != expected:
            raise RuntimeError('exclusion rollback invariant failed')
    return result
