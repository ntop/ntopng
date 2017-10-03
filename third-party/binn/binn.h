
// TO ENABLE INLINE FUNCTIONS:
//   ON MSVC: enable the 'Inline Function Expansion' (/Ob2) compiler option, and maybe the
//            'Whole Program Optimitazion' (/GL), that requires the
//            'Link Time Code Generation' (/LTCG) linker option to be enabled too

#ifndef BINN_H
#define BINN_H

#ifdef __cplusplus
extern "C" {
#endif


#ifndef NULL
#ifdef __cplusplus
#define NULL    0
#else
#define NULL    ((void *)0)
#endif
#endif

#ifndef TRUE
#define TRUE  1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef BOOL
typedef int BOOL;
#endif

#ifndef APIENTRY
 #ifdef _WIN32
  #define APIENTRY __stdcall
 #else
  //#define APIENTRY __attribute__((stdcall))
  #define APIENTRY 
 #endif
#endif

#ifndef BINN_PRIVATE
 #ifdef DEBUG
  #define BINN_PRIVATE
 #else
  #define BINN_PRIVATE  static
 #endif
#endif

#ifdef _MSC_VER
  #define INLINE         __inline
  #define ALWAYS_INLINE  __forceinline
#else
  // you can change to 'extern inline' if using the gcc option -flto
  #define INLINE         static inline
  #define ALWAYS_INLINE  static inline __attribute__((always_inline))
#endif

#ifndef int64
#if defined(_MSC_VER) || defined(__BORLANDC__)
  typedef __int64 int64;
  typedef unsigned __int64 uint64;
#else
  typedef int64_t int64;
  typedef u_int64_t uint64;
#endif
#endif

#ifdef _WIN32
#define INT64_FORMAT  "I64i"
#define UINT64_FORMAT "I64u"
#define INT64_HEX_FORMAT  "I64x"
#else
#define INT64_FORMAT  "lli"
#define UINT64_FORMAT "llu"
#define INT64_HEX_FORMAT  "llx"
#endif


// BINN CONSTANTS  ----------------------------------------

#define INVALID_BINN         0

// Storage Data Types  ------------------------------------

#define BINN_STORAGE_NOBYTES   0x00
#define BINN_STORAGE_BYTE      0x20  //  8 bits
#define BINN_STORAGE_WORD      0x40  // 16 bits -- the endianess (byte order) is automatically corrected
#define BINN_STORAGE_DWORD     0x60  // 32 bits -- the endianess (byte order) is automatically corrected
#define BINN_STORAGE_QWORD     0x80  // 64 bits -- the endianess (byte order) is automatically corrected
#define BINN_STORAGE_STRING    0xA0  // Are stored with null termination
#define BINN_STORAGE_BLOB      0xC0
#define BINN_STORAGE_CONTAINER 0xE0
#define BINN_STORAGE_VIRTUAL   0x80000
//--
#define BINN_STORAGE_MIN       BINN_STORAGE_NOBYTES
#define BINN_STORAGE_MAX       BINN_STORAGE_CONTAINER

#define BINN_STORAGE_MASK      0xE0
#define BINN_STORAGE_MASK16    0xE000
#define BINN_STORAGE_HAS_MORE  0x10
#define BINN_TYPE_MASK         0x0F
#define BINN_TYPE_MASK16       0x0FFF

#define BINN_MAX_VALUE_MASK    0xFFFFF
//++

// Data Formats  ------------------------------------------

#define BINN_LIST      0xE0
#define BINN_MAP       0xE1
#define BINN_OBJECT    0xE2

#define BINN_NULL      0x00
#define BINN_TRUE      0x01
#define BINN_FALSE     0x02

#define BINN_UINT8     0x20  // (BYTE) (unsigned byte) Is the default format for the BYTE type
#define BINN_INT8      0x21  // (BYTE) (signed byte, from -128 to +127. The 0x80 is the sign bit, so the range in hex is from 0x80 [-128] to 0x7F [127], being 0x00 = 0 and 0xFF = -1)
#define BINN_UINT16    0x40  // (WORD) (unsigned integer) Is the default format for the WORD type
#define BINN_INT16     0x41  // (WORD) (signed integer)
#define BINN_UINT32    0x60  // (DWORD) (unsigned integer) Is the default format for the DWORD type
#define BINN_INT32     0x61  // (DWORD) (signed integer)
#define BINN_UINT64    0x80  // (QWORD) (unsigned integer) Is the default format for the QWORD type
#define BINN_INT64     0x81  // (QWORD) (signed integer)

#define BINN_SCHAR     BINN_INT8
#define BINN_UCHAR     BINN_UINT8

#define BINN_STRING    0xA0  // (STRING) Raw String
#define BINN_DATETIME  0xA1  // (STRING) iso8601 format -- YYYY-MM-DD HH:MM:SS
#define BINN_DATE      0xA2  // (STRING) iso8601 format -- YYYY-MM-DD
#define BINN_TIME      0xA3  // (STRING) iso8601 format -- HH:MM:SS
#define BINN_DECIMAL   0xA4  // (STRING) High precision number - used for generic decimal values and for those ones that cannot be represented in the float64 format.
#define BINN_CURRENCYSTR  0xA5  // (STRING) With currency unit/symbol - check for some iso standard format
#define BINN_SINGLE_STR   0xA6  // (STRING) Can be restored to float32
#define BINN_DOUBLE_STR   0xA7  // (STRING) May be restored to float64

#define BINN_FLOAT32   0x62  // (DWORD) 
#define BINN_FLOAT64   0x82  // (QWORD) 
#define BINN_FLOAT     BINN_FLOAT32
#define BINN_SINGLE    BINN_FLOAT32
#define BINN_DOUBLE    BINN_FLOAT64

#define BINN_CURRENCY  0x83  // (QWORD)

#define BINN_BLOB      0xC0  // (BLOB) Raw Blob


// virtual types:

#define BINN_BOOL      0x80061  // (DWORD) The value may be 0 or 1

#ifdef BINN_EXTENDED
//#define BINN_SINGLE    0x800A1  // (STRING) Can be restored to float32
//#define BINN_DOUBLE    0x800A2  // (STRING) May be restored to float64
#endif

//#define BINN_BINN      0x800E1  // (CONTAINER)
//#define BINN_BINN_BUFFER  0x800C1  // (BLOB) user binn. it's not open by the parser


// extended content types:

// strings:

#define BINN_HTML      0xB001
#define BINN_XML       0xB002
#define BINN_JSON      0xB003
#define BINN_JAVASCRIPT 0xB004
#define BINN_CSS       0xB005

// blobs:

#define BINN_JPEG      0xD001
#define BINN_GIF       0xD002
#define BINN_PNG       0xD003
#define BINN_BMP       0xD004



//--

// type families
#define BINN_FAMILY_NONE   0x00
#define BINN_FAMILY_NULL   0xf1
#define BINN_FAMILY_INT    0xf2
#define BINN_FAMILY_FLOAT  0xf3
#define BINN_FAMILY_STRING 0xf4
#define BINN_FAMILY_BLOB   0xf5
#define BINN_FAMILY_BOOL   0xf6
#define BINN_FAMILY_BINN   0xf7

// integer types related to signal
#define BINN_SIGNED_INT     11
#define BINN_UNSIGNED_INT   22

//++


typedef void (*binn_mem_free)(void*);
#define BINN_STATIC      ((binn_mem_free)0)
#define BINN_TRANSIENT   ((binn_mem_free)-1)


// --- BINN STRUCTURE --------------------------------------------------------------


struct binn_struct {
  int    header;     // this struct header holds the magic number (BINN_MAGIC) that identifies this memory block as a binn structure
  BOOL   allocated;  // the struct can be allocated using malloc_fn() or can be on the stack
  BOOL   writable;   // did it was create for writing? it can use the pbuf if not unified with ptr
  BOOL   dirty;      // the container header is not written to the buffer
  //
  void  *pbuf;       // use *ptr below?
  BOOL   pre_allocated;
  int    alloc_size;
  int    used_size;
  //
  int    type;
  void  *ptr;
  int    size;
  int    count;
  //
  binn_mem_free freefn;  // used only when type == BINN_STRING or BINN_BLOB
  //
  union {
    signed char    vint8;
    signed short   vint16;
    signed int     vint32;
    int64          vint64;
    unsigned char  vuint8;
    unsigned short vuint16;
    unsigned int   vuint32;
    uint64         vuint64;
    //
    signed char    vchar;
    unsigned char  vuchar;
    signed short   vshort;
    unsigned short vushort;
    signed int     vint;
    unsigned int   vuint;
    //
    float          vfloat;
    double         vdouble;
    //
    BOOL           vbool;
  };
  //
  BOOL   disable_int_compression;
};

typedef struct binn_struct binn;



// --- GENERAL FUNCTIONS  ----------------------------------------------------------


void   APIENTRY binn_set_alloc_functions(void* (*new_malloc)(size_t), void* (*new_realloc)(void*,size_t), void (*new_free)(void*));

int    APIENTRY binn_create_type(int storage_type, int data_type_index);
BOOL   APIENTRY binn_get_type_info(int long_type, int *pstorage_type, int *pextra_type);

int    APIENTRY binn_get_write_storage(int type);
int    APIENTRY binn_get_read_storage(int type);

BOOL   APIENTRY binn_is_container(binn *item);


// --- WRITE FUNCTIONS  ------------------------------------------------------------

// create a new binn allocating memory for the structure
binn * APIENTRY binn_new(int type, int size, void *buffer);
binn * APIENTRY binn_list();
binn * APIENTRY binn_map();
binn * APIENTRY binn_object();

// create a new binn storing the structure on the stack
BOOL APIENTRY binn_create(binn *item, int type, int size, void *buffer);
BOOL APIENTRY binn_create_list(binn *list);
BOOL APIENTRY binn_create_map(binn *map);
BOOL APIENTRY binn_create_object(binn *object);


BOOL APIENTRY binn_list_add_new(binn *list, binn *value);
BOOL APIENTRY binn_map_set_new(binn *map, int id, binn *value);
BOOL APIENTRY binn_object_set_new(binn *obj, char *key, binn *value);


// extended interface

BOOL   APIENTRY binn_list_add(binn *list, int type, void *pvalue, int size);
BOOL   APIENTRY binn_map_set(binn *map, int id, int type, void *pvalue, int size);
BOOL   APIENTRY binn_object_set(binn *obj, char *key, int type, void *pvalue, int size);


// release memory

void   APIENTRY binn_free(binn *item);
void * APIENTRY binn_release(binn *item); // free the binn structure but keeps the binn buffer allocated, returning a pointer to it. use the free function to release the buffer later


// --- CREATING VALUES ---------------------------------------------------

binn * APIENTRY binn_value(int type, void *pvalue, int size, binn_mem_free freefn);

ALWAYS_INLINE binn * binn_int8(signed char value) {
  return binn_value(BINN_INT8, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_int16(short value) {
  return binn_value(BINN_INT16, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_int32(int value) {
  return binn_value(BINN_INT32, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_int64(int64 value) {
  return binn_value(BINN_INT64, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_uint8(unsigned char value) {
  return binn_value(BINN_UINT8, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_uint16(unsigned short value) {
  return binn_value(BINN_UINT16, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_uint32(unsigned int value) {
  return binn_value(BINN_UINT32, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_uint64(uint64 value) {
  return binn_value(BINN_UINT64, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_float(float value) {
  return binn_value(BINN_FLOAT, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_double(double value) {
  return binn_value(BINN_DOUBLE, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_bool(BOOL value) {
  return binn_value(BINN_BOOL, &value, 0, NULL);
}
ALWAYS_INLINE binn * binn_null() {
  return binn_value(BINN_NULL, NULL, 0, NULL);
}
ALWAYS_INLINE binn * binn_string(char *str, binn_mem_free freefn) {
  return binn_value(BINN_STRING, str, 0, freefn);
}
ALWAYS_INLINE binn * binn_blob(void *ptr, int size, binn_mem_free freefn) {
  return binn_value(BINN_BLOB, ptr, size, freefn);
}


// --- READ FUNCTIONS  -------------------------------------------------------------

// these functions accept pointer to the binn structure and pointer to the binn buffer
void * APIENTRY binn_ptr(void *ptr);
int    APIENTRY binn_size(void *ptr);
int    APIENTRY binn_type(void *ptr);
int    APIENTRY binn_count(void *ptr);

BOOL   APIENTRY binn_is_valid(void *ptr, int *ptype, int *pcount, int *psize);
/* the function returns the values (type, count and size) and they don't need to be
   initialized. these values are read from the buffer. example:

   int type, count, size;
   result = binn_is_valid(ptr, &type, &count, &size);
*/
BOOL   APIENTRY binn_is_valid_ex(void *ptr, int *ptype, int *pcount, int *psize);
/* if some value is informed (type, count or size) then the function will check if 
   the value returned from the serialized data matches the informed value. otherwise
   the values must be initialized to zero. example:

   int type=0, count=0, size = known_size;
   result = binn_is_valid_ex(ptr, &type, &count, &size);
*/

BOOL   APIENTRY binn_is_struct(void *ptr);


// Loading a binn buffer into a binn value - this is optional

BOOL   APIENTRY binn_load(void *data, binn *item);  // on stack
binn * APIENTRY binn_open(void *data);              // allocated


// easiest interface to use, but don't check if the value is there

signed char    APIENTRY binn_list_int8(void *list, int pos);
short          APIENTRY binn_list_int16(void *list, int pos);
int            APIENTRY binn_list_int32(void *list, int pos);
int64          APIENTRY binn_list_int64(void *list, int pos);
unsigned char  APIENTRY binn_list_uint8(void *list, int pos);
unsigned short APIENTRY binn_list_uint16(void *list, int pos);
unsigned int   APIENTRY binn_list_uint32(void *list, int pos);
uint64         APIENTRY binn_list_uint64(void *list, int pos);
float          APIENTRY binn_list_float(void *list, int pos);
double         APIENTRY binn_list_double(void *list, int pos);
BOOL           APIENTRY binn_list_bool(void *list, int pos);
BOOL           APIENTRY binn_list_null(void *list, int pos);
char *         APIENTRY binn_list_str(void *list, int pos);
void *         APIENTRY binn_list_blob(void *list, int pos, int *psize);
void *         APIENTRY binn_list_list(void *list, int pos);
void *         APIENTRY binn_list_map(void *list, int pos);
void *         APIENTRY binn_list_object(void *list, int pos);

signed char    APIENTRY binn_map_int8(void *map, int id);
short          APIENTRY binn_map_int16(void *map, int id);
int            APIENTRY binn_map_int32(void *map, int id);
int64          APIENTRY binn_map_int64(void *map, int id);
unsigned char  APIENTRY binn_map_uint8(void *map, int id);
unsigned short APIENTRY binn_map_uint16(void *map, int id);
unsigned int   APIENTRY binn_map_uint32(void *map, int id);
uint64         APIENTRY binn_map_uint64(void *map, int id);
float          APIENTRY binn_map_float(void *map, int id);
double         APIENTRY binn_map_double(void *map, int id);
BOOL           APIENTRY binn_map_bool(void *map, int id);
BOOL           APIENTRY binn_map_null(void *map, int id);
char *         APIENTRY binn_map_str(void *map, int id);
void *         APIENTRY binn_map_blob(void *map, int id, int *psize);
void *         APIENTRY binn_map_list(void *map, int id);
void *         APIENTRY binn_map_map(void *map, int id);
void *         APIENTRY binn_map_object(void *map, int id);

signed char    APIENTRY binn_object_int8(void *obj, char *key);
short          APIENTRY binn_object_int16(void *obj, char *key);
int            APIENTRY binn_object_int32(void *obj, char *key);
int64          APIENTRY binn_object_int64(void *obj, char *key);
unsigned char  APIENTRY binn_object_uint8(void *obj, char *key);
unsigned short APIENTRY binn_object_uint16(void *obj, char *key);
unsigned int   APIENTRY binn_object_uint32(void *obj, char *key);
uint64         APIENTRY binn_object_uint64(void *obj, char *key);
float          APIENTRY binn_object_float(void *obj, char *key);
double         APIENTRY binn_object_double(void *obj, char *key);
BOOL           APIENTRY binn_object_bool(void *obj, char *key);
BOOL           APIENTRY binn_object_null(void *obj, char *key);
char *         APIENTRY binn_object_str(void *obj, char *key);
void *         APIENTRY binn_object_blob(void *obj, char *key, int *psize);
void *         APIENTRY binn_object_list(void *obj, char *key);
void *         APIENTRY binn_object_map(void *obj, char *key);
void *         APIENTRY binn_object_object(void *obj, char *key);


// return a pointer to an allocated binn structure - must be released with the free() function or equivalent set in binn_set_alloc_functions()
binn * APIENTRY binn_list_value(void *list, int pos);
binn * APIENTRY binn_map_value(void *map, int id);
binn * APIENTRY binn_object_value(void *obj, char *key);

// read the value to a binn structure on the stack
BOOL APIENTRY binn_list_get_value(void* list, int pos, binn *value);
BOOL APIENTRY binn_map_get_value(void* map, int id, binn *value);
BOOL APIENTRY binn_object_get_value(void *obj, char *key, binn *value);

// single interface - these functions check the data type
BOOL APIENTRY binn_list_get(void *list, int pos, int type, void *pvalue, int *psize);
BOOL APIENTRY binn_map_get(void *map, int id, int type, void *pvalue, int *psize);
BOOL APIENTRY binn_object_get(void *obj, char *key, int type, void *pvalue, int *psize);

// these 3 functions return a pointer to the value and the data type
// they are thread-safe on big-endian devices
// on little-endian devices they are thread-safe only to return pointers to list, map, object, blob and strings
// the returned pointer to 16, 32 and 64 bits values must be used only by single-threaded applications
void * APIENTRY binn_list_read(void *list, int pos, int *ptype, int *psize);
void * APIENTRY binn_map_read(void *map, int id, int *ptype, int *psize);
void * APIENTRY binn_object_read(void *obj, char *key, int *ptype, int *psize);


// READ PAIR FUNCTIONS

// these functions use base 1 in the 'pos' argument

// on stack
BOOL APIENTRY binn_map_get_pair(void *map, int pos, int *pid, binn *value);
BOOL APIENTRY binn_object_get_pair(void *obj, int pos, char *pkey, binn *value);  // must free the memory returned in the pkey

// allocated
binn * APIENTRY binn_map_pair(void *map, int pos, int *pid);
binn * APIENTRY binn_object_pair(void *obj, int pos, char *pkey);  // must free the memory returned in the pkey

// these 2 functions return a pointer to the value and the data type
// they are thread-safe on big-endian devices
// on little-endian devices they are thread-safe only to return pointers to list, map, object, blob and strings
// the returned pointer to 16, 32 and 64 bits values must be used only by single-threaded applications
void * APIENTRY binn_map_read_pair(void *ptr, int pos, int *pid, int *ptype, int *psize);
void * APIENTRY binn_object_read_pair(void *ptr, int pos, char *pkey, int *ptype, int *psize);


// SEQUENTIAL READ FUNCTIONS

typedef struct binn_iter_struct {
    unsigned char *pnext;
    unsigned char *plimit;
    int   type;
    int   count;
    int   current;
} binn_iter;

BOOL   APIENTRY binn_iter_init(binn_iter *iter, void *pbuf, int type);

// allocated
binn * APIENTRY binn_list_next_value(binn_iter *iter);
binn * APIENTRY binn_map_next_value(binn_iter *iter, int *pid);
binn * APIENTRY binn_object_next_value(binn_iter *iter, char *pkey);  // the key must be declared as: char key[256];

// on stack
BOOL   APIENTRY binn_list_next(binn_iter *iter, binn *value);
BOOL   APIENTRY binn_map_next(binn_iter *iter, int *pid, binn *value);
BOOL   APIENTRY binn_object_next(binn_iter *iter, char *pkey, binn *value);  // the key must be declared as: char key[256];

// these 3 functions return a pointer to the value and the data type
// they are thread-safe on big-endian devices
// on little-endian devices they are thread-safe only to return pointers to list, map, object, blob and strings
// the returned pointer to 16, 32 and 64 bits values must be used only by single-threaded applications
void * APIENTRY binn_list_read_next(binn_iter *iter, int *ptype, int *psize);
void * APIENTRY binn_map_read_next(binn_iter *iter, int *pid, int *ptype, int *psize);
void * APIENTRY binn_object_read_next(binn_iter *iter, char *pkey, int *ptype, int *psize);  // the key must be declared as: char key[256];


// --- MACROS ------------------------------------------------------------


#define binn_is_writable(item) (item)->writable;


// set values on stack allocated binn structures

#define binn_set_null(item)         do { (item)->type = BINN_NULL; } while (0)

#define binn_set_bool(item,value)   do { (item)->type = BINN_BOOL; (item)->vbool = value; (item)->ptr = &((item)->vbool); } while (0)

#define binn_set_int(item,value)    do { (item)->type = BINN_INT32; (item)->vint32 = value; (item)->ptr = &((item)->vint32); } while (0)
#define binn_set_int64(item,value)  do { (item)->type = BINN_INT64; (item)->vint64 = value; (item)->ptr = &((item)->vint64); } while (0)

#define binn_set_uint(item,value)   do { (item)->type = BINN_UINT32; (item)->vuint32 = value; (item)->ptr = &((item)->vuint32); } while (0)
#define binn_set_uint64(item,value) do { (item)->type = BINN_UINT64; (item)->vuint64 = value; (item)->ptr = &((item)->vuint64); } while (0)

#define binn_set_float(item,value)  do { (item)->type = BINN_FLOAT;  (item)->vfloat  = value; (item)->ptr = &((item)->vfloat); } while (0)
#define binn_set_double(item,value) do { (item)->type = BINN_DOUBLE; (item)->vdouble = value; (item)->ptr = &((item)->vdouble); } while (0)

//#define binn_set_string(item,str,pfree)    do { (item)->type = BINN_STRING; (item)->ptr = str; (item)->freefn = pfree; } while (0)
//#define binn_set_blob(item,ptr,size,pfree) do { (item)->type = BINN_BLOB;   (item)->ptr = ptr; (item)->freefn = pfree; (item)->size = size; } while (0)
BOOL APIENTRY binn_set_string(binn *item, char *str, binn_mem_free pfree);
BOOL APIENTRY binn_set_blob(binn *item, void *ptr, int size, binn_mem_free pfree);


//#define binn_double(value) {       (item)->type = BINN_DOUBLE; (item)->vdouble = value; (item)->ptr = &((item)->vdouble) }



// FOREACH MACROS
// must use these declarations in the function that will use them:
//  binn_iter iter;
//  char key[256];  // only for the object
//  int  id;        // only for the map
//  binn value;

#define binn_object_foreach(object, key, value)   \
    binn_iter_init(&iter, object, BINN_OBJECT);   \
    while (binn_object_next(&iter, key, &value))

#define binn_map_foreach(map, id, value)      \
    binn_iter_init(&iter, map, BINN_MAP);     \
    while (binn_map_next(&iter, &id, &value))

#define binn_list_foreach(list, value)      \
    binn_iter_init(&iter, list, BINN_LIST); \
    while (binn_list_next(&iter, &value))



/*************************************************************************************/
/*** SET FUNCTIONS *******************************************************************/
/*************************************************************************************/

ALWAYS_INLINE BOOL binn_list_add_int8(binn *list, signed char value) {
  return binn_list_add(list, BINN_INT8, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_int16(binn *list, short value) {
  return binn_list_add(list, BINN_INT16, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_int32(binn *list, int value) {
  return binn_list_add(list, BINN_INT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_int64(binn *list, int64 value) {
  return binn_list_add(list, BINN_INT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_uint8(binn *list, unsigned char value) {
  return binn_list_add(list, BINN_UINT8, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_uint16(binn *list, unsigned short value) {
  return binn_list_add(list, BINN_UINT16, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_uint32(binn *list, unsigned int value) {
  return binn_list_add(list, BINN_UINT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_uint64(binn *list, uint64 value) {
  return binn_list_add(list, BINN_UINT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_float(binn *list, float value) {
  return binn_list_add(list, BINN_FLOAT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_double(binn *list, double value) {
  return binn_list_add(list, BINN_FLOAT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_bool(binn *list, BOOL value) {
  return binn_list_add(list, BINN_BOOL, &value, 0);
}
ALWAYS_INLINE BOOL binn_list_add_null(binn *list) {
  return binn_list_add(list, BINN_NULL, NULL, 0);
}
ALWAYS_INLINE BOOL binn_list_add_str(binn *list, char *str) {
  return binn_list_add(list, BINN_STRING, str, 0);
}
ALWAYS_INLINE BOOL binn_list_add_blob(binn *list, void *ptr, int size) {
  return binn_list_add(list, BINN_BLOB, ptr, size);
}
ALWAYS_INLINE BOOL binn_list_add_list(binn *list, void *list2) {
  return binn_list_add(list, BINN_LIST, binn_ptr(list2), binn_size(list2));
}
ALWAYS_INLINE BOOL binn_list_add_map(binn *list, void *map) {
  return binn_list_add(list, BINN_MAP, binn_ptr(map), binn_size(map));
}
ALWAYS_INLINE BOOL binn_list_add_object(binn *list, void *obj) {
  return binn_list_add(list, BINN_OBJECT, binn_ptr(obj), binn_size(obj));
}
ALWAYS_INLINE BOOL binn_list_add_value(binn *list, binn *value) {
  return binn_list_add(list, value->type, binn_ptr(value), binn_size(value));
}

/*************************************************************************************/

ALWAYS_INLINE BOOL binn_map_set_int8(binn *map, int id, signed char value) {
  return binn_map_set(map, id, BINN_INT8, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_int16(binn *map, int id, short value) {
  return binn_map_set(map, id, BINN_INT16, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_int32(binn *map, int id, int value) {
  return binn_map_set(map, id, BINN_INT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_int64(binn *map, int id, int64 value) {
  return binn_map_set(map, id, BINN_INT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_uint8(binn *map, int id, unsigned char value) {
  return binn_map_set(map, id, BINN_UINT8, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_uint16(binn *map, int id, unsigned short value) {
  return binn_map_set(map, id, BINN_UINT16, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_uint32(binn *map, int id, unsigned int value) {
  return binn_map_set(map, id, BINN_UINT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_uint64(binn *map, int id, uint64 value) {
  return binn_map_set(map, id, BINN_UINT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_float(binn *map, int id, float value) {
  return binn_map_set(map, id, BINN_FLOAT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_double(binn *map, int id, double value) {
  return binn_map_set(map, id, BINN_FLOAT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_bool(binn *map, int id, BOOL value) {
  return binn_map_set(map, id, BINN_BOOL, &value, 0);
}
ALWAYS_INLINE BOOL binn_map_set_null(binn *map, int id) {
  return binn_map_set(map, id, BINN_NULL, NULL, 0);
}
ALWAYS_INLINE BOOL binn_map_set_str(binn *map, int id, char *str) {
  return binn_map_set(map, id, BINN_STRING, str, 0);
}
ALWAYS_INLINE BOOL binn_map_set_blob(binn *map, int id, void *ptr, int size) {
  return binn_map_set(map, id, BINN_BLOB, ptr, size);
}
ALWAYS_INLINE BOOL binn_map_set_list(binn *map, int id, void *list) {
  return binn_map_set(map, id, BINN_LIST, binn_ptr(list), binn_size(list));
}
ALWAYS_INLINE BOOL binn_map_set_map(binn *map, int id, void *map2) {
  return binn_map_set(map, id, BINN_MAP, binn_ptr(map2), binn_size(map2));
}
ALWAYS_INLINE BOOL binn_map_set_object(binn *map, int id, void *obj) {
  return binn_map_set(map, id, BINN_OBJECT, binn_ptr(obj), binn_size(obj));
}
ALWAYS_INLINE BOOL binn_map_set_value(binn *map, int id, binn *value) {
  return binn_map_set(map, id, value->type, binn_ptr(value), binn_size(value));
}

/*************************************************************************************/

ALWAYS_INLINE BOOL binn_object_set_int8(binn *obj, char *key, signed char value) {
  return binn_object_set(obj, key, BINN_INT8, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_int16(binn *obj, char *key, short value) {
  return binn_object_set(obj, key, BINN_INT16, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_int32(binn *obj, char *key, int value) {
  return binn_object_set(obj, key, BINN_INT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_int64(binn *obj, char *key, int64 value) {
  return binn_object_set(obj, key, BINN_INT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_uint8(binn *obj, char *key, unsigned char value) {
  return binn_object_set(obj, key, BINN_UINT8, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_uint16(binn *obj, char *key, unsigned short value) {
  return binn_object_set(obj, key, BINN_UINT16, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_uint32(binn *obj, char *key, unsigned int value) {
  return binn_object_set(obj, key, BINN_UINT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_uint64(binn *obj, char *key, uint64 value) {
  return binn_object_set(obj, key, BINN_UINT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_float(binn *obj, char *key, float value) {
  return binn_object_set(obj, key, BINN_FLOAT32, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_double(binn *obj, char *key, double value) {
  return binn_object_set(obj, key, BINN_FLOAT64, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_bool(binn *obj, char *key, BOOL value) {
  return binn_object_set(obj, key, BINN_BOOL, &value, 0);
}
ALWAYS_INLINE BOOL binn_object_set_null(binn *obj, char *key) {
  return binn_object_set(obj, key, BINN_NULL, NULL, 0);
}
ALWAYS_INLINE BOOL binn_object_set_str(binn *obj, char *key, char *str) {
  return binn_object_set(obj, key, BINN_STRING, str, 0);
}
ALWAYS_INLINE BOOL binn_object_set_blob(binn *obj, char *key, void *ptr, int size) {
  return binn_object_set(obj, key, BINN_BLOB, ptr, size);
}
ALWAYS_INLINE BOOL binn_object_set_list(binn *obj, char *key, void *list) {
  return binn_object_set(obj, key, BINN_LIST, binn_ptr(list), binn_size(list));
}
ALWAYS_INLINE BOOL binn_object_set_map(binn *obj, char *key, void *map) {
  return binn_object_set(obj, key, BINN_MAP, binn_ptr(map), binn_size(map));
}
ALWAYS_INLINE BOOL binn_object_set_object(binn *obj, char *key, void *obj2) {
  return binn_object_set(obj, key, BINN_OBJECT, binn_ptr(obj2), binn_size(obj2));
}
ALWAYS_INLINE BOOL binn_object_set_value(binn *obj, char *key, binn *value) {
  return binn_object_set(obj, key, value->type, binn_ptr(value), binn_size(value));
}

/*************************************************************************************/
/*** GET FUNCTIONS *******************************************************************/
/*************************************************************************************/

ALWAYS_INLINE BOOL binn_list_get_int8(void *list, int pos, signed char *pvalue) {
  return binn_list_get(list, pos, BINN_INT8, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_int16(void *list, int pos, short *pvalue) {
  return binn_list_get(list, pos, BINN_INT16, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_int32(void *list, int pos, int *pvalue) {
  return binn_list_get(list, pos, BINN_INT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_int64(void *list, int pos, int64 *pvalue) {
  return binn_list_get(list, pos, BINN_INT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_uint8(void *list, int pos, unsigned char *pvalue) {
  return binn_list_get(list, pos, BINN_UINT8, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_uint16(void *list, int pos, unsigned short *pvalue) {
  return binn_list_get(list, pos, BINN_UINT16, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_uint32(void *list, int pos, unsigned int *pvalue) {
  return binn_list_get(list, pos, BINN_UINT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_uint64(void *list, int pos, uint64 *pvalue) {
  return binn_list_get(list, pos, BINN_UINT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_float(void *list, int pos, float *pvalue) {
  return binn_list_get(list, pos, BINN_FLOAT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_double(void *list, int pos, double *pvalue) {
  return binn_list_get(list, pos, BINN_FLOAT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_bool(void *list, int pos, BOOL *pvalue) {
  return binn_list_get(list, pos, BINN_BOOL, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_str(void *list, int pos, char **pvalue) {
  return binn_list_get(list, pos, BINN_STRING, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_blob(void *list, int pos, void **pvalue, int *psize) {
  return binn_list_get(list, pos, BINN_BLOB, pvalue, psize);
}
ALWAYS_INLINE BOOL binn_list_get_list(void *list, int pos, void **pvalue) {
  return binn_list_get(list, pos, BINN_LIST, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_map(void *list, int pos, void **pvalue) {
  return binn_list_get(list, pos, BINN_MAP, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_list_get_object(void *list, int pos, void **pvalue) {
  return binn_list_get(list, pos, BINN_OBJECT, pvalue, NULL);
}

/***************************************************************************/

ALWAYS_INLINE BOOL binn_map_get_int8(void *map, int id, signed char *pvalue) {
  return binn_map_get(map, id, BINN_INT8, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_int16(void *map, int id, short *pvalue) {
  return binn_map_get(map, id, BINN_INT16, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_int32(void *map, int id, int *pvalue) {
  return binn_map_get(map, id, BINN_INT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_int64(void *map, int id, int64 *pvalue) {
  return binn_map_get(map, id, BINN_INT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_uint8(void *map, int id, unsigned char *pvalue) {
  return binn_map_get(map, id, BINN_UINT8, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_uint16(void *map, int id, unsigned short *pvalue) {
  return binn_map_get(map, id, BINN_UINT16, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_uint32(void *map, int id, unsigned int *pvalue) {
  return binn_map_get(map, id, BINN_UINT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_uint64(void *map, int id, uint64 *pvalue) {
  return binn_map_get(map, id, BINN_UINT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_float(void *map, int id, float *pvalue) {
  return binn_map_get(map, id, BINN_FLOAT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_double(void *map, int id, double *pvalue) {
  return binn_map_get(map, id, BINN_FLOAT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_bool(void *map, int id, BOOL *pvalue) {
  return binn_map_get(map, id, BINN_BOOL, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_str(void *map, int id, char **pvalue) {
  return binn_map_get(map, id, BINN_STRING, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_blob(void *map, int id, void **pvalue, int *psize) {
  return binn_map_get(map, id, BINN_BLOB, pvalue, psize);
}
ALWAYS_INLINE BOOL binn_map_get_list(void *map, int id, void **pvalue) {
  return binn_map_get(map, id, BINN_LIST, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_map(void *map, int id, void **pvalue) {
  return binn_map_get(map, id, BINN_MAP, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_map_get_object(void *map, int id, void **pvalue) {
  return binn_map_get(map, id, BINN_OBJECT, pvalue, NULL);
}

/***************************************************************************/

// usage:
//   if (binn_object_get_int32(obj, "key", &value) == FALSE) xxx;

ALWAYS_INLINE BOOL binn_object_get_int8(void *obj, char *key, signed char *pvalue) {
  return binn_object_get(obj, key, BINN_INT8, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_int16(void *obj, char *key, short *pvalue) {
  return binn_object_get(obj, key, BINN_INT16, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_int32(void *obj, char *key, int *pvalue) {
  return binn_object_get(obj, key, BINN_INT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_int64(void *obj, char *key, int64 *pvalue) {
  return binn_object_get(obj, key, BINN_INT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_uint8(void *obj, char *key, unsigned char *pvalue) {
  return binn_object_get(obj, key, BINN_UINT8, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_uint16(void *obj, char *key, unsigned short *pvalue) {
  return binn_object_get(obj, key, BINN_UINT16, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_uint32(void *obj, char *key, unsigned int *pvalue) {
  return binn_object_get(obj, key, BINN_UINT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_uint64(void *obj, char *key, uint64 *pvalue) {
  return binn_object_get(obj, key, BINN_UINT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_float(void *obj, char *key, float *pvalue) {
  return binn_object_get(obj, key, BINN_FLOAT32, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_double(void *obj, char *key, double *pvalue) {
  return binn_object_get(obj, key, BINN_FLOAT64, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_bool(void *obj, char *key, BOOL *pvalue) {
  return binn_object_get(obj, key, BINN_BOOL, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_str(void *obj, char *key, char **pvalue) {
  return binn_object_get(obj, key, BINN_STRING, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_blob(void *obj, char *key, void **pvalue, int *psize) {
  return binn_object_get(obj, key, BINN_BLOB, pvalue, psize);
}
ALWAYS_INLINE BOOL binn_object_get_list(void *obj, char *key, void **pvalue) {
  return binn_object_get(obj, key, BINN_LIST, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_map(void *obj, char *key, void **pvalue) {
  return binn_object_get(obj, key, BINN_MAP, pvalue, NULL);
}
ALWAYS_INLINE BOOL binn_object_get_object(void *obj, char *key, void **pvalue) {
  return binn_object_get(obj, key, BINN_OBJECT, pvalue, NULL);
}

/***************************************************************************/

BOOL   APIENTRY binn_get_int32(binn *value, int *pint);
BOOL   APIENTRY binn_get_int64(binn *value, int64 *pint);
BOOL   APIENTRY binn_get_double(binn *value, double *pfloat);
BOOL   APIENTRY binn_get_bool(binn *value, BOOL *pbool);
char * APIENTRY binn_get_str(binn *value);

// boolean string values:
// 1, true, yes, on
// 0, false, no, off

// boolean number values:
// !=0 [true]
// ==0 [false]


#ifdef __cplusplus
}
#endif

#endif //BINN_H
