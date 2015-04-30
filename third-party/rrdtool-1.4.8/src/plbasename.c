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

#include <memory.h>
#include <stdlib.h>
#include "plbasename.h"
#include <string.h>
#if defined(TEST)
#include <stdio.h>
#endif

#if defined(__cplusplus)

extern "C" {

#endif

const char *
PL_basename(const char *name)
{
    const char *base;
    char *p;
    static char *tmp = NULL;
    int len; 

    if (tmp) {
        free(tmp);
        tmp = NULL;
    }

    if (!name || !strcmp(name, ""))
        return "";

    if (!strcmp(name, "/"))
        return "/";

    len = strlen(name);
    if (name[len - 1] == '/') {
        // ditch the trailing '/'
        p = tmp = (char*)malloc(len);
        strncpy(p, name, len - 1); 
    } else {
        p = (char *) name;
    }

    for (base = p; *p; p++) 
        if (*p == '/') 
            base = p + 1;
    
    return base;
}

const char *
PL_dirname(const char *name)
{
    static char *ret = NULL;
    int len;
    int size = 0;
    const char *p;

    if (ret) {
        free(ret);
        ret = NULL;
    }

    if (!name || !strcmp(name, "") || !strstr(name, "/"))
        return(".");

    if (!strcmp(name, "/"))
        return(name);

    // find the last slash in the string

    len = strlen(name);
    p = &name[len - 1];

    if (*p == '/') p--;  // skip the trailing /

    while (p != name && *p != '/') p--;

    size = p - name;
    if (size) {
        ret = (char*)malloc(size + 1);
        memcpy(ret, name, size);
        ret[size] = '\0';
    } else if (*p == '/')
        return "/";
    else
        return "";
    
    return (const char *) ret;
}

#if defined(__cplusplus)

}

#endif 

#if defined(TEST)

int
main(int argc, char *argv[])
{
/*     run the following tests:

       path           dirname        basename
       "/usr/lib"     "/usr"         "lib"
       "/usr/"        "/"            "usr"
       "usr"          "."            "usr"
       "/"            "/"            "/"
       "."            "."            "."
       ".."           "."            ".."
       NULL           "."            ""
       ""             "."            ""
       "./.."         "."            ".."

      These results can be verified by running the unix commands
      basename(1) and dirname(1). One tweek to the test strategy
      used here would be, on darwin and linux, to shell out to 
      get the expected results vs hardcoding. 
*/
    if (!strcmp(PL_basename("/usr/lib"), "lib"))
        printf("PL_basename /usr/lib passed\n");
    else
        printf("PL_basename /usr/lib failed expected lib\n");
    if (!strcmp(PL_dirname("/usr/lib"), "/usr"))
        printf("PL_dirname /usr/lib passed\n");
    else
        printf("PL_dirname /usr/lib failed expected /usr\n");
    if (!strcmp(PL_basename("/usr/"), "usr"))
        printf("PL_basename /usr/ passed\n");
    else
        printf("PL_basename /usr/ failed expected usr\n");
    if (!strcmp(PL_dirname("/usr/"), "/"))
        printf("PL_dirname /usr/ passed\n");
    else
        printf("PL_dirname /usr/ failed expected /\n");
    if (!strcmp(PL_basename("usr"), "usr"))
        printf("PL_basename usr passed\n");
    else
        printf("PL_basename usr failed expected usr\n");
    if (!strcmp(PL_dirname("usr"), "."))
        printf("PL_dirname usr passed\n");
    else
        printf("PL_dirname usr failed expected .\n");
    if (!strcmp(PL_basename("/"), "/"))
        printf("PL_basename / passed\n");
    else
        printf("PL_basename / failed expected /\n");
    if (!strcmp(PL_dirname("/"), "/"))
        printf("PL_dirname / passed\n");
    else
        printf("PL_dirname / failed expected /\n");
    if (!strcmp(PL_basename("."), "."))
        printf("PL_basename . passed\n");
    else
        printf("PL_basename . failed\n");
    if (!strcmp(PL_dirname("."), "."))
        printf("PL_dirname . passed\n");
    else
        printf("PL_dirname . failed expected .\n");
    if (!strcmp(PL_basename(".."), ".."))
        printf("PL_basename .. passed\n");
    else
        printf("PL_basename .. failed expected  ..\n");
    if (!strcmp(PL_dirname(".."), "."))
        printf("PL_dirname .. passed\n");
    else
        printf("PL_dirname .. failed expected .\n");
    if (!strcmp(PL_basename(NULL), ""))
        printf("PL_basename NULL passed\n");
    else
        printf("PL_basename NULL failed expected \"\"\n");
    if (!strcmp(PL_dirname(NULL), "."))
        printf("PL_dirname NULL passed\n");
    else
        printf("PL_dirname NULL failed expected .\n");
    if (!strcmp(PL_basename(""), ""))
        printf("PL_basename \"\" passed\n");
    else
        printf("PL_basename \"\" failed expected \"\"\n");
    if (!strcmp(PL_dirname(""), "."))
        printf("PL_dirname \"\" passed\n");
    else
        printf("PL_dirname \"\" failed expected .\n");

    if (!strcmp(PL_basename("./.."), ".."))
        printf("PL_basename ./.. passed\n");
    else
        printf("PL_basename ./.. failed expected ..\n");
    if (!strcmp(PL_dirname("./.."), "."))
        printf("PL_dirname ./.. passed\n");
    else
        printf("PL_dirname ./.. failed expected .\n");
}
#endif
#endif // WIN32
