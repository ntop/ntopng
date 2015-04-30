#ifdef WIN32
/*
 *
 * Cross-platform basename/dirname
 *
 * Copyright 2005 Syd Logan, All Rights Reserved
 *
 * This code is distributed without warranty. You are free to use this
 * code for any purpose, however, if this code is republished or
 * redistributed in its original form, as hardcopy or electronically,
 * then you must include this copyright notice along with the code.
 *
 */

// minor changes 2008 by Stefan Ludewig stefan.ludewig@exitgames.com for WIN32 version RRDtool

#if !defined(__PL_BASENAME_H__)
#define __PL_BASENAME_H__

/*
       path           dirname        basename
       "/usr/lib"     "/usr"         "lib"
       "/usr/"        "/"            "usr"
       "usr"          "."            "usr"
       "/"            "/"            "/"
       "."            "."            "."
       ".."           "."            ".."
*/

#if defined(__cplusplus)
extern "C" {
#endif

const char *PL_basename(const char *name);
const char *PL_dirname(const char *name);

#define basename(name) ((char*)PL_basename(name))
#define dirname(name) ((char*)PL_dirname(name))

#if defined(__cplusplus)
}
#endif

#endif
#endif // WIN32
