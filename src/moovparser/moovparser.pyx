# cython: language_level=3, boundscheck=False, wraparound=False, initializedcheck=False
from libc.stdio cimport printf
from libc.stdint cimport uint8_t, uint32_t, int32_t
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from cpython cimport array
cimport cython
from cython cimport view

cdef class Node:
    cdef:
        const unsigned char[:] name
        const unsigned char[:] data
        # Py_ssize_t size
        Py_ssize_t begin
        Node next

    def __cinit__(self):
        self.next = None
    
    def __repr__(self):
        cdef list res = []
        res.append(f"name:{bytes(self.name).decode()}, size:{self.data.shape[0]}, start:{self.begin}")
        if self.next:
            res.append(self.next.__repr__())
        return "\n".join(res)

    @staticmethod
    cdef Node New(const unsigned char* name, const unsigned char[:] data, Py_ssize_t begin):
        cdef Node node = Node.__new__(Node)
        node.name = name[:4]
        node.data = data
        # node.size = size
        node.begin = begin
        return node

cdef class FrameFinder:
    cdef:
        Node stco
        Node stsc
        Node stsz
        int32_t[::1] pre_sum_stsc
    
    def __cinit__(self, Node stco, Node stsc, Node stsz):
        self.stco = stco
        self.stsc = stsc
        self.stsz = stsz
        self.init_pre_sum_stsc()

    cdef void init_pre_sum_stsc(self):
        if self.stsc is None:
            raise ValueError("stsc is None")
        cdef:
            int32_t entry_num = 0
            int32_t entry_start = 0
            int entry_size = 12
            int32_t pre_sum = 0
            int32_t entry_count = char2int32(&self.stsc.data[12])
            array.array template = array.array("l", [])
        self.pre_sum_stsc = array.clone(template, entry_count, zero=False)
        printf("entry_count: %d\n", entry_count)
        for entry_num in range(entry_count):
            entry_start = 16 + entry_num * entry_size
            pre_sum += char2int32(&self.stsc.data[entry_start + 4])
            printf("stsc: %d\n", char2int32(&self.stsc.data[entry_start + 4]))
            self.pre_sum_stsc[entry_num] = pre_sum
    
    cpdef int32_t find_frame_index(self, int32_t frame_index):
        cdef:
            int32_t lo = 0
            int32_t hi = self.pre_sum_stsc.shape[0]
            int32_t mid
        # bisect left 
        while lo < hi:
            mid = (lo + hi) // 2
            if self.pre_sum_stsc[mid] < frame_index:
                lo = mid + 1
            else:
                hi = mid
        if lo < self.pre_sum_stsc.shape[0]:
            return char2int32(&self.stsc.data[16 + lo * 12])
        return -1

    def __repr__(self):
        cdef:
            list pre_nums = []
            int32_t i = 0
        for i in range(self.pre_sum_stsc.shape[0]):
            pre_nums.append(str(self.pre_sum_stsc[i]))
        return ",".join(pre_nums)

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

cdef void parse_stsc(const unsigned char[:] data):
    cdef:
        int frame_num = 0
        int32_t entry_num = 0
        int32_t entry_start = 0
        int entry_size = 12
    # printf("size: %d\n", char2int32(&data[0]))
    # printf("type: %s\n", &data[4:8][0])
    # printf("version: %d\n", data[8])
    # printf("flags: %d\n", data[9:12])
    # printf("entry count: %d\n", char2int32(&data[12]))
    
    for entry_num in range(char2int32(&data[12])):
        entry_start = 16 + entry_num * entry_size
        # printf("chunk id: %d\n", char2int32(&data[entry_start]))
        # printf("samples per chunk: %d\n", char2int32(&data[entry_start+4]))
        # printf("samples description id: %d\n", char2int32(&data[entry_start+8]))
        frame_num += char2int32(&data[entry_start+4])
    # printf("frame num: %d\n", frame_num)

cdef bint parse_stsd_is_mp4a(const unsigned char[:] data):
    cdef:
        int32_t entry_num = 0
        int32_t entry_start = 0
        int entry_size = 16
        int i = 0
    # printf("size: %d\n", char2int32(&data[0]))
    # printf("type: %s\n", &data[4:8][0])
    # printf("version: %d\n", data[8])
    # printf("flags: %d\n", data[9:12])
    # printf("entry count: %d\n", char2int32(&data[12]))
    
    for entry_num in range(1):
        entry_start = 16 + entry_num * entry_size
        # printf("Sample description size: %d\n", char2int32(&data[entry_start]))
        # printf("Data format: %s\n", &data[entry_start+4])
        return is_atom(&data[entry_start+4], b"mp4a")
        # for i in range(6):    
        #     printf("Reserved: %d\n", data[entry_start+8+i])
        # printf("Data reference index: %d\n", data[entry_start+14] << 8 | data[entry_start+15])
        

cdef void parse_stco(const unsigned char[:] data):
    cdef:
        int32_t entry_num = 0
        int32_t entry_start = 0
        int entry_size = 4
    
    printf("size: %d\n", char2int32(&data[0]))
    printf("type: %s\n", &data[4:8][0])
    printf("version: %d\n", data[8])
    printf("flags: %d\n", data[9:12])
    printf("entry count: %d\n", char2int32(&data[12]))
    for entry_num in range(char2int32(&data[12])):
        entry_start = 16 + entry_num * entry_size
        printf("chunk offset: %d\n", char2int32(&data[entry_start]))

cdef void parse_stsz(const unsigned char[:] data):
    cdef:
        int32_t entry_num = 0
        int32_t entry_start = 0
        int entry_size = 4
        int sum_18 = 0
    # printf("size: %d\n", char2int32(&data[0]))
    # printf("type: %s\n", &data[4:8][0])
    # printf("version: %d\n", data[8])
    # printf("flags: %d\n", data[9:12])
    # printf("sample size: %d\n", char2int32(&data[12]))
    # printf("entry count: %d\n", char2int32(&data[16]))
    for entry_num in range(char2int32(&data[16])):
        entry_start = 20 + entry_num * entry_size
        if entry_num < 18:
            sum_18 += char2int32(&data[entry_start])
    #     if entry_num == 0:
    #         printf("sample size: %d\n", char2int32(&data[entry_start]))
    # printf("sum 18:%d\n", sum_18)

# @cython.boundscheck(False)
# @cython.wraparound(False)
# @cython.initializedcheck(False)
cpdef Node parse_nodes(const unsigned char[:] raw_data):
    cdef:
        Node root = None
        Node node = None
        Py_ssize_t p = 0
        Py_ssize_t moov_begin = 0
        const unsigned char** atom_name_ptr = NULL
        const unsigned char[:] data
        FrameFinder frame_finder = None
        bint found_mp4a = False
        Node stco = None
        Node stsc = None
        Node stsz = None
    
    for p in range(raw_data.shape[0]):
        if is_atom(&raw_data[p], b"moov"):
            break
    if p >= raw_data.shape[0]:
        raise Exception("no moov")
    if p>=4:
        p-=4
    data = raw_data[p:].copy()
    moov_begin = p
    p = 0
    while p < data.shape[0]-4:
        atom_name_ptr = all_atom_names
        while atom_name_ptr[0]:
            if is_atom(&data[p], atom_name_ptr[0]):
                break
            atom_name_ptr+=1
        if atom_name_ptr[0]:
            if node is not None:
                node.next = Node.New(atom_name_ptr[0], data[p-4:p-4+char2int32(&data[p-4])], moov_begin+p-4)
                node = node.next
                if found_mp4a:
                    if is_atom(&node.name[0], b"stsc"):
                        stsc = node
                        # parse_stsc(node.data[:])      
                    if is_atom(&node.name[0], b"stco"):
                        stco = node
                        parse_stco(node.data[:])
                    if is_atom(&node.name[0], b"stsz"):
                        stsz = node
                        # parse_stsz(node.data[:])
                if is_atom(&node.name[0], b"stsd"):
                    found_mp4a = parse_stsd_is_mp4a(node.data[:])
                
            if root is None: 
                root = Node.New(atom_name_ptr[0], data[p-4:p-4+char2int32(&data[p-4])], moov_begin+p-4)
                node = root
        p+=1

        if is_atom(&node.name[0], b"udta"):
            p+=node.data.shape[0]-1
    if stsc is not None and stsz is not None and stco is not None:
        frame_finder = FrameFinder(stco, stsc, stsz)
    print(frame_finder)
    print(frame_finder.find_frame_index(0))
    print(frame_finder.find_frame_index(18))
    print(frame_finder.find_frame_index(19))
    print(frame_finder.find_frame_index(80))
    print(frame_finder.find_frame_index(300))
    print(frame_finder.find_frame_index(312))
    print(frame_finder.find_frame_index(313))
    return root

