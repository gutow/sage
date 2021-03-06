"""
Lean matrices

Internal data structures for the ``LinearMatroid`` class and some subclasses.
Note that many of the methods are ``cdef``, and therefore only available from
Cython code.

.. warning::

    Intended for internal use by the ``LinearMatroid`` classes only. End users
    should work with Sage matrices instead. Methods that are used outside
    lean_matrix.pyx and have no equivalent in Sage's ``Matrix`` have been
    flagged in the code, as well as where they are used, by ``# Not a Sage
    matrix operation`` or ``# Deprecated Sage matrix operation``.

AUTHORS:

- Rudi Pendavingh, Stefan van Zwam (2013-04-01): initial version

"""
#*****************************************************************************
#       Copyright (C) 2013 Rudi Pendavingh <rudi.pendavingh@gmail.com>
#       Copyright (C) 2013 Stefan van Zwam <stefanvanzwam@gmail.com>
#
#
#  Distributed under the terms of the GNU General Public License (GPL)
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

include 'sage/ext/stdsage.pxi'
include 'sage/misc/bitset.pxi'
from sage.matrix.matrix2 cimport Matrix
from sage.rings.all import ZZ, FiniteField, GF
from sage.rings.integer cimport Integer
import sage.matrix.constructor

cdef class LeanMatrix:
    """
    Lean matrices

    Sage's matrix classes are powerful, versatile, and often very fast. However, their performance with regard to pivoting
    (pretty much the only task performed on them within the context of matroids) leaves something to be desired. The LeanMatrix
    classes provide the LinearMatroid classes with a custom, light-weight data structure to store and manipulate matrices.

    This is the abstract base class. Most methods are not implemented; this is only to fix the interface.

    .. NOTE::

        This class is intended for internal use by the LinearMatroid class only. Hence it does not derive from ``SageObject``.
        If ``A`` is a LeanMatrix instance, and you need access from other parts of Sage, use ``Matrix(A)`` instead.

    EXAMPLES::

        sage: M = Matroid(ring=GF(5), matrix=[[1, 0, 1, 1, 1], [0, 1, 1, 2, 3]])  # indirect doctest
        sage: M.is_isomorphic(matroids.Uniform(2, 5))
        True
    """
    def __init__(self, long m, long n, M=None):
        """
        Initialize a lean matrix; see class documentation for more info.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import LeanMatrix
            sage: A = LeanMatrix(3, 4)
            sage: A.ncols()
            4
        """
        self._nrows = m
        self._ncols = n

    def __repr__(self):
        """
        Return a string representation.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import LeanMatrix
            sage: A = LeanMatrix(3, 4)
            sage: repr(A)
            'LeanMatrix instance with 3 rows and 4 columns'
        """
        return "LeanMatrix instance with " + str(self._nrows) + " rows and " + str(self._ncols) + " columns"

    def _matrix_(self):
        """
        Return a matrix version.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import GenericMatrix
            sage: A = Matrix(GF(5), [[1, 0, 1, 1, 1], [0, 1, 1, 2, 3]])
            sage: A == GenericMatrix(2, 5, A)._matrix_()
            True
        """
        cdef long r, c
        M = sage.matrix.constructor.Matrix(self.base_ring(), self._nrows, self._ncols)
        for r from 0 <= r < self._nrows:
            for c from 0 <= c < self._ncols:
                M[r, c] = self.get_unsafe(r, c)
        return M

    cdef LeanMatrix copy(self):   # Deprecated Sage matrix operation
        """
        Make a copy of ``self``.
        """
        cdef LeanMatrix A = type(self)(self.nrows(), self.ncols(), self)
        return A

    cdef void resize(self, long k):    # Not a Sage matrix operation
        """
        Change number of rows of ``self`` to ``k``. Preserves data.
        """
        raise NotImplementedError

    cdef LeanMatrix stack(self, LeanMatrix M):
        """
        Stack ``self`` on top of ``M``. Assumes ``self`` and ``M`` are of same
        type, and compatible dimensions.
        """
        cdef LeanMatrix A
        cdef long i, j
        cdef long sr = self.nrows()
        A = type(self)(sr + M.nrows(), self.ncols())
        for i from 0 <= i < sr:
            for j from 0 <= j < self.ncols():
                A.set_unsafe(i, j, self.get_unsafe(i, j))
        for i from 0 <= i < M.nrows():
            for j from 0 <= j < M.ncols():
                A.set_unsafe(i + sr, j, M.get_unsafe(i, j))
        return A

    cdef LeanMatrix augment(self, LeanMatrix M):
        """
        Concatenates ``self`` with ``M``, placing ``M`` to the right of
        ``self``. Assumes ``self`` and ``M`` are of same type, and compatible
        dimensions.
        """
        cdef LeanMatrix A
        cdef long i, j
        cdef long sc = self.ncols()
        A = type(self)(self.nrows(), sc + M.ncols())
        for i from 0 <= i < self.nrows():
            for j from 0 <= j < sc:
                A.set_unsafe(i, j, self.get_unsafe(i, j))
            for j from 0 <= j < M.ncols():
                A.set_unsafe(i, j + sc, M.get_unsafe(i, j))
        return A

    cdef LeanMatrix prepend_identity(self):   # Not a Sage matrix operation
        """
        Return the matrix obtained by prepending an identity matrix. Special
        case of ``augment``.
        """
        cdef long i, j
        cdef LeanMatrix A = type(self)(self.nrows(), self.ncols() + self.nrows())
        for i from 0 <= i < self.nrows():
            A.set_unsafe(i, i, self.base_ring()(1))
            for j from 0 <= j < self.ncols():
                A.set_unsafe(i, self.nrows() + j, self.get_unsafe(i, j))
        return A

    cpdef long ncols(self):
        """
        Return the number of columns.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import LeanMatrix
            sage: A = LeanMatrix(3, 4)
            sage: A.ncols()
            4
        """
        return self._ncols

    cpdef long nrows(self):
        """
        Return the number of rows.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import LeanMatrix
            sage: A = LeanMatrix(3, 4)
            sage: A.nrows()
            3
        """
        return self._nrows

    cpdef base_ring(self):
        """
        Return the base ring.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import LeanMatrix
            sage: A = LeanMatrix(3, 4)
            sage: A.base_ring()
            Traceback (most recent call last):
            ...
            NotImplementedError: subclasses need to implement this.
        """
        raise NotImplementedError("subclasses need to implement this.")

    cpdef characteristic(self):
        """
        Return the characteristic of ``self.base_ring()``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import GenericMatrix
            sage: A = GenericMatrix(3, 4, ring=GF(5))
            sage: A.characteristic()
            5
        """
        return self.base_ring().characteristic()

    cdef get_unsafe(self, long r, long c):
        """
        Return the value in row ``r``, column ``c``.
        """
        raise NotImplementedError

    cdef void set_unsafe(self, long r, long c, x):
        """
        Set the value in row ``r``, column ``c`` to ``x``.
        """
        raise NotImplementedError

    cdef bint is_nonzero(self, long r, long c):   # Not a Sage matrix operation
        """
        Check if value in row ``r``, column ``c`` equals ``0``.
        """
        return self.get_unsafe(r, c) != 0

    cdef void add_multiple_of_row_c(self, long x, long y, s, bint col_start):
        """
        Add ``s`` times row ``y`` to row ``x``. Argument ``col_start`` is
        ignored.
        """
        cdef long i
        if s is None:
            for i from 0 <= i < self._ncols:
                self.set_unsafe(x, i, self.get_unsafe(x, i) + self.get_unsafe(y, i))
        else:
            for i from 0 <= i < self._ncols:
                self.set_unsafe(x, i, self.get_unsafe(x, i) + s * self.get_unsafe(y, i))

    cdef void swap_rows_c(self, long x, long y):
        """
        Swap rows ``x`` and ``y``.
        """
        cdef long i
        for i from 0 <= i < self._ncols:
            tmp = self.get_unsafe(x, i)
            self.set_unsafe(x, i, self.get_unsafe(y, i))
            self.set_unsafe(y, i, tmp)

    cdef void rescale_row_c(self, long x, s, bint col_start):
        """
        Scale row ``x`` by ``s``. Argument ``col_start`` is for Sage
        compatibility, and is ignored.
        """
        cdef long i
        for i from 0 <= i < self._ncols:
            self.set_unsafe(x, i, s * self.get_unsafe(x, i))

    cdef void rescale_column_c(self, long y, s, bint start_row):
        """
        Scale column ``y`` by ``s``. Argument ``start_row`` is for Sage
        compatibility, and ignored.
        """
        cdef long j
        for j from 0 <= j < self._nrows:
            self.set_unsafe(j, y, self.get_unsafe(j, y) * s)

    cdef void pivot(self, long x, long y):   # Not a Sage matrix operation
        """
        Row-reduce to make column ``y`` have a ``1`` in row ``x`` and zeroes
        elsewhere.

        Assumption (not checked): the entry in row ``x``, column ``y`` is
        nonzero to start with.

        .. NOTE::

            This is different from what matroid theorists tend to call a
            pivot, as it does not involve a column exchange!
        """
        cdef long i, j
        self.rescale_row_c(x, self.get_unsafe(x, y) ** (-1), 0)
        for i from 0 <= i < self._nrows:
            s = self.get_unsafe(i, y)
            if s and i != x:
                self.add_multiple_of_row_c(i, x, -s, 0)

    cdef list gauss_jordan_reduce(self, columns):   # Not a Sage matrix operation
        """
        Row-reduce so the lexicographically first basis indexes an identity
        submatrix.
        """
        cdef long r = 0
        cdef list P = []
        cdef long c, p, row
        cdef bint is_pivot
        for c in columns:
            is_pivot = False
            for row from r <= row < self._nrows:
                if self.is_nonzero(row, c):
                    is_pivot = True
                    p = row
                    break
            if is_pivot:
                self.swap_rows_c(p, r)
                self.rescale_row_c(r, self.get_unsafe(r, c) ** (-1), 0)
                for row from 0 <= row < self._nrows:
                    if row != r and self.is_nonzero(row, c):
                        self.add_multiple_of_row_c(row, r, -self.get_unsafe(row, c), 0)
                P.append(c)
                r += 1
            if r == self._nrows:
                break
        return P

    cdef list nonzero_positions_in_row(self, long r):
        """
        Get coordinates of nonzero entries of row ``r``.
        """
        return [i for i in xrange(self._ncols) if self.is_nonzero(r, i)]

    cdef LeanMatrix transpose(self):
        """
        Return the transpose of the matrix.
        """
        cdef LeanMatrix A = type(self)(self.ncols(), self.nrows())
        cdef long i, j
        for i from 0 <= i < self.nrows():
            for j from 0 <= j < self.ncols():
                A.set_unsafe(j, i, self.get_unsafe(i, j))
        return A

    cdef LeanMatrix _matrix_times_matrix_(self, LeanMatrix other):
        """
        Multiply two matrices. Assumes ``self`` and ``M`` are of same type,
        and compatible dimensions.
        """
        cdef LeanMatrix A = type(self)(self.nrows(), other.ncols())
        cdef i, j, k
        for i from 0 <= i < self.nrows():
            for j from 0 <= j < other.ncols():
                for k from 0 <= k < self.ncols():
                    A.set_unsafe(i, j, self.get_unsafe(i, k) * other.get_unsafe(k, j))
        return A

    cdef LeanMatrix matrix_from_rows_and_columns(self, rows, columns):
        """
        Return submatrix indexed by indicated rows and columns.
        """
        cdef long r, c
        cdef LeanMatrix A = type(self)(len(rows), len(columns), ring=self.base_ring())
        for r from 0 <= r < len(rows):
            for c from 0 <= c < len(columns):
                A.set_unsafe(r, c, self.get_unsafe(rows[r], columns[c]))
        return A

    def __mul__(left, right):
        """
        Multiply two matrices, or multiply a matrix with a constant from the
        base ring.

        Only works if both matrices are of the same type, or if the constant
        is the first operand and can be coerced into the base ring.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 2, Matrix(GF(2), [[1, 0], [1, 1]]))
            sage: B = GenericMatrix(3, 2, Matrix(GF(2), [[1, 0], [1, 0], [1, 0]]))
            sage: B * A
            LeanMatrix instance with 3 rows and 2 columns over Finite Field of size 2
        """
        cdef long i
        cdef LeanMatrix A
        if isinstance(left, LeanMatrix):
            if type(left) == type(right):
                return (<LeanMatrix>left)._matrix_times_matrix_(right)
            else:
                return NotImplemented
        if not left in (<LeanMatrix>right).base_ring():
            try:
                left = (<LeanMatrix>right).base_ring()(left)
            except (TypeError, NotImplemented, ValueError):
                return NotImplemented
        A = (<LeanMatrix>right).copy()
        for i from 0 <= i < A.nrows():
            A.rescale_row_c(i, left, 0)
        return A

    def __neg__(self):
        """
        Return a matrix ``B`` such that ``self + B`` is the all-zero matrix.

        Note that the `` + `` operator is currently not supported.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 2, Matrix(GF(3), [[1, 0], [0, 1]]))
            sage: C = -A
            sage: -C == A
            True
        """
        cdef long i
        cdef LeanMatrix A = self.copy()
        x = self.base_ring()(-1)
        for i from 0 <= i < A.nrows():
            A.rescale_row_c(i, x, 0)
        return A

    def __richcmp__(left, right, op):
        """
        Compare two matrices.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: B = GenericMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: C = GenericMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: D = BinaryMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: E = GenericMatrix(2, 3, Matrix(GF(2), [[1, 0, 0], [0, 1, 0]]))
            sage: A == B  # indirect doctest
            True
            sage: A != C  # indirect doctest
            True
            sage: A == D  # indirect doctest
            False
            sage: E == A
            False
        """
        cdef long i, j
        if op in [0, 1, 4, 5]:  # <, <=, >, >=
            return NotImplemented
        if not isinstance(left, LeanMatrix) or not isinstance(right, LeanMatrix):
            return NotImplemented
        if type(left) != type(right):
            return NotImplemented
        if op == 2:  # ==
            res = True
        if op == 3:  # !=
            res = False
        # res gets inverted if matroids are deemed different.
        if left.nrows() != right.nrows():
            return not res
        if left.ncols() != right.ncols():
            return not res
        for i from 0 <= i < left.nrows():
            for j from 0 <= j < left.ncols():
                if (<LeanMatrix>left).get_unsafe(i, j) != (<LeanMatrix>right).get_unsafe(i, j):
                    return not res
        return res

    #    In Cythonized classes, use ``__richcmp__()`` instead of ``__eq__()``, ``__ne__()``.

    #    Copying, loading, saving:

    def __copy__(self):
        """
        Return a copy of ``self``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 5, Matrix(GF(5), [[1, 0, 1, 1, 1], [0, 1, 1, 2, 3]]))
            sage: A == copy(A)  # indirect doctest
            True
        """
        return self.copy()

    def __deepcopy__(self, memo={}):
        """
        Return a deep copy of ``self``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 5, Matrix(GF(5), [[1, 0, 1, 1, 1], [0, 1, 1, 2, 3]]))
            sage: A == deepcopy(A)  # indirect doctest
            True
        """
        return self.copy()

    def __reduce__(self):
        """
        Save the object.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = LeanMatrix(2, 5)
            sage: A == loads(dumps(A))  # indirect doctest
            Traceback (most recent call last):
            ...
            NotImplementedError: subclasses need to implement this.
        """
        raise NotImplementedError("subclasses need to implement this.")

cdef class GenericMatrix(LeanMatrix):
    """
    Matrix over arbitrary Sage ring.

    INPUT:

    - ``nrows`` -- number of rows
    - ``ncols`` -- number of columns
    - ``M`` -- (default: ``None``) a ``Matrix`` or ``GenericMatrix`` of
      dimensions at most ``m*n``.
    - ``ring`` -- (default: ``None``) a Sage ring.

    .. NOTE::

        This class is intended for internal use by the LinearMatroid class
        only. Hence it does not derive from ``SageObject``. If ``A`` is a
        LeanMatrix instance, and you need access from other parts of Sage,
        use ``Matrix(A)`` instead.

        If the constructor is fed a GenericMatrix instance, the ``ring``
        argument is ignored. Otherwise, the matrix entries
        will be converted to the appropriate ring.

    EXAMPLES::

        sage: M = Matroid(ring=GF(5), matrix=[[1, 0, 1, 1, 1], [0, 1, 1, 2, 3]])  # indirect doctest
        sage: M.is_isomorphic(matroids.Uniform(2, 5))
        True
    """

    def __init__(self, long nrows, long ncols, M=None, ring=None):
        """
        See class docstring for full information.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 2, Matrix(GF(3), [[0, 0], [0, 0]]))  # indirect doctest
            sage: B = GenericMatrix(2, 2, ring=GF(3))
            sage: A == B
            True
        """
        cdef long i, j
        cdef bint ring_override = False
        self._nrows = nrows
        self._ncols = ncols
        if M is not None:
            self._base_ring = M.base_ring()
        if ring is not None:
            # Overrides M's ring
            self._base_ring = ring
            ring_override = True
        # Default:
        if self._base_ring is None:
            self._base_ring = ZZ
        self._zero = self._base_ring(0)
        self._one = self._base_ring(1)
        self._entries = [self._zero] * nrows * ncols
        if M is not None:
            if isinstance(M, GenericMatrix):
                if nrows == (<GenericMatrix>M)._nrows and ncols == (<GenericMatrix>M)._ncols:
                    self._entries = (<GenericMatrix>M)._entries[:]  # Slicing notation makes copy
                else:
                    for i from 0 <= i < (<GenericMatrix>M)._nrows:
                        self._entries[i * self._ncols:i * self._ncols + (<GenericMatrix>M)._ncols] = (<GenericMatrix>M)._entries[i * (<GenericMatrix>M)._ncols:(i + 1) * (<GenericMatrix>M)._ncols]
            elif isinstance(M, LeanMatrix):
                if ring_override:
                    for i from 0 <= i < M.nrows():
                        for j from 0 <= j < M.ncols():
                            self._entries[i * self._ncols + j] = self._base_ring((<LeanMatrix>M).get_unsafe(i, j))
                else:
                    for i from 0 <= i < M.nrows():
                        for j from 0 <= j < M.ncols():
                            self._entries[i * self._ncols + j] = (<LeanMatrix>M).get_unsafe(i, j)
            else:  # Sage Matrix or otherwise
                if ring_override:
                    for i from 0 <= i < M.nrows():
                        for j from 0 <= j < M.ncols():
                            self._entries[i * self._ncols + j] = self._base_ring(M[i, j])
                else:
                    for i from 0 <= i < M.nrows():
                        for j from 0 <= j < M.ncols():
                            self._entries[i * self._ncols + j] = M[i, j]

    def __repr__(self):
        """
        Print representation.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 2, Matrix(GF(3), [[0, 0], [0, 0]]))
            sage: repr(A)  # indirect doctest
            'LeanMatrix instance with 2 rows and 2 columns over Finite Field of size 3'
        """
        return "LeanMatrix instance with " + str(self._nrows) + " rows and " + str(self._ncols) + " columns over " + repr(self._base_ring)

    cdef LeanMatrix copy(self):   # Deprecated Sage matrix operation
        cdef GenericMatrix M = GenericMatrix(self._nrows, self._ncols, M=self)
        return M

    cdef void resize(self, long k):   # Not a Sage matrix operation
        """
        Change number of rows to ``k``. Preserves data.
        """
        cdef long l = len(self._entries) - k * self._ncols
        if l > 0:
            self._entries.extend([self._zero] * l)
        elif l < 0:
            del self._entries[k * self._ncols:]
        self._nrows = k

    cdef LeanMatrix stack(self, LeanMatrix M):
        """
        Warning: assumes ``M`` is a GenericMatrix instance!
        """
        cdef GenericMatrix A
        cdef long i, j
        A = GenericMatrix(0, 0, ring=self._base_ring)
        A._entries = self._entries + ((<GenericMatrix>M)._entries)
        A._nrows = self._nrows + M.nrows()
        A._ncols = self._ncols
        return A

    cdef LeanMatrix augment(self, LeanMatrix M):
        """
        Warning: assumes ``M`` is a GenericMatrix instance!
        """
        cdef GenericMatrix A
        cdef long i
        cdef long Mn = M.ncols()
        A = GenericMatrix(self._nrows, self._ncols + Mn, ring=self._base_ring)
        for i from 0 <= i < self._nrows:
            A._entries[i * A._ncols:i * A._ncols + self._ncols] = self._entries[i * self._ncols:(i + 1) * self._ncols]
            A._entries[i * A._ncols + self._ncols:(i + 1) * A._ncols]=(<GenericMatrix>M)._entries[i * Mn:(i + 1) * Mn]
        return A

    cdef LeanMatrix prepend_identity(self):   # Not a Sage matrix operation
        cdef GenericMatrix A = GenericMatrix(self._nrows, self._ncols + self._nrows, ring=self._base_ring)
        for i from 0 <= i < self._nrows:
            A._entries[i * A._ncols + i] = self._one
            A._entries[i * A._ncols + self._nrows:(i + 1) * A._ncols]=self._entries[i * self._ncols:(i + 1) * self._ncols]
        return A

    cpdef base_ring(self):
        """
        Return the base ring of ``self``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import GenericMatrix
            sage: A = GenericMatrix(3, 4, ring=GF(5))
            sage: A.base_ring()
            Finite Field of size 5
        """
        return self._base_ring

    cpdef characteristic(self):
        """
        Return the characteristic of ``self.base_ring()``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import GenericMatrix
            sage: A = GenericMatrix(3, 4, ring=GF(5))
            sage: A.characteristic()
            5
        """
        if self._characteristic is None:
            self._characteristic = self._base_ring.characteristic()
        return self._characteristic

    cdef get_unsafe(self, long r, long c):
        return self._entries[r * self._ncols + c]

    cdef void set_unsafe(self, long r, long c, x):
        self._entries[r * self._ncols + c] = x

    cdef void swap_rows_c(self, long x, long y):
        """
        Swap rows ``x`` and ``y``.
        """
        cdef list tmp = self._entries[x * self._ncols:(x + 1) * self._ncols]
        self._entries[x * self._ncols:(x + 1) * self._ncols] = self._entries[y * self._ncols:(y + 1) * self._ncols]
        self._entries[y * self._ncols:(y + 1) * self._ncols] = tmp

    cdef LeanMatrix transpose(self):
        """
        Return the transpose of the matrix.
        """
        cdef GenericMatrix A
        cdef long i, j
        A = GenericMatrix(self._ncols, self._nrows, ring=self._base_ring)
        for i from 0 <= i < self._nrows:
            for j from 0 <= j < self._ncols:
                A.set_unsafe(j, i, self.get_unsafe(i, j))
        return A

    cdef inline row_inner_product(self, long i, long j):   # Not a Sage matrix operation
        """
        Return the inner product between rows ``i`` and ``j``.
        """
        cdef long k
        res = 0
        for k from 0 <= k < self._ncols:
            x = self.get_unsafe(i, k)
            y = self.get_unsafe(j, k)
            if y and y != self._one:
                y += self._one
            res += x * y
        return res

    cdef LeanMatrix _matrix_times_matrix_(self, LeanMatrix other):
        """
        Return the product ``self * other``.
        """
        cdef GenericMatrix A, ot
        cdef long i, j, t
        ot = <GenericMatrix > other
        A = GenericMatrix(self._nrows, ot._ncols, ring=self._base_ring)
        for i from 0 <= i < A._nrows:
            for j from 0 <= j < A._ncols:
                s = self._zero
                for t from 0 <= t < self._ncols:
                    s += self.get_unsafe(i, t) * ot.get_unsafe(t, j)
                A.set_unsafe(i, j, s)
        return A

    def __richcmp__(left, right, op):
        """
        Compare two matrices.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: B = GenericMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: C = GenericMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: D = BinaryMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: E = GenericMatrix(2, 3, Matrix(GF(2), [[1, 0, 0], [0, 1, 0]]))
            sage: A == B  # indirect doctest
            True
            sage: A != C  # indirect doctest
            True
            sage: A == D  # indirect doctest
            False
            sage: E == A
            False
        """
        cdef long i, j
        if op in [0, 1, 4, 5]:  # <, <=, >, >=
            return NotImplemented
        if not isinstance(left, GenericMatrix) or not isinstance(right, GenericMatrix):
            return NotImplemented
        if op == 2:  # ==
            res = True
        if op == 3:  # !=
            res = False
        # res gets inverted if matroids are deemed different.
        if left.nrows() != right.nrows():
            return not res
        if left.ncols() != right.ncols():
            return not res
        if left.base_ring() != right.base_ring():
            return not res
        if (<GenericMatrix>left)._entries != (<GenericMatrix>right)._entries:
            return not res
        return res

    def __reduce__(self):
        """
        Save the object.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(2, 5, ring=QQ)
            sage: A == loads(dumps(A))  # indirect doctest
            True
            sage: C = GenericMatrix(2, 2, Matrix(GF(3), [[1, 1], [0, 1]]))
            sage: C == loads(dumps(C))
            True
        """
        import sage.matroids.unpickling
        version = 0
        data = (self.nrows(), self.ncols(), self.base_ring(), self._entries)
        return sage.matroids.unpickling.unpickle_generic_matrix, (version, data)

# Binary matrices

cdef bint GF2_not_defined = True
cdef GF2, GF2_one, GF2_zero

cdef class BinaryMatrix(LeanMatrix):
    """
    Binary matrix class. Entries are stored bit-packed into integers.

    INPUT:

    - ``m`` -- Number of rows.
    - ``n`` -- Number of columns.
    - ``M`` -- (default: ``None``) Matrix or BinaryMatrix instance.
      Assumption: dimensions of ``M`` are at most ``m`` by ``n``.
    - ``ring`` -- (default: ``None``) ignored.

    EXAMPLES::

        sage: from sage.matroids.lean_matrix import *
        sage: A = BinaryMatrix(2, 2, Matrix(GF(7), [[0, 0], [0, 0]]))
        sage: B = BinaryMatrix(2, 2, ring=GF(5))
        sage: C = BinaryMatrix(2, 2)
        sage: A == B and A == C
        True
    """
    def __cinit__(self, long m, long n, object M=None, object ring=None):
        """
        Init internal data structures.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = BinaryMatrix(2, 2, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
        """
        cdef long i, j
        self._nrows = m
        self._ncols = n
        self._M = <bitset_t* > sage_malloc(self._nrows * sizeof(bitset_t))
        if isinstance(M, BinaryMatrix):
            j = max(1, (<BinaryMatrix>M)._ncols)
        else:
            j = max(1, self._ncols)
        for i from 0 <= i < self._nrows:
            bitset_init(self._M[i], j)
            bitset_clear(self._M[i])
        bitset_init(self._temp, j)

    def __init__(self, long m, long n, object M=None, object ring=None):
        """
        See class docstring for full specification.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = BinaryMatrix(2, 2, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
        """
        cdef long i, j
        global GF2, GF2_zero, GF2_one, GF2_not_defined
        if GF2_not_defined:
            GF2 = GF(2)
            GF2_zero = GF2(0)
            GF2_one = GF2(1)
            GF2_not_defined = False
        if M is not None:
            if isinstance(M, BinaryMatrix):
                for i from 0 <= i < M.nrows():
                    bitset_copy(self._M[i], (<BinaryMatrix>M)._M[i])
                j = max(1, self._ncols)
                for i from 0 <= i < self._nrows:
                    bitset_realloc(self._M[i], j)
            elif isinstance(M, LeanMatrix):
                for i from 0 <= i < M.nrows():
                    for j from 0 <= j < M.ncols():
                        if int((<LeanMatrix>M).get_unsafe(i, j)) % 2:
                            self.set(i, j)
            elif isinstance(M, Matrix):
                for i from 0 <= i < M.nrows():
                    for j from 0 <= j < M.ncols():
                        if int((<Matrix>M).get_unsafe(i, j)) % 2:
                            self.set(i, j)
            else:
                raise TypeError("unrecognized input type")

    def __dealloc__(self):
        cdef long i
        for i from 0 <= i < self._nrows:
            bitset_free(self._M[i])
        sage_free(self._M)
        bitset_free(self._temp)

    def __repr__(self):
        """
        Print representation string

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = BinaryMatrix(2, 3, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))
            sage: repr(A)  # indirect doctest
            '2 x 3 BinaryMatrix\n[000]\n[000]'
        """
        out = str(self._nrows) + ' x ' + str(self._ncols) + ' BinaryMatrix'
        cdef long i
        if self._ncols > 0:
            for i from 0 <= i < self._nrows:
                out += '\n[' + bitset_string(self._M[i]) + ']'
        else:
            for i from 0 <= i < self._nrows:
                out += '[]'
        return out

    def _matrix_(self):
        """
        Return a matrix version.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = Matrix(GF(2), [[1, 0], [0, 1]])
            sage: A == BinaryMatrix(2, 2, A)._matrix_()
            True
        """
        cdef long i, j
        M = sage.matrix.constructor.Matrix(GF(2), self._nrows, self._ncols)
        for i from 0 <= i < self._nrows:
            for j from 0 <= j < self._ncols:
                if bitset_in(self._M[i], j):
                    M[i, j] = 1
        return M

    cdef LeanMatrix copy(self):   # Deprecated Sage matrix operation
        cdef BinaryMatrix B
        cdef long i
        B = BinaryMatrix(self.nrows(), self.ncols())
        for i from 0 <= i < self._nrows:
            bitset_copy(B._M[i], self._M[i])
        return B

    cdef void resize(self, long k):   # Not a Sage matrix operation
        """
        Change number of rows to ``k``. Preserves data.
        """
        cdef long i, c
        if k < self._nrows:
            for i from k <= i < self._nrows:
                bitset_free(self._M[i])
            self._nrows = k
            self._M = <bitset_t* > sage_realloc(self._M, k * sizeof(bitset_t))
        if k > self._nrows:
            self._M = <bitset_t* > sage_realloc(self._M, k * sizeof(bitset_t))
            c = max(1, self._ncols)
            for i from self._nrows <= i < k:
                bitset_init(self._M[i], c)
                bitset_clear(self._M[i])
            self._nrows = k

    cdef LeanMatrix stack(self, LeanMatrix MM):
        """
        Given ``A`` and ``B``, return
        [A]
        [B]
        """
        cdef BinaryMatrix R
        cdef BinaryMatrix M = <BinaryMatrix > MM
        cdef long i
        R = BinaryMatrix(self.nrows() + M.nrows(), self.ncols(), self)
        for i from 0 <= i < M.nrows():
            bitset_copy(R._M[i + self.nrows()], M._M[i])
        return R

    cdef LeanMatrix augment(self, LeanMatrix MM):
        """
        Given ``A`` and ``B``, return
        [A B]
        """
        cdef BinaryMatrix R
        cdef BinaryMatrix M = <BinaryMatrix > MM
        cdef long i, j
        R = BinaryMatrix(self.nrows(), self.ncols() + M.ncols(), self)
        for i from 0 <= i < R.nrows():
            for j from 0 <= j < M.ncols():
                bitset_set_to(R._M[i], self.ncols() + j, bitset_in(M._M[i], j))
        return R

    cdef LeanMatrix prepend_identity(self):   # Not a Sage matrix operation
        """
        Return the matrix obtained by prepending an identity matrix. Special case of ``augment``.
        """
        cdef long i, j
        cdef BinaryMatrix A = BinaryMatrix(self._nrows, self._ncols + self._nrows)
        for i from 0 <= i < self._nrows:
            A.set(i, i)
            for j from 0 <= j < self._ncols:
                if self.get(i, j):
                    A.set(i, self._nrows + j)
        return A

    cpdef base_ring(self):
        """
        Return `GF(2)`.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = BinaryMatrix(4, 4)
            sage: A.base_ring()
            Finite Field of size 2
        """
        global GF2
        return GF2

    cpdef characteristic(self):
        """
        Return the characteristic of ``self.base_ring()``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = BinaryMatrix(3, 4)
            sage: A.characteristic()
            2
        """
        return 2

    cdef get_unsafe(self, long r, long c):
        global GF2_one, GF2_zero
        if bitset_in(self._M[r], c):
            return GF2_one
        return GF2_zero

    cdef void set_unsafe(self, long r, long c, x):
        if x:
            bitset_add(self._M[r], c)
        else:
            bitset_discard(self._M[r], c)

    cdef bint is_nonzero(self, long r, long c):   # Not a Sage matrix operation
        return bitset_in(self._M[r], c)

    cdef inline bint get(self, long r, long c):   # Not a Sage matrix operation
        return bitset_in(self._M[r], c)

    cdef inline void set(self, long x, long y):   # Not a Sage matrix operation
        bitset_add(self._M[x], y)

    cdef void pivot(self, long x, long y):   # Not a Sage matrix operation
        """
        Row-reduce to make column ``y`` have a ``1`` in row ``x`` and
        zeroes elsewhere.

        Assumption (not checked): the entry in row ``x``, column ``y``
        is nonzero to start with.

        .. NOTE::

            This is different from what matroid theorists tend to call a
            pivot, as it does not involve a column exchange!
        """
        cdef long i, j
        for i from 0 <= i < self._nrows:
            if bitset_in(self._M[i], y) and i != x:
                bitset_symmetric_difference(self._M[i], self._M[i], self._M[x])

    cdef inline long row_len(self, long i):   # Not a Sage matrix operation
        """
        Return number of nonzero entries in row ``i``.
        """
        return bitset_len(self._M[i])

    cdef inline bint row_inner_product(self, long i, long j):   # Not a Sage matrix operation
        """
        Return the inner product between rows ``i`` and ``j``.
        """
        bitset_copy(self._temp, self._M[i])
        bitset_intersection(self._temp, self._temp, self._M[j])
        return bitset_len(self._temp) % 2

    cdef void add_multiple_of_row_c(self, long i, long j, s, bint col_start):
        """
        Add row ``j`` to row ``i``. Other arguments are ignored.
        """
        bitset_symmetric_difference(self._M[i], self._M[i], self._M[j])

    cdef void swap_rows_c(self, long i, long j):
        bitset_copy(self._temp, self._M[i])
        bitset_copy(self._M[i], self._M[j])
        bitset_copy(self._M[j], self._temp)

    cdef inline list nonzero_positions_in_row(self, long i):
        """
        Get coordinates of nonzero entries of row ``r``.
        """
        return bitset_list(self._M[i])

    cdef inline list row_sum(self, object L):   # Not a Sage matrix operation
        """
        Return the mod-2 sum of the rows indexed by ``L``.
        """
        bitset_clear(self._temp)
        for l in L:
            bitset_symmetric_difference(self._temp, self._temp, self._M[l])
        return bitset_list(self._temp)

    cdef inline list row_union(self, object L):   # Not a Sage matrix operation
        """
        Return the ``or`` of the rows indexed by ``L``.
        """
        bitset_clear(self._temp)
        for l in L:
            bitset_union(self._temp, self._temp, self._M[l])
        return bitset_list(self._temp)

    cdef LeanMatrix transpose(self):
        """
        Return the transpose of the matrix.
        """
        cdef BinaryMatrix T
        cdef long i, j
        T = BinaryMatrix(self._ncols, self._nrows)
        for i from 0 <= i < self._nrows:
            j = bitset_first(self._M[i])
            while j >= 0:
                T.set(j, i)
                j = bitset_next(self._M[i], j + 1)
        return T

    cdef LeanMatrix _matrix_times_matrix_(self, LeanMatrix other):
        """
        Return the product ``self * other``.
        """
        cdef BinaryMatrix M
        cdef BinaryMatrix ot = <BinaryMatrix > other
        M = BinaryMatrix(self._nrows, ot._ncols)
        cdef long i, j
        for i from 0 <= i < self._nrows:
            j = bitset_first(self._M[i])
            while j >= 0:
                bitset_symmetric_difference(M._M[i], M._M[i], ot._M[j])
                j = bitset_next(self._M[i], j + 1)
        return M

    cdef LeanMatrix matrix_from_rows_and_columns(self, rows, columns):
        """
        Return submatrix indexed by indicated rows and columns.
        """
        cdef long r, c
        cdef BinaryMatrix A = BinaryMatrix(len(rows), len(columns))
        for r from 0 <= r < len(rows):
            for c from 0 <= c < len(columns):
                if bitset_in(self._M[rows[r]], columns[c]):
                    bitset_add(A._M[r], c)
        return A

    cdef list _character(self, bitset_t x):   # Not a Sage matrix operation
        """
        Return the vector of intersection lengths of the rows with ``x``.
        """
        cdef long i
        I = []
        for i from 0 <= i < self._nrows:
            bitset_intersection(self._temp, self._M[i], x)
            I.append(bitset_len(self._temp))
        return I

    cdef BinaryMatrix _distinguish_by(self, BinaryMatrix P):
        """
        Helper method for equitable partition.
        """
        cdef BinaryMatrix Q
        d = {}
        for i from 0 <= i < self._nrows:
            c = hash(tuple(P._character(self._M[i])))
            if c in d:
                d[c].append(i)
            else:
                d[c] = [i]
        Q = BinaryMatrix(len(d), self._nrows)
        i = 0
        for c in sorted(d):
            for j in d[c]:
                bitset_add(Q._M[i], j)
            i += 1
        return Q

    cdef BinaryMatrix _splice_by(self, BinaryMatrix P):
        """
        Helper method for equitable partition.
        """
        cdef BinaryMatrix Q
        cdef long i, j, r
        Q = BinaryMatrix(self._ncols, self._ncols)
        r = 0
        for i from 0 <= i < self._nrows:
            for j from 0 <= j < P._nrows:
                bitset_intersection(self._temp, self._M[i], P._M[j])
                if not bitset_isempty(self._temp):
                    bitset_copy(Q._M[r], self._temp)
                    r += 1
        Q.resize(r)
        return Q

    cdef BinaryMatrix _isolate(self, long j):
        """
        Helper method for isomorphism test.
        """
        cdef BinaryMatrix Q
        cdef long i, r
        Q = BinaryMatrix(self._nrows + 1, self._ncols)
        for i from 0 <= i < self._nrows:
            bitset_copy(Q._M[i], self._M[i])
            bitset_discard(Q._M[i], j)
        bitset_add(Q._M[self._nrows], j)
        return Q

    cdef BinaryMatrix equitable_partition(self, BinaryMatrix P=None):
        """
        Compute an equitable partition of the columns.
        """
        if P is None:
            P = BinaryMatrix(1, self._ncols)
            bitset_set_first_n(P._M[0], self._ncols)
        r = 0
        while P.nrows() > r:
            r = P.nrows()
            P = P._splice_by(self._distinguish_by(P))
        return P

    cdef bint is_isomorphic(self, BinaryMatrix other, BinaryMatrix s_eq=None, BinaryMatrix o_eq=None):   # Not a Sage matrix operation
        """
        Test for isomorphism between the row spaces.
        """
        cdef long e, f, i, j
        if s_eq is None:
            s_eq = self.equitable_partition()
        if o_eq is None:
            o_eq = other.equitable_partition()

        if s_eq.nrows() != o_eq.nrows():
            return False
        if s_eq.nrows() == s_eq.ncols():  # s_eq and o_eq partition into singletons
            morph = [0 for i from 0 <= i < self._nrows]
            for i from 0 <= i < self._nrows:
                morph[bitset_first(s_eq._M[i])] = bitset_first(o_eq._M[i])
            for i from 0 <= i < self._nrows:
                for j from 0 <= j < self._ncols:
                    if self.get(i, j) != other.get(morph[i], morph[j]):
                        return False
            return True

        for i from 0 <= i < s_eq.nrows():
            if s_eq.row_len(i) != o_eq.row_len(i):
                return False
        for i from 0 <= i < s_eq.nrows():
            if s_eq.row_len(i) > 1:
                break
        e = bitset_first(s_eq._M[i])
        s_eq2 = self.equitable_partition(s_eq._isolate(e))
        f = bitset_first(o_eq._M[i])
        while f >= 0:
            if self.is_isomorphic(other, s_eq2, other.equitable_partition(o_eq._isolate(f))):
                return True
            f = bitset_next(o_eq._M[i], f + 1)
        return False

    def __neg__(self):
        """
        Negate the matrix.

        In characteristic 2, this does nothing.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = BinaryMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: B = -A  # indirect doctest
            sage: B == A
            True
        """
        return self.copy()

    def __richcmp__(left, right, op):
        """
        Compare two matrices.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = BinaryMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: B = BinaryMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: C = BinaryMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: D = GenericMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: E = BinaryMatrix(2, 3, Matrix(GF(2), [[1, 0, 0], [0, 1, 0]]))
            sage: A == B  # indirect doctest
            True
            sage: A != C  # indirect doctest
            True
            sage: A == D  # indirect doctest
            False
            sage: E == A
            False
        """
        cdef long i, j
        if op in [0, 1, 4, 5]:  # <, <=, >, >=
            return NotImplemented
        if not isinstance(left, BinaryMatrix) or not isinstance(right, BinaryMatrix):
            return NotImplemented
        if op == 2:  # ==
            res = True
        if op == 3:  # !=
            res = False
        # res gets inverted if matroids are deemed different.
        if left.nrows() != right.nrows():
            return not res
        if left.ncols() != right.ncols():
            return not res
        for i from 0 <= i < left.nrows():
            if not bitset_eq((<BinaryMatrix>left)._M[i], (<BinaryMatrix>right)._M[i]):
                return not res
        return res

    def __reduce__(self):
        """
        Save the object.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = BinaryMatrix(2, 5)
            sage: A == loads(dumps(A))  # indirect doctest
            True
            sage: C = BinaryMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: C == loads(dumps(C))
            True
        """
        import sage.matroids.unpickling
        version = 0
        M = []
        versionB = 0
        size = 0
        limbs = 0
        longsize = 0
        for i from 0 <= i < self.nrows():
            versionB, size, limbs, longsize, data = bitset_pickle(self._M[i])
            M.append(data)
        data = (self.nrows(), self.ncols(), versionB, size, limbs, longsize, M)
        return sage.matroids.unpickling.unpickle_binary_matrix, (version, data)

cdef bint GF3_not_defined = True
cdef GF3, GF3_one, GF3_zero, GF3_minus_one


cdef class TernaryMatrix(LeanMatrix):
    """
    Ternary matrix class. Entries are stored bit-packed into integers.

    INPUT:

    - ``m`` -- Number of rows.
    - ``n`` -- Number of columns.
    - ``M`` -- (default: ``None``) ``Matrix`` or ``TernaryMatrix`` instance.
      Assumption: dimensions of ``M`` are at most ``m`` by ``n``.
    - ``ring`` -- (default: ``None``) ignored.

    EXAMPLES::

        sage: from sage.matroids.lean_matrix import *
        sage: A = TernaryMatrix(2, 2, Matrix(GF(7), [[0, 0], [0, 0]]))
        sage: B = TernaryMatrix(2, 2, ring=GF(5))
        sage: C = TernaryMatrix(2, 2)
        sage: A == B and A == C
        True
    """
    def __cinit__(self, long m, long n, M=None, ring=None):
        """
        Init internal data structures.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = TernaryMatrix(2, 2, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
        """
        cdef long i, j
        global GF3, GF3_zero, GF3_one, GF3_minus_one, GF3_not_defined
        if GF3_not_defined:
            GF3 = GF(3)
            GF3_zero = GF3(0)
            GF3_one = GF3(1)
            GF3_minus_one = GF3(2)
            GF3_not_defined = False

        self._nrows = m
        self._ncols = n
        self._M0 = <bitset_t* > sage_malloc(self._nrows * sizeof(bitset_t))
        self._M1 = <bitset_t* > sage_malloc(self._nrows * sizeof(bitset_t))

        if isinstance(M, TernaryMatrix):
            j = max(1, (<TernaryMatrix>M)._ncols)
        else:
            j = max(1, self._ncols)
        for i from 0 <= i < self._nrows:
            bitset_init(self._M0[i], j)
            bitset_clear(self._M0[i])
            bitset_init(self._M1[i], j)
            bitset_clear(self._M1[i])
        bitset_init(self._s, j)
        bitset_init(self._t, j)
        bitset_init(self._u, j)

    def __init__(self, long m, long n, M=None, ring=None):
        """
        See class docstring for full specification.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = TernaryMatrix(2, 2, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
        """
        cdef long i, j
        if M is not None:
            if isinstance(M, TernaryMatrix):
                for i from 0 <= i < (<TernaryMatrix>M)._nrows:
                    bitset_copy(self._M0[i], (<TernaryMatrix>M)._M0[i])
                    bitset_copy(self._M1[i], (<TernaryMatrix>M)._M1[i])
                j = max(1, self._ncols)
                for i from 0 <= i < self._nrows:
                    bitset_realloc(self._M0[i], j)
                    bitset_realloc(self._M1[i], j)
                return
            if isinstance(M, LeanMatrix):
                for i from 0 <= i < M.nrows():
                    for j from 0 <= j < M.ncols():
                        s = int((<LeanMatrix>M).get_unsafe(i, j)) % 3
                        if s:
                            bitset_add(self._M0[i], j)
                        if s == 2:
                            bitset_add(self._M1[i], j)
                return
            if isinstance(M, Matrix):
                for i from 0 <= i < M.nrows():
                    for j from 0 <= j < M.ncols():
                        s = int((<Matrix>M).get_unsafe(i, j)) % 3
                        if s:
                            bitset_add(self._M0[i], j)
                        if s == 2:
                            bitset_add(self._M1[i], j)

    def __dealloc__(self):
        cdef long i
        for i from 0 <= i < self._nrows:
            bitset_free(self._M0[i])
            bitset_free(self._M1[i])
        sage_free(self._M0)
        sage_free(self._M1)
        bitset_free(self._s)
        bitset_free(self._t)
        bitset_free(self._u)

    def __repr__(self):
        """
        Print representation string

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = TernaryMatrix(2, 3, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))
            sage: repr(A)  # indirect doctest
            '2 x 3 TernaryMatrix\n[000]\n[000]'
        """
        out = str(self._nrows) + ' x ' + str(self._ncols) + ' TernaryMatrix'
        cdef long i
        if self._ncols > 0:
            for i from 0 <= i < self._nrows:
                out += '\n['
                for j from 0 <= j < self._ncols:
                    x = self.get(i, j)
                    if x == 0:
                        out += '0'
                    if x == 1:
                        out += '+'
                    if x == -1:
                        out += '-'
                out += ']'
        else:
            for i from 0 <= i < self._nrows:
                out += '[]'
        return out

    def _matrix_(self):
        """
        Return a matrix version.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = Matrix(GF(3), [[1, 0], [0, 1]])
            sage: A == TernaryMatrix(2, 2, A)._matrix_()
            True
        """
        cdef long i, j
        M = sage.matrix.constructor.Matrix(GF(3), self._nrows, self._ncols)
        for i from 0 <= i < self._nrows:
            for j from 0 <= j < self._ncols:
                    M[i, j] = self.get(i, j)
        return M

    cdef get_unsafe(self, long r, long c):
        global GF3_zero, GF3_one, GF3_minus_one
        if not bitset_in(self._M0[r], c):
            return GF3_zero
        if not bitset_in(self._M1[r], c):
            return GF3_one
        return GF3_minus_one

    cdef void set_unsafe(self, long r, long c, x):
        self.set(r, c, x)

    cdef LeanMatrix copy(self):   # Deprecated Sage matrix operation
        cdef TernaryMatrix T
        cdef long i
        T = TernaryMatrix(self._nrows, self._ncols)
        for i from 0 <= i < self._nrows:
            bitset_copy(T._M0[i], self._M0[i])
            bitset_copy(T._M1[i], self._M1[i])
        return T

    cdef void resize(self, long k):   # Not a Sage matrix operation
        """
        Change number of rows to ``k``. Preserves data.
        """
        cdef long i
        if k < self._nrows:
            for i from k <= i < self._nrows:
                bitset_free(self._M0[i])
                bitset_free(self._M1[i])
            self._nrows = k
            self._M0 = <bitset_t* > sage_realloc(self._M0, k * sizeof(bitset_t))
            self._M1 = <bitset_t* > sage_realloc(self._M1, k * sizeof(bitset_t))
        if k > self._nrows:
            self._M0 = <bitset_t* > sage_realloc(self._M0, k * sizeof(bitset_t))
            self._M1 = <bitset_t* > sage_realloc(self._M1, k * sizeof(bitset_t))
            c = max(1, self._ncols)
            for i from self._nrows <= i < k:
                bitset_init(self._M0[i], c)
                bitset_clear(self._M0[i])
                bitset_init(self._M1[i], c)
                bitset_clear(self._M1[i])
            self._nrows = k

    cdef LeanMatrix stack(self, LeanMatrix MM):
        cdef TernaryMatrix R
        cdef TernaryMatrix M = <TernaryMatrix > MM
        cdef long i
        R = TernaryMatrix(self.nrows() + M.nrows(), self.ncols(), self)
        for i from 0 <= i < M.nrows():
            bitset_copy(R._M0[i + self.nrows()], M._M0[i])
            bitset_copy(R._M1[i + self.nrows()], M._M1[i])
        return R

    cdef LeanMatrix augment(self, LeanMatrix MM):
        cdef TernaryMatrix R
        cdef TernaryMatrix M = <TernaryMatrix > MM
        cdef long i, j
        R = TernaryMatrix(self.nrows(), self.ncols() + M.ncols(), self)
        for i from 0 <= i < R.nrows():
            for j from 0 <= j < M.ncols():
                bitset_set_to(R._M0[i], self.ncols() + j, bitset_in(M._M0[i], j))
                bitset_set_to(R._M1[i], self.ncols() + j, bitset_in(M._M1[i], j))
        return R

    cdef LeanMatrix prepend_identity(self):   # Not a Sage matrix operation
        """
        Return the matrix obtained by prepending an identity matrix.

        Special case of ``augment``.
        """
        cdef long i, j
        cdef TernaryMatrix A = TernaryMatrix(self._nrows, self._ncols + self._nrows)
        for i from 0 <= i < self._nrows:
            A.set(i, i, 1)
            for j from 0 <= j < self._ncols:
                A.set(i, self._nrows + j, self.get(i, j))
        return A

    cpdef base_ring(self):
        """
        Return GF(3).

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = TernaryMatrix(3, 3)
            sage: A.base_ring()
            Finite Field of size 3
        """
        global GF3
        return GF3

    cpdef characteristic(self):
        """
        Return the characteristic of ``self.base_ring()``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = TernaryMatrix(3, 4)
            sage: A.characteristic()
            3
        """
        return 3

    cdef inline long get(self, long r, long c):   # Not a Sage matrix operation
        if not bitset_in(self._M0[r], c):
            return 0
        if not bitset_in(self._M1[r], c):
            return 1
        return -1

    cdef inline void set(self, long r, long c, x):   # Not a Sage matrix operation
        if x == 0:
            bitset_discard(self._M0[r], c)
            bitset_discard(self._M1[r], c)
        if x == 1:
            bitset_add(self._M0[r], c)
            bitset_discard(self._M1[r], c)
        if x == -1:
            bitset_add(self._M0[r], c)
            bitset_add(self._M1[r], c)

    cdef bint is_nonzero(self, long r, long c):   # Not a Sage matrix operation
        return bitset_in(self._M0[r], c)

    cdef bint _is_negative(self, long r, long c):
        return bitset_in(self._M1[r], c)

    cdef inline long row_len(self, long i):   # Not a Sage matrix operation
        """
        Return number of nonzero entries in row ``i``.
        """
        return bitset_len(self._M0[i])

    cdef inline long row_inner_product(self, long i, long j):   # Not a Sage matrix operation
        """
        Return the inner product between rows ``i`` and ``j``.
        """
        cdef long u
        if i == j:
            return self.row_len(i) % 3
        bitset_intersection(self._s, self._M0[i], self._M0[j])
        bitset_symmetric_difference(self._t, self._M1[i], self._M1[j])
        bitset_intersection(self._t, self._t, self._s)
        u = (bitset_len(self._s) + bitset_len(self._t)) % 3
        return u

    cdef void add_multiple_of_row_c(self, long x, long y, s, bint col_start):
        """
        Add ``s`` times row ``y`` to row ``x``. Argument ``col_start`` is
        ignored.
        """
        if s is None:
            bitset_symmetric_difference(self._s, self._M0[x], self._M1[y])
            bitset_symmetric_difference(self._t, self._M1[x], self._M0[y])
            bitset_intersection(self._u, self._s, self._t)
            bitset_symmetric_difference(self._s, self._s, self._M1[x])
            bitset_symmetric_difference(self._t, self._t, self._M1[y])
            bitset_union(self._M0[x], self._s, self._t)
            bitset_copy(self._M1[x], self._u)
        elif s == 1:
            bitset_symmetric_difference(self._s, self._M0[x], self._M1[y])
            bitset_symmetric_difference(self._t, self._M1[x], self._M0[y])
            bitset_intersection(self._u, self._s, self._t)
            bitset_symmetric_difference(self._s, self._s, self._M1[x])
            bitset_symmetric_difference(self._t, self._t, self._M1[y])
            bitset_union(self._M0[x], self._s, self._t)
            bitset_copy(self._M1[x], self._u)
        else:  # -1, since we assume no 0-multiple ever gets added.
            self.row_subs(x, y)

    cdef void row_subs(self, long x, long y):   # Not a Sage matrix operation
        """
        Subtract row ``y`` from row ``x``.
        """
        bitset_symmetric_difference(self._s, self._M1[x], self._M1[y])
        bitset_symmetric_difference(self._t, self._M0[x], self._M0[y])
        bitset_union(self._M0[x], self._s, self._t)
        bitset_symmetric_difference(self._t, self._M1[y], self._t)
        bitset_symmetric_difference(self._s, self._M0[y], self._M1[x])
        bitset_intersection(self._M1[x], self._s, self._t)

    cdef void _row_negate(self, long x):
        bitset_symmetric_difference(self._M1[x], self._M1[x], self._M0[x])

    cdef void swap_rows_c(self, long x, long y):
        bitset_copy(self._s, self._M0[x])
        bitset_copy(self._M0[x], self._M0[y])
        bitset_copy(self._M0[y], self._s)
        bitset_copy(self._t, self._M1[x])
        bitset_copy(self._M1[x], self._M1[y])
        bitset_copy(self._M1[y], self._t)

    cdef void pivot(self, long x, long y):   # Not a Sage matrix operation
        """
        Row-reduce to make column ``y`` have a ``1`` in row ``x`` and zeroes
        elsewhere.

        Assumption (not checked): the entry in row ``x``, column ``y`` is
        nonzero to start with.

        .. NOTE::

            This is different from what matroid theorists tend to call a
            pivot, as it does not involve a column exchange!
        """
        cdef long i, j
        if self._is_negative(x, y):
            self._row_negate(x)
        for i from 0 <= i < self._nrows:
            if self.is_nonzero(i, y) and i != x:
                if self._is_negative(i, y):
                    self.add_multiple_of_row_c(i, x, 1, 0)
                else:
                    self.row_subs(i, x)

    cdef list nonzero_positions_in_row(self, long r):
        """
        Get coordinates of nonzero entries of row ``r``.
        """
        return bitset_list(self._M0[r])

    cdef LeanMatrix transpose(self):
        """
        Return the transpose of the matrix.
        """
        cdef TernaryMatrix T
        cdef long i, j
        T = TernaryMatrix(self._ncols, self._nrows)
        for i from 0 <= i < self._nrows:
            j = bitset_first(self._M0[i])
            while j >= 0:
                bitset_add(T._M0[j], i)
                if bitset_in(self._M1[i], j):
                    bitset_add(T._M1[j], i)
                j = bitset_next(self._M0[i], j + 1)
        return T

    cdef LeanMatrix _matrix_times_matrix_(self, LeanMatrix other):
        """
        Return the product ``self * other``.
        """
        cdef TernaryMatrix M
        M = TernaryMatrix(self._nrows + 1, other.ncols())
        cdef long i, j
        for i from 0 <= i < self._nrows:
            j = bitset_first(self._M0[i])
            while j >= 0:
                bitset_copy(M._M0[self._nrows], (<TernaryMatrix>other)._M0[j])
                bitset_copy(M._M1[self._nrows], (<TernaryMatrix>other)._M1[j])
                if bitset_in(self._M1[i], j):
                    M.add_multiple_of_row_c(i, self._nrows, 1, 0)
                else:
                    M.row_subs(i, self._nrows)
                j = bitset_next(self._M0[i], j + 1)
        M.resize(self._nrows)
        return M

    def __richcmp__(left, right, op):
        """
        Compare two matrices.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = TernaryMatrix(2, 2, Matrix(GF(3), [[1, 0], [0, 1]]))
            sage: B = TernaryMatrix(2, 2, Matrix(GF(3), [[1, 0], [0, 1]]))
            sage: C = TernaryMatrix(2, 2, Matrix(GF(3), [[1, 1], [0, 1]]))
            sage: D = TernaryMatrix(2, 2, Matrix(GF(3), [[1, 1], [0, 1]]))
            sage: E = TernaryMatrix(2, 3, Matrix(GF(3), [[1, 0, 0], [0, 1, 0]]))
            sage: A == B  # indirect doctest
            True
            sage: A != C  # indirect doctest
            True
            sage: A == D  # indirect doctest
            False
            sage: E == A
            False
        """
        cdef long i, j
        if op in [0, 1, 4, 5]:  # <, <=, >, >=
            return NotImplemented
        if not isinstance(left, TernaryMatrix) or not isinstance(right, TernaryMatrix):
            return NotImplemented
        if op == 2:  # ==
            res = True
        if op == 3:  # !=
            res = False
        # res gets inverted if matroids are deemed different.
        if left.nrows() != right.nrows():
            return not res
        if left.ncols() != right.ncols():
            return not res
        for i from 0 <= i < left.nrows():
            if not bitset_eq((<TernaryMatrix>left)._M0[i], (<TernaryMatrix>right)._M0[i]):
                return not res
            if not bitset_eq((<TernaryMatrix>left)._M1[i], (<TernaryMatrix>right)._M1[i]):
                return not res
        return res

    def __reduce__(self):
        """
        Save the object.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = TernaryMatrix(2, 5)
            sage: A == loads(dumps(A))  # indirect doctest
            True
            sage: C = TernaryMatrix(2, 2, Matrix(GF(3), [[1, 1], [0, 1]]))
            sage: C == loads(dumps(C))
            True
        """
        import sage.matroids.unpickling
        version = 0
        M0 = []
        M1 = []
        versionB = 0
        size = 0
        limbs = 0
        longsize = 0
        for i from 0 <= i < self.nrows():
            versionB, size, limbs, longsize, data = bitset_pickle(self._M0[i])
            M0.append(data)
            versionB, size, limbs, longsize, data = bitset_pickle(self._M1[i])
            M1.append(data)
        data = (self.nrows(), self.ncols(), versionB, size, limbs, longsize, M0, M1)
        return sage.matroids.unpickling.unpickle_ternary_matrix, (version, data)

cdef class QuaternaryMatrix(LeanMatrix):
    """
    Matrices over GF(4).

    INPUT:

    - ``m`` -- Number of rows
    - ``n`` -- Number of columns
    - ``M`` -- (default: ``None``) A QuaternaryMatrix or LeanMatrix or (Sage)
      Matrix instance. If not given, new matrix will be filled with zeroes.
      Assumption: ``M`` has dimensions at most ``m`` times ``n``.
    - ``ring`` -- (default: ``None``) A copy of GF(4). Useful for specifying
      generator name.

    EXAMPLES::

        sage: from sage.matroids.lean_matrix import *
        sage: A = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))
        sage: B = QuaternaryMatrix(2, 2, GenericMatrix(2, 2, ring=GF(4, 'x')))
        sage: C = QuaternaryMatrix(2, 2, ring=GF(4, 'x'))
        sage: A == B and A == C
        True
    """
    def __cinit__(self, long m, long n, M=None, ring=None):
        """
        Init internal data structures.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
        """
        cdef long i, j
        self._nrows = m
        self._ncols = n
        self._M0 = <bitset_t* > sage_malloc(self._nrows * sizeof(bitset_t))
        self._M1 = <bitset_t* > sage_malloc(self._nrows * sizeof(bitset_t))

        if isinstance(M, QuaternaryMatrix):
            j = max(1, (<QuaternaryMatrix>M)._ncols)
        else:
            j = max(1, self._ncols)

        for i from 0 <= i < self._nrows:
            bitset_init(self._M0[i], j)
            bitset_clear(self._M0[i])
            bitset_init(self._M1[i], j)
            bitset_clear(self._M1[i])
        bitset_init(self._s, j)
        bitset_init(self._t, j)
        bitset_init(self._u, j)

    def __init__(self, long m, long n, M=None, ring=None):
        """
        See class docstring for full specification.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
        """
        cdef long i, j
        if M is not None:
            if isinstance(M, QuaternaryMatrix):
                self._gf4 = (<QuaternaryMatrix>M)._gf4
                self._zero = self._gf4(0)
                self._one = self._gf4(1)
                self._x_zero = self._gf4.gens()[0]
                self._x_one = self._x_zero + self._one
                for i from 0 <= i < (<QuaternaryMatrix>M)._nrows:
                    bitset_copy(self._M0[i], (<QuaternaryMatrix>M)._M0[i])
                    bitset_copy(self._M1[i], (<QuaternaryMatrix>M)._M1[i])
                j = max(1, self._ncols)
                for i from 0 <= i < self._nrows:
                    bitset_realloc(self._M0[i], j)
                    bitset_realloc(self._M1[i], j)
            elif isinstance(M, LeanMatrix):
                self._gf4 = (<LeanMatrix>M).base_ring()
                self._zero = self._gf4(0)
                self._one = self._gf4(1)
                self._x_zero = self._gf4.gens()[0]
                self._x_one = self._x_zero + self._one
                for i from 0 <= i < M.nrows():
                    for j from 0 <= j < M.ncols():
                        self.set(i, j, (<LeanMatrix>M).get_unsafe(i, j))
            elif isinstance(M, Matrix):
                self._gf4 = (<Matrix>M).base_ring()
                self._zero = self._gf4(0)
                self._one = self._gf4(1)
                self._x_zero = self._gf4.gens()[0]
                self._x_one = self._x_zero + self._one
                for i from 0 <= i < M.nrows():
                    for j from 0 <= j < M.ncols():
                        self.set(i, j, (<Matrix>M).get_unsafe(i, j))
            else:
                raise TypeError("unrecognized input type.")
        else:
            self._gf4 = ring
            self._zero = self._gf4(0)
            self._one = self._gf4(1)
            self._x_zero = self._gf4.gens()[0]
            self._x_one = self._x_zero + self._one

    def __dealloc__(self):
        """
        Free internal data structures.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
            sage: A = None
        """
        cdef long i
        for i from 0 <= i < self._nrows:
            bitset_free(self._M0[i])
            bitset_free(self._M1[i])
        sage_free(self._M0)
        sage_free(self._M1)
        bitset_free(self._s)
        bitset_free(self._t)
        bitset_free(self._u)

    def __repr__(self):
        """
        Print representation string

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 3, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))
            sage: repr(A)  # indirect doctest
            '2 x 3 QuaternaryMatrix\n[000]\n[000]'
        """
        out = str(self._nrows) + ' x ' + str(self._ncols) + ' QuaternaryMatrix'
        cdef long i
        if self._ncols > 0:
            for i from 0 <= i < self._nrows:
                out += '\n['
                for j from 0 <= j < self._ncols:
                    x = self.get(i, j)
                    if x == self._zero:
                        out += '0'
                    if x == self._one:
                        out += '1'
                    if x == self._x_zero:
                        out += 'x'
                    if x == self._x_one:
                        out += 'y'
                out += ']'
        else:
            for i from 0 <= i < self._nrows:
                out += '[]'
        return out

    def _matrix_(self):
        """
        Return Sage Matrix version of ``self``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 3, Matrix(GF(4, 'x'), [[0, 0], [0, 0]]))
            sage: A._matrix_()
            [0 0 0]
            [0 0 0]
        """
        M = sage.matrix.constructor.Matrix(self._gf4, self._nrows, self._ncols)
        for i from 0 <= i < self._nrows:
            for j from 0 <= j < self._ncols:
                M[i, j] = self.get(i, j)
        return M

    cdef inline get(self, long r, long c):   # Not a Sage matrix operation
        if bitset_in(self._M0[r], c):
            if bitset_in(self._M1[r], c):
                return self._x_one
            else:
                return self._one
        else:
            if bitset_in(self._M1[r], c):
                return self._x_zero
            else:
                return self._zero

    cdef inline void set(self, long r, long c, x):   # Not a Sage matrix operation
        if x == self._zero:
            bitset_discard(self._M0[r], c)
            bitset_discard(self._M1[r], c)
        if x == self._one:
            bitset_add(self._M0[r], c)
            bitset_discard(self._M1[r], c)
        if x == self._x_zero:
            bitset_discard(self._M0[r], c)
            bitset_add(self._M1[r], c)
        if x == self._x_one:
            bitset_add(self._M0[r], c)
            bitset_add(self._M1[r], c)

    cdef get_unsafe(self, long r, long c):
        return self.get(r, c)

    cdef void set_unsafe(self, long r, long c, x):
        self.set(r, c, x)

    cdef bint is_nonzero(self, long r, long c):   # Not a Sage matrix operation
        return bitset_in(self._M0[r], c) or bitset_in(self._M1[r], c)

    cdef LeanMatrix copy(self):   # Deprecated Sage matrix operation
        cdef QuaternaryMatrix T
        cdef long i
        T = QuaternaryMatrix(self._nrows, self._ncols, ring=self._gf4)
        for i from 0 <= i < self._nrows:
            bitset_copy(T._M0[i], self._M0[i])
            bitset_copy(T._M1[i], self._M1[i])
        return T

    cdef void resize(self, long k):   # Not a Sage matrix operation
        """
        Change number of rows to ``k``. Preserves data.
        """
        if k < self._nrows:
            for i from k <= i < self._nrows:
                bitset_free(self._M0[i])
                bitset_free(self._M1[i])
            self._nrows = k
            self._M0 = <bitset_t* > sage_realloc(self._M0, k * sizeof(bitset_t))
            self._M1 = <bitset_t* > sage_realloc(self._M1, k * sizeof(bitset_t))
        if k > self._nrows:
            self._M0 = <bitset_t* > sage_realloc(self._M0, k * sizeof(bitset_t))
            self._M1 = <bitset_t* > sage_realloc(self._M1, k * sizeof(bitset_t))
            c = max(1, self._ncols)
            for i from self._nrows <= i < k:
                bitset_init(self._M0[i], c)
                bitset_clear(self._M0[i])
                bitset_init(self._M1[i], c)
                bitset_clear(self._M1[i])
            self._nrows = k

    cdef LeanMatrix stack(self, LeanMatrix MM):
        cdef QuaternaryMatrix R
        cdef QuaternaryMatrix M = <QuaternaryMatrix > MM
        cdef long i
        R = QuaternaryMatrix(self.nrows() + M.nrows(), self.ncols(), self)
        for i from 0 <= i < self._nrows:
            bitset_copy(R._M0[i + self.nrows()], M._M0[i])
            bitset_copy(R._M1[i + self.nrows()], M._M1[i])
        return R

    cdef LeanMatrix augment(self, LeanMatrix MM):
        cdef QuaternaryMatrix R
        cdef QuaternaryMatrix M = <QuaternaryMatrix > MM
        cdef long i, j
        R = QuaternaryMatrix(self.nrows(), self.ncols() + M.ncols(), self)
        for i from 0 <= i < R.nrows():
            for j from 0 <= j < M.ncols():
                bitset_set_to(R._M0[i], self.ncols() + j, bitset_in(M._M0[i], j))
                bitset_set_to(R._M1[i], self.ncols() + j, bitset_in(M._M1[i], j))
        return R

    cdef LeanMatrix prepend_identity(self):   # Not a Sage matrix operation
        """
        Return the matrix obtained by prepending an identity matrix. Special
        case of ``augment``.
        """
        cdef long i, j
        cdef QuaternaryMatrix A = QuaternaryMatrix(self._nrows, self._ncols + self._nrows, ring=self._gf4)
        for i from 0 <= i < self._nrows:
            A.set(i, i, 1)
            for j from 0 <= j < self._ncols:
                A.set(i, self._nrows + j, self.get(i, j))
        return A

    cpdef base_ring(self):
        """
        Return copy of `GF(4)` with appropriate generator.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 2, ring=GF(4, 'f'))
            sage: A.base_ring()
            Finite Field in f of size 2^2
        """
        return self._gf4

    cpdef characteristic(self):
        """
        Return the characteristic of ``self.base_ring()``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(200, 5000, ring=GF(4, 'x'))
            sage: A.characteristic()
            2
        """
        return 2

    cdef inline long row_len(self, long i):   # Not a Sage matrix operation
        """
        Return number of nonzero entries in row ``i``.
        """
        bitset_union(self._t, self._M0[i], self._M1[i])
        return bitset_len(self._t)

    cdef inline row_inner_product(self, long i, long j):   # Not a Sage matrix operation
        """
        Return the inner product between rows ``i`` and ``j``.
        """
        cdef bint a, b
        bitset_intersection(self._t, self._M0[i], self._M0[j])
        bitset_intersection(self._u, self._M0[i], self._M1[j])
        bitset_symmetric_difference(self._t, self._t, self._u)
        bitset_intersection(self._s, self._M1[i], self._M0[j])
        bitset_symmetric_difference(self._u, self._u, self._s)
        bitset_intersection(self._s, self._M1[i], self._M1[j])
        bitset_symmetric_difference(self._t, self._t, self._s)
        a = bitset_len(self._t) % 2
        b = bitset_len(self._u) % 2
        if a:
            if b:
                return self._x_one
            else:
                return self._one
        else:
            if b:
                return self._x_zero
            else:
                return self._zero

    cdef void add_multiple_of_row_c(self, long x, long y, s, bint col_start):
        """
        Add ``s`` times row ``y`` to row ``x``. Argument ``col_start`` is
        ignored.
        """
        if s == self._zero:
            return
        if s == self._one or s is None:
            bitset_symmetric_difference(self._M0[x], self._M0[x], self._M0[y])
            bitset_symmetric_difference(self._M1[x], self._M1[x], self._M1[y])
            return
        if s == self._x_zero:
            bitset_symmetric_difference(self._M0[x], self._M0[x], self._M1[y])
            bitset_symmetric_difference(self._M1[x], self._M1[x], self._M0[y])
            bitset_symmetric_difference(self._M1[x], self._M1[x], self._M1[y])
            return
        if s == self._x_one:
            bitset_symmetric_difference(self._M0[x], self._M0[x], self._M0[y])
            bitset_symmetric_difference(self._M0[x], self._M0[x], self._M1[y])
            bitset_symmetric_difference(self._M1[x], self._M1[x], self._M0[y])
            return

    cdef void swap_rows_c(self, long x, long y):
        bitset_copy(self._s, self._M0[x])
        bitset_copy(self._M0[x], self._M0[y])
        bitset_copy(self._M0[y], self._s)
        bitset_copy(self._t, self._M1[x])
        bitset_copy(self._M1[x], self._M1[y])
        bitset_copy(self._M1[y], self._t)

    cdef inline void _row_div(self, long x, object s):
        """
        Divide all entries in row ``x`` by ``s``.
        """
        if s == self._one:
            return
        if s == self._x_zero:
            bitset_symmetric_difference(self._M0[x], self._M0[x], self._M1[x])
            bitset_symmetric_difference(self._M1[x], self._M0[x], self._M1[x])
            return
        if s == self._x_one:
            bitset_symmetric_difference(self._M1[x], self._M0[x], self._M1[x])
            bitset_symmetric_difference(self._M0[x], self._M0[x], self._M1[x])
            return

    cdef void pivot(self, long x, long y):   # Not a Sage matrix operation
        """
        Row-reduce to make column ``y`` have a ``1`` in row ``x`` and zeroes
        elsewhere.

        Assumption (not checked): the entry in row ``x``, column ``y`` is
        nonzero to start with.

        .. NOTE::

            This is different from what matroid theorists tend to call a
            pivot, as it does not involve a column exchange!
        """
        cdef long i, j
        self._row_div(x, self.get(x, y))
        for i from 0 <= i < self._nrows:
            if self.is_nonzero(i, y) and i != x:
                self.add_multiple_of_row_c(i, x, self.get(i, y), 0)

    cdef list nonzero_positions_in_row(self, long r):
        """
        Get coordinates of nonzero entries of row ``r``.
        """
        bitset_union(self._t, self._M0[r], self._M1[r])
        return bitset_list(self._t)

    cdef LeanMatrix transpose(self):
        """
        Return the transpose of the matrix.
        """
        cdef QuaternaryMatrix T
        cdef long i, j
        T = QuaternaryMatrix(self._ncols, self._nrows, ring=self._gf4)
        for i from 0 <= i < self._ncols:
            for j from 0 <= j < self._nrows:
                T.set(i, j, self.get(j, i))
        return T

    cdef void conjugate(self):   # Not a Sage matrix operation
        """
        Apply the nontrivial GF(4)-automorphism to the entries.
        """
        cdef long i
        for i from 0 <= i < self._nrows:
            bitset_symmetric_difference(self._M0[i], self._M0[i], self._M1[i])

    cdef LeanMatrix _matrix_times_matrix_(self, LeanMatrix other):
        """
        Return the product ``self * other``.
        """
        cdef QuaternaryMatrix M, ot
        ot = <QuaternaryMatrix > other
        M = QuaternaryMatrix(self._nrows + 1, ot._ncols, ring=self._gf4)
        cdef long i, j
        for i from 0 <= i < self._nrows:
            for j from 0 <= j < self._ncols:
                bitset_copy(M._M0[self._nrows], ot._M0[j])
                bitset_copy(M._M1[self._nrows], ot._M1[j])
                M.add_multiple_of_row_c(i, self._nrows, self.get(i, j), 0)
        M.resize(self._nrows)
        return M

    def __neg__(self):
        """
        Negate the matrix.

        In characteristic 2, this does nothing.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[1, 0], [0, 1]]))
            sage: B = -A  # indirect doctest
            sage: B == A
            True
        """
        return self.copy()

    def __richcmp__(left, right, op):
        """
        Compare two matrices.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[1, 0], [0, 1]]))
            sage: B = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[1, 0], [0, 1]]))
            sage: C = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[1, 1], [0, 1]]))
            sage: D = QuaternaryMatrix(2, 2, Matrix(GF(4, 'y'), [[1, 0], [0, 1]]))
            sage: E = QuaternaryMatrix(2, 3, Matrix(GF(4, 'x'), [[1, 0, 0], [0, 1, 0]]))
            sage: A == B  # indirect doctest
            True
            sage: A != C  # indirect doctest
            True
            sage: A == D  # indirect doctest
            False
            sage: E == A
            False
        """
        cdef long i, j
        if op in [0, 1, 4, 5]:  # <, <=, >, >=
            return NotImplemented
        if not isinstance(left, QuaternaryMatrix) or not isinstance(right, QuaternaryMatrix):
            return NotImplemented
        if op == 2:  # ==
            res = True
        if op == 3:  # !=
            res = False
        if left.base_ring() != right.base_ring():
            return not res
        # res gets inverted if matroids are deemed different.
        if left.nrows() != right.nrows():
            return not res
        if left.ncols() != right.ncols():
            return not res
        for i from 0 <= i < left.nrows():
            if not bitset_eq((<QuaternaryMatrix>left)._M0[i], (<QuaternaryMatrix>right)._M0[i]):
                return not res
            if not bitset_eq((<QuaternaryMatrix>left)._M1[i], (<QuaternaryMatrix>right)._M1[i]):
                return not res
        return res

    def __reduce__(self):
        """
        Save the object.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = QuaternaryMatrix(2, 5, ring=GF(4, 'x'))
            sage: A == loads(dumps(A))  # indirect doctest
            True
            sage: C = QuaternaryMatrix(2, 2, Matrix(GF(4, 'x'), [[1, 1], [0, 1]]))
            sage: C == loads(dumps(C))
            True
        """
        import sage.matroids.unpickling
        version = 0
        M0 = []
        M1 = []
        versionB = 0
        size = 0
        limbs = 0
        longsize = 0
        ring = self._gf4
        for i from 0 <= i < self.nrows():
            versionB, size, limbs, longsize, data = bitset_pickle(self._M0[i])
            M0.append(data)
            versionB, size, limbs, longsize, data = bitset_pickle(self._M1[i])
            M1.append(data)
        data = (self.nrows(), self.ncols(), ring, versionB, size, limbs, longsize, M0, M1)
        return sage.matroids.unpickling.unpickle_quaternary_matrix, (version, data)

cpdef GenericMatrix generic_identity(n, ring):
    """
    Return a GenericMatrix instance containing the `n \times n` identity
    matrix over ``ring``.

    EXAMPLES::

        sage: from sage.matroids.lean_matrix import *
        sage: A = generic_identity(2, QQ)
        sage: Matrix(A)
        [1 0]
        [0 1]
    """
    cdef long i
    cdef GenericMatrix A = GenericMatrix(n, n, ring=ring)
    for i from 0 <= i < n:
        A.set_unsafe(i, i, A._one)
    return A

# Integer matrices

cdef class IntegerMatrix(LeanMatrix):
    """
    Matrix over the integers.

    INPUT:

    - ``nrows`` -- number of rows
    - ``ncols`` -- number of columns
    - ``M`` -- (default: ``None``) a ``Matrix`` or ``GenericMatrix`` of
      dimensions at most ``m*n``.

    .. NOTE::

        This class is intended for internal use by the LinearMatroid class
        only. Hence it does not derive from ``SageObject``.
        If ``A`` is a LeanMatrix instance, and you need access from other
        parts of Sage, use ``Matrix(A)`` instead.

        This class is mainly intended for use with the RegularMatroid class,
        so entries are assumed to be small integers. No
        overflow checking takes place!

    EXAMPLES::

        sage: M = Matroid(graphs.CompleteGraph(4).incidence_matrix(),
        ....:             regular=True)  # indirect doctest
        sage: M.is_isomorphic(matroids.Wheel(3))
        True
    """
    def __cinit__(self, long nrows, long ncols, M=None, ring=None):
        """
        Init internal data structures.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = IntegerMatrix(2, 2, Matrix(GF(4, 'x'),
            ....:                   [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
        """
        cdef long i, j
        self._nrows = nrows
        self._ncols = ncols
        self._entries = <int* > sage_malloc(nrows * ncols * sizeof(int))
        memset(self._entries, 0, nrows * ncols * sizeof(int))

    def __init__(self, long nrows, long ncols, M=None, ring=None):
        """
        See class docstring for full information.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = IntegerMatrix(2, 2, Matrix(GF(3),
            ....:                       [[0, 0], [0, 0]]))  # indirect doctest
            sage: B = IntegerMatrix(2, 2)
            sage: A == B
            True
        """
        cdef long i, j
        if M is not None:
            if isinstance(M, IntegerMatrix):
                for i from 0 <= i < M.nrows():
                    memcpy(self._entries + i * self._ncols, (<IntegerMatrix>M)._entries + i * (<IntegerMatrix>M)._ncols, (<IntegerMatrix>M)._ncols * sizeof(int))
            elif isinstance(M, LeanMatrix):
                for i from 0 <= i < M.nrows():
                    for j from 0 <= j < M.ncols():
                        self._entries[i * self._ncols + j] = int((<LeanMatrix>M).get_unsafe(i, j))
            else:  # Sage Matrix or otherwise
                for i from 0 <= i < M.nrows():
                    for j from 0 <= j < M.ncols():
                        self._entries[i * self._ncols + j] = int(M[i, j])

    def __dealloc__(self):
        """
        Free internal data structures.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = IntegerMatrix(2, 2, Matrix(GF(4, 'x'),
            ....:                       [[0, 0], [0, 0]]))  # Indirect doctest
            sage: A.nrows()
            2
            sage: A = None
        """
        sage_free(self._entries)

    def __repr__(self):
        """
        Print representation.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = IntegerMatrix(2, 2, Matrix(GF(3), [[0, 0], [0, 0]]))
            sage: repr(A)  # indirect doctest
            'IntegerMatrix instance with 2 rows and 2 columns'
        """
        return "IntegerMatrix instance with " + str(self._nrows) + " rows and " + str(self._ncols) + " columns"

    cdef inline get(self, long r, long c):   # Not a Sage matrix operation
        return self._entries[r * self._ncols + c]

    cdef inline void set(self, long r, long c, int x):   # Not a Sage matrix operation
        self._entries[r * self._ncols + c] = x

    cdef get_unsafe(self, long r, long c):
        """
        Return a Sage Integer, for safety down the line when dividing.

        EXAMPLE:

        By returning an Integer rather than an int, the following test no
        longer fails::

            sage: from sage.matroids.advanced import *
            sage: M = RegularMatroid(matrix([
            ....:                  (1, 0, 0, 0,  1,  0,  0, -1, 0,  0, 0),
            ....:                  (0, 1, 0, 0, -1,  1,  0,  0, 0,  0, 0),
            ....:                  (0, 0, 1, 0,  0, -1,  1,  0, 0,  1, 0),
            ....:                  (0, 0, 0, 1,  0,  0, -1,  1, 0,  0, 0),
            ....:                  (0, 0, 0, 0,  0,  0, -1,  0, 1, -1, 0),
            ....:                  (0, 0, 0, 0,  0,  0,  0, -1, 1,  0, 1)]))
            sage: all(N.is_valid() for N in M.linear_extensions(F=[4, 10]))
            True
        """
        return Integer(self.get(r, c))

    cdef void set_unsafe(self, long r, long c, x):
        self.set(r, c, x)

    cdef bint is_nonzero(self, long r, long c):   # Not a Sage matrix operation
        return self.get(r, c)

    cdef LeanMatrix copy(self):   # Deprecated Sage matrix operation
        cdef IntegerMatrix M = IntegerMatrix(self._nrows, self._ncols)
        memcpy(M._entries, self._entries, self._nrows * self._ncols * sizeof(int))
        return M

    cdef void resize(self, long k):   # Not a Sage matrix operation
        """
        Change number of rows to ``k``. Preserves data.
        """
        cdef long l = self._ncols * (self._nrows - k)
        if l > 0:
            sage_realloc(self._entries, self._ncols * k * sizeof(int))
            memset(self._entries + self._nrows * self._ncols, 0, l * self._ncols * sizeof(int))
        elif l < 0:
            sage_realloc(self._entries, self._ncols * k * sizeof(int))
        self._nrows = k

    cdef LeanMatrix stack(self, LeanMatrix M):
        """
        Warning: assumes ``M`` is an IntegerMatrix instance of right
        dimensions!
        """
        cdef IntegerMatrix A
        A = IntegerMatrix(self._nrows + M.nrows(), self._ncols)
        memcpy(A._entries, self._entries, self._nrows * self._ncols * sizeof(int))
        memcpy(A._entries + self._nrows * self._ncols, (<IntegerMatrix>M)._entries, M.nrows() * M.ncols() * sizeof(int))
        return A

    cdef LeanMatrix augment(self, LeanMatrix M):
        """
        Warning: assumes ``M`` is a GenericMatrix instance!
        """
        cdef IntegerMatrix A
        cdef long i
        cdef long Mn = M.ncols()
        A = IntegerMatrix(self._nrows, self._ncols + Mn)
        for i from 0 <= i < self._nrows:
            memcpy(A._entries + i * A._ncols, self._entries + i * self._ncols, self._ncols * sizeof(int))
            memcpy(A._entries + (i * A._ncols + self._ncols), (<IntegerMatrix>M)._entries + i * Mn, Mn * sizeof(int))
        return A

    cdef LeanMatrix prepend_identity(self):   # Not a Sage matrix operation
        cdef IntegerMatrix A = IntegerMatrix(self._nrows, self._ncols + self._nrows, ring=self._base_ring)
        cdef long i
        for i from 0 <= i < self._nrows:
            A._entries[i * A._ncols + i] = 1
            memcpy(A._entries + (i * A._ncols + self._nrows), self._entries + i * self._ncols, self._ncols * sizeof(int))
        return A

    cpdef base_ring(self):
        """
        Return the base ring of ``self``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = IntegerMatrix(3, 4)
            sage: A.base_ring()
            Integer Ring
        """
        return ZZ

    cpdef characteristic(self):
        """
        Return the characteristic of ``self.base_ring()``.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = GenericMatrix(3, 4)
            sage: A.characteristic()
            0
        """
        return 0

    cdef inline long row_len(self, long i):   # Not a Sage matrix operation
        """
        Return number of nonzero entries in row ``i``.
        """
        cdef long k
        cdef long res = 0
        for k from 0 <= k < self._ncols:
            if self.get(i, k):
                res += 1
        return res

    cdef inline row_inner_product(self, long i, long j):   # Not a Sage matrix operation
        """
        Return the inner product between rows ``i`` and ``j``.
        """
        cdef long k
        cdef int res = 0
        for k from 0 <= k < self._ncols:
            res += self.get(i, k) * self.get(j, k)
        return res

    cdef void add_multiple_of_row_c(self, long x, long y, s, bint col_start):
        """
        Add ``s`` times row ``y`` to row ``x``. Argument ``col_start`` is
        ignored.
        """
        cdef long i
        if s is None:
            for i from 0 <= i < self._ncols:
                self.set(x, i, self.get(x, i) + self.get(y, i))
        else:
            for i from 0 <= i < self._ncols:
                self.set(x, i, self.get(x, i) + s * self.get(y, i))

    cdef void swap_rows_c(self, long x, long y):
        """
        Swap rows ``x`` and ``y``.
        """
        cdef int* tmp
        tmp = <int* > sage_malloc(self._ncols * sizeof(int))
        memcpy(tmp, self._entries + x * self._ncols, self._ncols * sizeof(int))
        memcpy(self._entries + x * self._ncols, self._entries + y * self._ncols, self._ncols * sizeof(int))
        memcpy(self._entries + y * self._ncols, tmp, self._ncols * sizeof(int))
        sage_free(tmp)

    cdef void rescale_row_c(self, long x, s, bint col_start):
        """
        Scale row ``x`` by ``s``. Argument ``col_start`` is for Sage
        compatibility, and is ignored.
        """
        cdef long i
        # print "row-scale: ", x, ", ", s
        for i from 0 <= i < self._ncols:
            self.set(x, i, s * self.get(x, i))

    cdef void rescale_column_c(self, long y, s, bint start_row):
        """
        Scale column ``y`` by ``s``. Argument ``start_row`` is for Sage
        compatibility, and is ignored.
        """
        cdef long j
        for j from 0 <= j < self._nrows:
            self.set(j, y, self.get(j, y) * s)

    cdef void pivot(self, long x, long y):   # Not a Sage matrix operation
        """
        Row-reduce to make column ``y`` have a ``1`` in row ``x`` and zeroes
        elsewhere.

        Assumption (not checked): the entry in row ``x``, column ``y`` is
        invertible (so 1 or -1) to start with.

        .. NOTE::

            This is different from what matroid theorists tend to call a
            pivot, as it does not involve a column exchange!
        """
        cdef long i, j
        cdef int a, s
        a = self.get(x, y)  # 1 or -1, so inverse is equal to itself
        self.rescale_row_c(x, a, 0)
        for i from 0 <= i < self._nrows:
            s = self.get(i, y)
            if s and i != x:
                self.add_multiple_of_row_c(i, x, -s, 0)

    cdef list nonzero_positions_in_row(self, long r):
        """
        Get coordinates of nonzero entries of row ``r``.
        """
        cdef long j
        cdef list res = []
        for j from r * self._ncols <= j < (r + 1) * self._ncols:
            if self._entries[j]:
                res.append(j - r * self._ncols)
        return res

    cdef LeanMatrix transpose(self):
        """
        Return the transpose of the matrix.
        """
        cdef IntegerMatrix A
        cdef long i, j
        A = IntegerMatrix(self._ncols, self._nrows)
        for i from 0 <= i < self._nrows:
            for j from 0 <= j < self._ncols:
                A.set(j, i, self.get(i, j))
        return A

    cdef LeanMatrix _matrix_times_matrix_(self, LeanMatrix other):
        """
        Return the product ``self * other``.
        """
        cdef IntegerMatrix A, ot
        cdef long i, j, t
        ot = <IntegerMatrix > other
        A = IntegerMatrix(self._nrows, ot._ncols)
        for i from 0 <= i < A._nrows:
            for j from 0 <= j < A._ncols:
                s = 0
                for t from 0 <= t < self._ncols:
                    s += self.get(i, t) * ot.get(t, j)
                A.set(i, j, s)
        return A

    cdef list gauss_jordan_reduce(self, columns):   # Not a Sage matrix operation
        """
        Row-reduce so the lexicographically first basis indexes an identity
        submatrix.
        """
        cdef long r = 0
        cdef list P = []
        cdef long a, c, p, row
        cdef bint is_pivot
        for c in columns:
            is_pivot = False
            for row from r <= row < self._nrows:
                a = self.get(row, c)
                if a:
                    if a < -1 or a > 1:
                        raise ValueError("not a totally unimodular matrix")
                    is_pivot = True
                    p = row
                    break
            if is_pivot:
                self.swap_rows_c(p, r)
                self.rescale_row_c(r, self.get(r, c), 0)  # Inverting not needed for integers -1, 1
                for row from 0 <= row < self._nrows:
                    if row != r and self.is_nonzero(row, c):
                        self.add_multiple_of_row_c(row, r, -self.get(row, c), 0)
                P.append(c)
                r += 1
            if r == self._nrows:
                break
        return P

    def __richcmp__(left, right, op):
        """
        Compare two matrices.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = IntegerMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: B = IntegerMatrix(2, 2, Matrix(GF(2), [[1, 0], [0, 1]]))
            sage: C = IntegerMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: D = IntegerMatrix(2, 2, Matrix(GF(2), [[1, 1], [0, 1]]))
            sage: E = IntegerMatrix(2, 3, Matrix(GF(2), [[1, 0, 0], [0, 1, 0]]))
            sage: A == B  # indirect doctest
            True
            sage: A != C  # indirect doctest
            True
            sage: A == D  # indirect doctest
            False
            sage: E == A
            False
        """
        cdef long i, j
        if op in [0, 1, 4, 5]:  # <, <=, >, >=
            return NotImplemented
        if not isinstance(left, IntegerMatrix) or not isinstance(right, IntegerMatrix):
            return NotImplemented
        if op == 2:  # ==
            res = True
        if op == 3:  # !=
            res = False
        # res gets inverted if matroids are deemed different.
        if left.nrows() != right.nrows():
            return not res
        if left.ncols() != right.ncols():
            return not res
        for i from 0 <= i < left.nrows() * left.ncols():
            if (<IntegerMatrix>left)._entries[i] != (<IntegerMatrix>right)._entries[i]:
                return not res
        return res

    def __reduce__(self):
        """
        Save the object.

        EXAMPLES::

            sage: from sage.matroids.lean_matrix import *
            sage: A = IntegerMatrix(2, 5)
            sage: A == loads(dumps(A))  # indirect doctest
            True
            sage: C = IntegerMatrix(2, 2, Matrix(GF(3), [[1, 1], [0, 1]]))
            sage: C == loads(dumps(C))
            True
        """
        import sage.matroids.unpickling
        cdef list entries = []
        cdef long i
        for i from 0 <= i < self._nrows * self._ncols:
            entries.append(self._entries[i])
        version = 0
        data = (self.nrows(), self.ncols(), entries)
        return sage.matroids.unpickling.unpickle_integer_matrix, (version, data)
