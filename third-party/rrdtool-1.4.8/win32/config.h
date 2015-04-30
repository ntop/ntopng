/* config.h.msvc.  Hand-tweaked config.h for MSVC compiler.  */
#ifndef CONFIG_H
#define CONFIG_H

#include <math.h>
#include <float.h>
#include <direct.h>
#include <ctype.h>
#include <stdlib.h>

/* realloc does not support NULL as argument */

#define HAVE_STRFTIME 1
#define HAVE_TIME_H 1
#define HAVE_LOCALE_H 1
#define HAVE_TZSET 1
#define HAVE_SETLOCALE 1
#define HAVE_MATH_H 1
#define HAVE_FLOAT_H 1
#define HAVE_MEMMOVE 1
#define HAVE_MALLOC_H 1
#define HAVE_MKTIME 1
#define HAVE_STRFTIME 1
#define HAVE_STRING_H 1
#define HAVE_STDLIB_H 1
#define HAVE_VSNPRINTF 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_RRD_GRAPH 1

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

#define NUMVERS 1.4050
#define PACKAGE_NAME "rrdtool"
#define PACKAGE_VERSION "1.4.5"
#define PACKAGE_STRING PACKAGE_NAME " " PACKAGE_VERSION

#ifndef WIN32
#define isinf(a) (_fpclass(a) == _FPCLASS_NINF || _fpclass(a) == _FPCLASS_PINF)
#define isnan _isnan
#endif
#define finite _finite
#define snprintf _snprintf
//#define vsnprintf _vsnprintf
//#define strftime strftime_

#define NO_NULL_REALLOC 1
#if NO_NULL_REALLOC
# define rrd_realloc(a,b) ( (a) == NULL ? malloc( (b) ) : realloc( (a) , (b) ))
#else
# define rrd_realloc(a,b) realloc((a), (b))
#endif

/* Vertical label angle: 90.0 (default) or 270.0 */
#define RRDGRAPH_YLEGEND_ANGLE 90.0

#define RRD_DEFAULT_FONT "Courier"

/* #define DEBUG 1 */

#ifndef WIN32
__inline int round(double a){int x = (a + 0.5); return x;}
#endif

#endif                          /* CONFIG_H */
