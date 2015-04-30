/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Takao Fujiwara, 2008
 *****************************************************************************
 * rrd_i18n.h   Common Header File
 *****************************************************************************/
#ifdef  __cplusplus
extern    "C" {
#endif


#ifndef _RRD_I18N_H
#define _RRD_I18N_H

#ifdef ENABLE_NLS
#  ifdef _LIBC
#    include <libintl.h>
#  else
#    include "gettext.h"
#    define _(String) gettext (String)
#  endif
#else
#  define _(String) (String)
#endif

#define N_(String) String

#endif

#ifdef  __cplusplus
}
#endif
