# cython: language_level=3, boundscheck=False, wraparound=False, initializedcheck=False
from libc.stdio cimport printf
from libc.stdint cimport uint8_t, uint32_t, int32_t
cimport cython

cdef class Node:
    cdef:
        const unsigned char[:] name
        const unsigned char* data
        Py_ssize_t size
        Py_ssize_t begin
        Node next

    def __cinit__(self):
        self.next = None
    
    def __repr__(self):
        cdef list res = []
        res.append(f"name:{bytes(self.name).decode()}, size:{self.size}, start:{self.begin}")
        if self.next:
            res.append(self.next.__repr__())
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


cdef extern from *:
    """
    const unsigned char* mchn_ptr[] = {"mvhd", "trak"};
    const unsigned char* all_atom_names[] = {"moov", "mvhd", "trak",
    "prfl",
    "tkhd",
    "tapt",
    "clip",
    "matt",
    "edts",
    "tref",
    "txas",
    "load",
    "imap",
    "mdia",
    "mdhd", "elng", "hdlr", "minf", "udta",
    "stbl" ,"stsd", "stts", "ctts", "cslg", "stco", "stsc", "stsz"
    };
    """
    cdef const unsigned char** mchn_ptr
    cdef const unsigned char** all_atom_names

# @cython.boundscheck(False)
# @cython.wraparound(False)
# @cython.initializedcheck(False)
cpdef Node parse_nodes(const unsigned char[:] data):
    cdef:
        Node root = None
        Node node = None
        Py_ssize_t p = 0
        const cython.uchar** atom_name_ptr = NULL
    for p in range(data.shape[0]):
        if is_atom(&data[p], b"moov"):
            break
    if p >= data.shape[0]:
        raise Exception("no moov")
    if p>=4:
        p-=4
    # if root.begin+root.size > data.shape[0]:
    #     raise Exception("incompleted moov")
    while p < data.shape[0]-4:
        atom_name_ptr = all_atom_names
        while atom_name_ptr[0]:
            if is_atom(&data[p], atom_name_ptr[0]):
                break
            atom_name_ptr+=1
        if atom_name_ptr[0]:
            if node is not None:
                node.next = Node.New(atom_name_ptr[0], &data[p-4], char2int32(&data[p-4]), p-4)
                node = node.next
            if root is None: 
                root = Node.New(atom_name_ptr[0], &data[p-4], char2int32(&data[p-4]), p-4)
                node = root
        p+=1      
        if is_atom(&node.name[0], b"udta"):
            p+=node.size-1

    return root

