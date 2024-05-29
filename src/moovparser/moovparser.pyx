# cython: language_level=3
from libc.stdio cimport printf
from libc.stdint cimport uint8_t, uint32_t, int32_t
cimport cython

cdef class Node:
    cdef:
        bytes name
        const unsigned char* data
        Py_ssize_t size
        Py_ssize_t begin
        list[Node] children

    def __cinit__(self):
        self.children = []
    
    def __repr__(self):
        cdef list res = []
        res.append(f"name:{self.name}, size:{self.size}, start:{self.begin}")
        if self.children:
            for child in self.children:
                res.append(f"  {child.__repr__()}")
        return "\n".join(res)

    @staticmethod
    cdef Node New(const unsigned char* name, const unsigned char* data, Py_ssize_t size, Py_ssize_t begin):
        cdef Node node = Node.__new__(Node)
        node.name = name[:4]
        node.data = data
        node.size = size
        node.begin = begin
        return node

# @cython.boundscheck(False)
cdef int32_t char2int32(const unsigned char* data) noexcept:
    return (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3]

# @cython.boundscheck(False)
cdef cython.bint is_atom(const unsigned char* data, const unsigned char* atom_type) noexcept:
    return data[0] == atom_type[0] and data[1] == atom_type[1] and data[2] == atom_type[2] and data[3] == atom_type[3]



@cython.boundscheck(False)
@cython.wraparound(False)
# @cython.initializedcheck(False)
cpdef Node parse_nodes(const unsigned char[:] data):
    cdef:
        Node moov
        Py_ssize_t p = 0
        Py_ssize_t moov_size = 0
        const cython.uchar* moov_n = b"moov"
    for p in range(data.shape[0]-4):
        if is_atom(&data[p], moov_n):
            break
    moov_size = char2int32(&data[p-4])
    moov = Node.New(&data[p:p+4][0], &data[p-4], moov_size, p-4)
    if moov.begin+moov.size > data.shape[0]:
        raise Exception("incompleted moov")
    cdef:
        const unsigned char* atom_type
        const unsigned char[:] atom_type0 = b""
        const cython.uchar* mchn_ptr = b"mvhdtrak"
        uint8_t atom_index = 0
    for p in  range(moov.size-4):
        for atom_index in range(2):
            atom_type = mchn_ptr + atom_index*4
            if is_atom(moov.data+p, atom_type):
                node = Node.New(atom_type, moov.data+p-4, char2int32(&moov.data[p-4]), moov.begin+p-4)
                moov.children.append(node)
                break
    return moov

