/****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 ****************************************************************************
 * rrd_graph_helper.c  commandline parser functions 
 *                     this code initially written by Alex van den Bogaerdt
 ****************************************************************************/

#include "rrd_graph.h"

#define dprintf if (gdp->debug) printf

/* NOTE ON PARSING:
 *
 * we use the following:
 * 
 * i=0;  sscanf(&line[*eaten], "what to find%n", variables, &i)
 *
 * Usually you want to find a separator as well.  Example:
 * i=0; sscanf(&line[*eaten], "%li:%n", &someint, &i)
 *
 * When the separator is not found, i is not set and thus remains zero.
 * Another way would be to compare strlen() to i
 *
 * Why is this important?  Because 12345abc should not be matched as
 * integer 12345 ...
 */

/* NOTE ON VNAMES:
 *
 * "if ((gdp->vidx=find_var(im, l))!=-1)" is not good enough, at least
 * not by itself.
 *
 * A vname as a result of a VDEF is quite different from a vname
 * resulting of a DEF or CDEF.
 */

/* NOTE ON VNAMES:
 *
 * A vname called "123" is not to be parsed as the number 123
 */


/* Define prototypes for the parsing methods.
  Inputs:
   const char *const line    - a fixed pointer to a fixed string
   unsigned int *const eaten - a fixed pointer to a changing index in that line
   graph_desc_t *const gdp   - a fixed pointer to a changing graph description
   image_desc_t *const im    - a fixed pointer to a changing image description
*/

int       rrd_parse_find_gf(
    const char *const,
    unsigned int *const,
    graph_desc_t *const);

int       rrd_parse_legend(
    const char *const,
    unsigned int *const,
    graph_desc_t *const);

int       rrd_parse_color(
    const char *const,
    graph_desc_t *const);

int       rrd_parse_textalign(
    const char *const,
    unsigned int *const,
    graph_desc_t *const);


int       rrd_parse_CF(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    enum cf_en *const);

int       rrd_parse_print(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int       rrd_parse_shift(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int       rrd_parse_xport(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int       rrd_parse_PVHLAST(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int       rrd_parse_make_vname(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int       rrd_parse_find_vname(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int       rrd_parse_def(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int       rrd_parse_vdef(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int       rrd_parse_cdef(
    const char *const,
    unsigned int *const,
    graph_desc_t *const,
    image_desc_t *const);

int rrd_parse_find_gf(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp)
{
    char      funcname[11], c1 = 0;
    int       i = 0;

    /* start an argument with DEBUG to be able to see how it is parsed */
    sscanf(&line[*eaten], "DEBUG%n", &i);
    if (i) {
        gdp->debug = 1;
        (*eaten) += i;
        i = 0;
        dprintf("Scanning line '%s'\n", &line[*eaten]);
    }
    i = 0;
    c1 = '\0';
    sscanf(&line[*eaten], "%10[A-Z]%n%c", funcname, &i, &c1);
    if (!i) {
        rrd_set_error("Could not make sense out of '%s'", line);
        return 1;
    }
    (*eaten) += i;
    if ((int) (gdp->gf = gf_conv(funcname)) == -1) {
        rrd_set_error("'%s' is not a valid function name", funcname);
        return 1;
    } else {
        dprintf("- found function name '%s'\n", funcname);
    }

    if (c1 == '\0') {
        rrd_set_error("Function %s needs parameters.  Line: %s\n", funcname,
                      line);
        return 1;
    }
    if (c1 == ':')
        (*eaten)++;

    /* Some commands have a parameter before the colon
     * (currently only LINE)
     */
    switch (gdp->gf) {
    case GF_LINE:
        if (c1 == ':') {
            gdp->linewidth = 1;
            dprintf("- using default width of 1\n");
        } else {
            i = 0;
            sscanf(&line[*eaten], "%lf:%n", &gdp->linewidth, &i);
            if (!i) {
                rrd_set_error("Cannot parse line width '%s' in line '%s'\n",
                              &line[*eaten], line);
                return 1;
            } else {
                dprintf("- scanned width %f\n", gdp->linewidth);
                if (isnan(gdp->linewidth)) {
                    rrd_set_error
                        ("LINE width '%s' is not a number in line '%s'\n",
                         &line[*eaten], line);
                    return 1;
                }
                if (isinf(gdp->linewidth)) {
                    rrd_set_error
                        ("LINE width '%s' is out of range in line '%s'\n",
                         &line[*eaten], line);
                    return 1;
                }
                if (gdp->linewidth < 0) {
                    rrd_set_error
                        ("LINE width '%s' is less than 0 in line '%s'\n",
                         &line[*eaten], line);
                    return 1;
                }
            }
            (*eaten) += i;
        }
        break;
    default:
        if (c1 == ':')
            break;
        rrd_set_error("Malformed '%s' command in line '%s'\n", &line[*eaten],
                      line);
        return 1;
    }
    if (line[*eaten] == '\0') {
        rrd_set_error("Expected some arguments after '%s'\n", line);
        return 1;
    }
    return 0;
}

int rrd_parse_legend(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp)
{
    int       i;

    if (line[*eaten] == '\0' || line[*eaten] == ':') {
        dprintf("- no (or: empty) legend found\n");
        return 0;
    }

    i = scan_for_col(&line[*eaten], FMT_LEG_LEN, gdp->legend);

    (*eaten) += i;

    if (line[*eaten] != '\0' && line[*eaten] != ':') {
        rrd_set_error("Legend too long");
        return 1;
    } else {
        return 0;
    }
}

int rrd_parse_color(
    const char *const string,
    graph_desc_t *const gdp)
{
    unsigned int r = 0, g = 0, b = 0, a = 0, i;

    /* matches the following formats:
     ** RGB
     ** RGBA
     ** RRGGBB
     ** RRGGBBAA
     */

    i = 0;
    while (string[i] && isxdigit((unsigned int) string[i]))
        i++;
    if (string[i] != '\0')
        return 1;       /* garbage follows hexdigits */
    switch (i) {
    case 3:
    case 4:
        sscanf(string, "%1x%1x%1x%1x", &r, &g, &b, &a);
        r *= 0x11;
        g *= 0x11;
        b *= 0x11;
        a *= 0x11;
        if (i == 3)
            a = 0xFF;
        break;
    case 6:
    case 8:
        sscanf(string, "%02x%02x%02x%02x", &r, &g, &b, &a);
        if (i == 6)
            a = 0xFF;
        break;
    default:
        return 1;       /* wrong number of digits */
    }
    gdp->col = gfx_hex_to_col(r << 24 | g << 16 | b << 8 | a);
    return 0;
}

int rrd_parse_CF(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    enum cf_en *cf)
{
    char      symname[CF_NAM_SIZE];
    int       i = 0;

    sscanf(&line[*eaten], CF_NAM_FMT "%n", symname, &i);
    if ((!i) || ((line[(*eaten) + i] != '\0') && (line[(*eaten) + i] != ':'))) {
        rrd_set_error("Cannot parse CF in '%s'", line);
        return 1;
    }
    (*eaten) += i;
    dprintf("- using CF '%s'\n", symname);

    if ((int) (*cf = cf_conv(symname)) == -1) {
        rrd_set_error("Unknown CF '%s' in '%s'", symname, line);
        return 1;
    }

    if (line[*eaten] != '\0')
        (*eaten)++;
    return 0;
}

/* Try to match next token as a vname.
 *
 * Returns:
 * -1     an error occured and the error string is set
 * other  the vname index number
 *
 * *eaten is incremented only when a vname is found.
 */
int rrd_parse_find_vname(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    char      tmpstr[MAX_VNAME_LEN + 1];
    int       i;
    long      vidx;

    i = 0;
    sscanf(&line[*eaten], DEF_NAM_FMT "%n", tmpstr, &i);
    if (!i) {
        rrd_set_error("Could not parse line '%s'", line);
        return -1;
    }
    if (line[*eaten + i] != ':' && line[*eaten + i] != '\0') {
        rrd_set_error("Could not parse line '%s'", line);
        return -1;
    }
    dprintf("- Considering '%s'\n", tmpstr);

    if ((vidx = find_var(im, tmpstr)) < 0) {
        dprintf("- Not a vname\n");
        rrd_set_error("Not a valid vname: %s in line %s", tmpstr, line);
        return -1;
    }
    dprintf("- Found vname '%s' vidx '%li'\n", tmpstr, gdp->vidx);
    if (line[*eaten + i] == ':')
        i++;
    (*eaten) += i;
    return vidx;
}

/* Parsing old-style xPRINT and new-style xPRINT */
int rrd_parse_print(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    /* vname:CF:format in case of DEF-based vname
     ** vname:CF:format in case of CDEF-based vname
     ** vname:format[:strftime] in case of VDEF-based vname
     */
    if ((gdp->vidx = rrd_parse_find_vname(line, eaten, gdp, im)) < 0)
        return 1;

    switch (im->gdes[gdp->vidx].gf) {
    case GF_DEF:
    case GF_CDEF:
        dprintf("- vname is of type DEF or CDEF, looking for CF\n");
        if (rrd_parse_CF(line, eaten, gdp, &gdp->cf))
            return 1;
        break;
    case GF_VDEF:
        dprintf("- vname is of type VDEF\n");
        break;
    default:
        rrd_set_error("Encountered unknown type variable '%s'",
                      im->gdes[gdp->vidx].vname);
        return 1;
    }

    if (rrd_parse_legend(line, eaten, gdp))
        return 1;
    /* for *PRINT the legend itself gets rendered later. We only
       get the format at this juncture */
    strcpy(gdp->format, gdp->legend);
    gdp->legend[0] = '\0';
    /* this is a very crud test, parsing :style flags should be in a function */
    if (im->gdes[gdp->vidx].gf == GF_VDEF
        && strcmp(line + (*eaten), ":strftime") == 0) {
        gdp->strftm = 1;
        (*eaten) += strlen(":strftime");
    }
    return 0;
}

/* SHIFT:_def_or_cdef:_vdef_or_number_
 */
int rrd_parse_shift(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    int       i;

    if ((gdp->vidx = rrd_parse_find_vname(line, eaten, gdp, im)) < 0)
        return 1;

    switch (im->gdes[gdp->vidx].gf) {
    case GF_DEF:
    case GF_CDEF:
        dprintf("- vname is of type DEF or CDEF, OK\n");
        break;
    case GF_VDEF:
        rrd_set_error("Cannot shift a VDEF: '%s' in line '%s'\n",
                      im->gdes[gdp->vidx].vname, line);
        return 1;
    default:
        rrd_set_error("Encountered unknown type variable '%s' in line '%s'",
                      im->gdes[gdp->vidx].vname, line);
        return 1;
    }

    if ((gdp->shidx = rrd_parse_find_vname(line, eaten, gdp, im)) >= 0) {
        switch (im->gdes[gdp->shidx].gf) {
        case GF_DEF:
        case GF_CDEF:
            rrd_set_error("Offset cannot be a (C)DEF: '%s' in line '%s'\n",
                          im->gdes[gdp->shidx].vname, line);
            return 1;
        case GF_VDEF:
            dprintf("- vname is of type VDEF, OK\n");
            break;
        default:
            rrd_set_error
                ("Encountered unknown type variable '%s' in line '%s'",
                 im->gdes[gdp->vidx].vname, line);
            return 1;
        }
    } else {
        long      time_tmp = 0;

        rrd_clear_error();
        i = 0;
        sscanf(&line[*eaten], "%li%n", &time_tmp, &i);
        gdp->shval = time_tmp;
        if (i != (int) strlen(&line[*eaten])) {
            rrd_set_error("Not a valid offset: %s in line %s", &line[*eaten],
                          line);
            return 1;
        }
        (*eaten) += i;
        dprintf("- offset is number %li\n", gdp->shval);
        gdp->shidx = -1;
    }
    return 0;
}

/* XPORT:_def_or_cdef[:legend]
 */
int rrd_parse_xport(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    if ((gdp->vidx = rrd_parse_find_vname(line, eaten, gdp, im)) < 0)
        return 1;

    switch (im->gdes[gdp->vidx].gf) {
    case GF_DEF:
    case GF_CDEF:
        dprintf("- vname is of type DEF or CDEF, OK\n");
        break;
    case GF_VDEF:
        rrd_set_error("Cannot xport a VDEF: '%s' in line '%s'\n",
                      im->gdes[gdp->vidx].vname, line);
        return 1;
    default:
        rrd_set_error("Encountered unknown type variable '%s' in line '%s'",
                      im->gdes[gdp->vidx].vname, line);
        return 1;
    }
    dprintf("- looking for legend in '%s'\n", &line[*eaten]);
    if (rrd_parse_legend(line, eaten, gdp))
        return 1;
    return 0;
}

int rrd_parse_textalign(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp)
{
    if (strcmp(&line[*eaten], "left") == 0) {
        gdp->txtalign = TXA_LEFT;
    } else if (strcmp(&line[*eaten], "right") == 0) {
        gdp->txtalign = TXA_RIGHT;
    } else if (strcmp(&line[*eaten], "justified") == 0) {
        gdp->txtalign = TXA_JUSTIFIED;
    } else if (strcmp(&line[*eaten], "center") == 0) {
        gdp->txtalign = TXA_CENTER;
    } else {
        rrd_set_error("Unknown alignement type '%s'", &line[*eaten]);
        return 1;
    }
    *eaten += strlen(&line[*eaten]);
    return 0;
}


/* Parsing of VRULE, HRULE, LINE, AREA, STACK and TICK
** is done in one function.
**
** Stacking VRULE, HRULE or TICK is not allowed.
**
** If a number (which is valid to enter) is more than a
** certain amount of characters, it is caught as an error.
** While this is arguable, so is entering fixed numbers
** with more than MAX_VNAME_LEN significant digits.
*/
int rrd_parse_PVHLAST(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    int       i, j, k;
    int       colorfound = 0;
    char      tmpstr[MAX_VNAME_LEN + 10];   /* vname#RRGGBBAA\0 */
    static int spacecnt = 0;

    if (spacecnt == 0) {
        float     one_space = gfx_get_text_width(im, 0,
                                                 im->
                                                 text_prop[TEXT_PROP_LEGEND].
                                                 font_desc,
                                                 im->tabwidth, "    ") / 4.0;
        float     target_space = gfx_get_text_width(im, 0,
                                                    im->
                                                    text_prop
                                                    [TEXT_PROP_LEGEND].font_desc,
                                                    im->tabwidth, "oo");

        spacecnt = target_space / one_space;
        dprintf("- spacecnt: %i onespace: %f targspace: %f\n", spacecnt,
                one_space, target_space);
    }


    dprintf("- parsing '%s'\n", &line[*eaten]);

    /* have simpler code in the drawing section */
    if (gdp->gf == GF_STACK) {
        gdp->stack = 1;
    }

    i = scan_for_col(&line[*eaten], MAX_VNAME_LEN + 9, tmpstr);
    if (line[*eaten + i] != '\0' && line[*eaten + i] != ':') {
        rrd_set_error("Cannot parse line '%s'", line);
        return 1;
    }

    j = i;
    while (j > 0 && tmpstr[j] != '#')
        j--;

    if (j) {
        tmpstr[j] = '\0';
    }
    /* We now have:
     * tmpstr[0]    containing vname
     * tmpstr[j]    if j!=0 then containing color
     * i            size of vname + color
     * j            if j!=0 then size of vname
     */

    /* Number or vname ?
     * If it is an existing vname, that's OK, provided that it is a
     * valid type (need time for VRULE, not a float)
     * Else see if it parses as a number.
     */
    dprintf("- examining string '%s'\n", tmpstr);
    if ((gdp->vidx = find_var(im, tmpstr)) >= 0) {
        dprintf("- found vname: '%s' vidx %li\n", tmpstr, gdp->vidx);
        switch (gdp->gf) {
        case GF_VRULE:
        case GF_HRULE:
            if (im->gdes[gdp->vidx].gf != GF_VDEF) {
                rrd_set_error("Using vname %s of wrong type in line %s\n",
                              im->gdes[gdp->gf].vname, line);
                return 1;
            }
            break;
        default:;
        }
    } else {
        long      time_tmp = 0;

        dprintf("- it is not an existing vname\n");
        switch (gdp->gf) {
        case GF_VRULE:
            k = 0;
            sscanf(tmpstr, "%li%n", &time_tmp, &k);
            gdp->xrule = time_tmp;
            if (((j != 0) && (k == j)) || ((j == 0) && (k == i))) {
                dprintf("- found time: %li\n", gdp->xrule);
            } else {
                dprintf("- is is not a valid number: %li\n", gdp->xrule);
                rrd_set_error
                    ("parameter '%s' does not represent time in line %s\n",
                     tmpstr, line);
                return 1;
            }
        default:
            k = 0;
            sscanf(tmpstr, "%lf%n", &gdp->yrule, &k);
            if (((j != 0) && (k == j)) || ((j == 0) && (k == i))) {
                dprintf("- found number: %lf\n", gdp->yrule);
            } else {
                dprintf("- is is not a valid number: %lf\n", gdp->yrule);
                rrd_set_error
                    ("parameter '%s' does not represent a number in line %s\n",
                     tmpstr, line);
                return 1;
            }
        }
    }

    if (j) {
        j++;
        dprintf("- examining color '%s'\n", &tmpstr[j]);
        if (rrd_parse_color(&tmpstr[j], gdp)) {
            rrd_set_error("Could not parse color in '%s'", &tmpstr[j]);
            return 1;
        }
        dprintf("- parsed color %0.0f,%0.0f,%0.0f,%0.0f\n", gdp->col.red,
                gdp->col.green, gdp->col.blue, gdp->col.alpha);
        colorfound = 1;
    } else {
        dprintf("- no color present in '%s'\n", tmpstr);
    }

    (*eaten) += i;      /* after vname#color */
    if (line[*eaten] != '\0') {
        (*eaten)++;     /* after colon */
    }

    if (gdp->gf == GF_TICK) {
        dprintf("- parsing '%s'\n", &line[*eaten]);
        dprintf("- looking for optional TICK number\n");
        j = 0;
        sscanf(&line[*eaten], "%lf%n", &gdp->yrule, &j);
        if (j) {
            if (line[*eaten + j] != '\0' && line[*eaten + j] != ':') {
                rrd_set_error("Cannot parse TICK fraction '%s'", line);
                return 1;
            }
            dprintf("- found number %f\n", gdp->yrule);
            if (gdp->yrule > 1.0 || gdp->yrule < -1.0) {
                rrd_set_error("Tick factor should be <= 1.0");
                return 1;
            }
            (*eaten) += j;
        } else {
            dprintf("- not found, defaulting to 0.1\n");
            gdp->yrule = 0.1;
        }
        if (line[*eaten] == '\0') {
            dprintf("- done parsing line\n");
            return 0;
        } else {
            if (line[*eaten] == ':') {
                (*eaten)++;
            } else {
                rrd_set_error("Can't make sense of that TICK line");
                return 1;
            }
        }
    }

    dprintf("- parsing '%s'\n", &line[*eaten]);

    /* Legend is next.  A legend without a color is an error.
     ** Stacking an item without having a legend is OK however
     ** then an empty legend should be specified.
     **   LINE:val#color:STACK  means legend is string "STACK"
     **   LINE:val#color::STACK means no legend, and do STACK
     **   LINE:val:STACK        is an error (legend but no color)
     **   LINE:val::STACK   means no legend, and do STACK
     */
    if (colorfound) {
        int       err = 0;
        char     *linecp = strdup(line);

        dprintf("- looking for optional legend\n");

        dprintf("- examining '%s'\n", &line[*eaten]);
        if (linecp[*eaten] != '\0' && linecp[*eaten] != ':') {
            int       spi;

            /* If the legend is not empty, it has to be prefixed with spacecnt ' ' characters. This then gets
             * replaced by the color box later on. */
            for (spi = 0; spi < spacecnt && (*eaten) > 1; spi++) {
                linecp[--(*eaten)] = ' ';
            }
        }

        if (rrd_parse_legend(linecp, eaten, gdp))
            err = 1;
        free(linecp);
        if (err)
            return 1;

        dprintf("- found legend '%s'\n", &gdp->legend[2]);
    } else {
        dprintf("- skipping empty legend\n");
        if (line[*eaten] != '\0' && line[*eaten] != ':') {
            rrd_set_error("Legend set but no color: %s", &line[*eaten]);
            return 1;
        }
    }
    if (line[*eaten] == '\0') {
        dprintf("- done parsing line\n");
        return 0;
    }
    (*eaten)++;         /* after colon */

    /* HRULE, VRULE and TICK cannot be stacked. */
    if ((gdp->gf != GF_HRULE)
        && (gdp->gf != GF_VRULE)
        && (gdp->gf != GF_TICK)) {

        dprintf("- parsing '%s', looking for STACK\n", &line[*eaten]);
        j = scan_for_col(&line[*eaten], 5, tmpstr);
        if (!strcmp("STACK", tmpstr)) {
            dprintf("- found STACK\n");
            gdp->stack = 1;
            (*eaten) += j;
            if (line[*eaten] == ':') {
                (*eaten) += 1;
            } else if (line[*eaten] == '\0') {
                dprintf("- done parsing line\n");
                return 0;
            } else {
                dprintf("- found %s instead of just STACK\n", &line[*eaten]);
                rrd_set_error("STACK expected but %s found", &line[*eaten]);
                return 1;
            }
        } else
            dprintf("- not STACKing\n");
    }

    dprintf("- parsing '%s', looking for skipscale\n", &line[*eaten]);
    j = scan_for_col(&line[*eaten], 9, tmpstr);
    if (!strcmp("skipscale", tmpstr)) {
        dprintf("- found skipscale\n");
        gdp->skipscale = 1;
        (*eaten) += j;
        if (line[*eaten] == ':') {
            (*eaten) += 1;
        } else if (line[*eaten] == '\0') {
            dprintf("- done parsing line\n");
            return 0;
        } else {
            dprintf("- found %s instead of just skipscale\n", &line[*eaten]);
            rrd_set_error("skipscale expected but %s found", &line[*eaten]);
            return 1;
        }
    }

    dprintf("- still more, should be dashes[=...]\n");
    dprintf("- parsing '%s'\n", &line[*eaten]);
    if (line[*eaten] != '\0') {
        /* parse dash arguments here. Possible options:
           - dashes
           - dashes=n_on[,n_off[,n_on,n_off]]
           - dashes[=n_on[,n_off[,n_on,n_off]]]:dash-offset=offset
           allowing 64 characters for definition of dash style */
        j = scan_for_col(&line[*eaten], 64, tmpstr);
        /* start with dashes */
        if (strcmp(tmpstr, "dashes") == 0) {
            /* if line was "dashes" or "dashes:dash-offset=xdashes="
               tmpstr will be "dashes" */
            dprintf("- found %s\n", tmpstr);
            /* initialise all required variables we need for dashed lines
               using default dash length of 5 pixels */
            gdp->dash = 1;
            gdp->p_dashes = (double *) malloc(sizeof(double));
            gdp->p_dashes[0] = 5;
            gdp->ndash = 1;
            gdp->offset = 0;
            (*eaten) += j;
        } else if (sscanf(tmpstr, "dashes=%s", tmpstr)) {
            /* dashes=n_on[,n_off[,n_on,n_off]] */
            char      csv[64];
            char     *pch;
            float     dsh;
            int       count = 0;
            char     *saveptr;

            strcpy(csv, tmpstr);

            pch = strtok_r(tmpstr, ",", &saveptr);
            while (pch != NULL) {
                pch = strtok_r(NULL, ",", &saveptr);
                count++;
            }
            dprintf("- %d dash value(s) found: ", count);
            if (count > 0) {
                gdp->dash = 1;
                gdp->ndash = count;
                gdp->p_dashes = (double *) malloc(sizeof(double) * count);
                pch = strtok_r(csv, ",", &saveptr);
                count = 0;
                while (pch != NULL) {
                    if (sscanf(pch, "%f", &dsh)) {
                        gdp->p_dashes[count] = (double) dsh;
                        dprintf("%.1f ", gdp->p_dashes[count]);
                        count++;
                    }
                    pch = strtok_r(NULL, ",", &saveptr);
                }
                dprintf("\n");
            } else
                dprintf("- syntax error. No dash lengths found!\n");
            (*eaten) += j;
        } else
            dprintf("- error: expected dashes[=...], found %s\n", tmpstr);
        if (line[*eaten] == ':') {
            (*eaten) += 1;
        } else if (line[*eaten] == '\0') {
            dprintf("- done parsing line\n");
            return 0;
        }
        /* dashes[=n_on[,n_off[,n_on,n_off]]]:dash-offset=offset
           allowing 16 characters for dash-offset=....
           => 4 characters for the offset value */
        j = scan_for_col(&line[*eaten], 16, tmpstr);
        if (sscanf(tmpstr, "dash-offset=%lf", &gdp->offset)) {
            dprintf("- found dash-offset=%.1f\n", gdp->offset);
            gdp->dash = 1;
            (*eaten) += j;
            if (line[*eaten] == ':')
                (*eaten) += 1;
        }
        if (line[*eaten] == '\0') {
            dprintf("- done parsing line\n");
            return 0;
        }
    }
    if (line[*eaten] == '\0') {
        dprintf("- done parsing line\n");
        return 0;
    }
    (*eaten)++;
    dprintf("- parsing '%s'\n", &line[*eaten]);

    return 0;
}

int rrd_parse_make_vname(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    char      tmpstr[MAX_VNAME_LEN + 10];
    int       i = 0;

    sscanf(&line[*eaten], DEF_NAM_FMT "=%n", tmpstr, &i);
    if (!i) {
        rrd_set_error("Cannot parse vname from '%s'", line);
        return 1;
    }
    if (line[*eaten+i] == '\0') {
        rrd_set_error("String ends after the = sign on '%s'", line);
        return 1;
    }
    dprintf("- found candidate '%s'\n", tmpstr);

    if ((gdp->vidx = find_var(im, tmpstr)) >= 0) {
        rrd_set_error("Attempting to reuse '%s'", im->gdes[gdp->vidx].vname);
        return 1;
    }
    strcpy(gdp->vname, tmpstr);
    dprintf("- created vname '%s' vidx %lu\n", gdp->vname, im->gdes_c - 1);
    (*eaten) += i;
    return 0;
}

int rrd_parse_def(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    int       i = 0;
    char      command[7];   /* step, start, end, reduce */
    char      tmpstr[256];
    rrd_time_value_t start_tv, end_tv;
    time_t    start_tmp = 0, end_tmp = 0;
    char     *parsetime_error = NULL;

    start_tv.type = end_tv.type = ABSOLUTE_TIME;
    start_tv.offset = end_tv.offset = 0;
    localtime_r(&gdp->start, &start_tv.tm);
    localtime_r(&gdp->end, &end_tv.tm);

    dprintf("- parsing '%s'\n", &line[*eaten]);
    dprintf("- from line '%s'\n", line);

    if (rrd_parse_make_vname(line, eaten, gdp, im))
        return 1;
    i = scan_for_col(&line[*eaten], sizeof(gdp->rrd) - 1, gdp->rrd);
    if (line[*eaten + i] != ':') {
        rrd_set_error("Problems reading database name");
        return 1;
    }
    (*eaten) += ++i;
    dprintf("- using file '%s'\n", gdp->rrd);

    i = 0;
    sscanf(&line[*eaten], DS_NAM_FMT ":%n", gdp->ds_nam, &i);
    if (!i) {
        rrd_set_error("Cannot parse DS in '%s'", line);
        return 1;
    }
    (*eaten) += i;
    dprintf("- using DS '%s'\n", gdp->ds_nam);

    if (rrd_parse_CF(line, eaten, gdp, &gdp->cf))
        return 1;
    gdp->cf_reduce = gdp->cf;

    if (line[*eaten] == '\0')
        return 0;

    while (1) {
        dprintf("- optional parameter follows: %s\n", &line[*eaten]);
        i = 0;
        sscanf(&line[*eaten], "%6[a-z]=%n", command, &i);
        if (!i) {
            rrd_set_error("Parse error in '%s'", line);
            return 1;
        }
        (*eaten) += i;
        dprintf("- processing '%s'\n", command);
        if (!strcmp("reduce", command)) {
            if (rrd_parse_CF(line, eaten, gdp, &gdp->cf_reduce))
                return 1;
            if (line[*eaten] != '\0')
                (*eaten)--;
        } else if (!strcmp("step", command)) {
            i = 0;
            sscanf(&line[*eaten], "%lu%n", &gdp->step, &i);
            gdp->step_orig = gdp->step;
            (*eaten) += i;
            dprintf("- using step %lu\n", gdp->step);
        } else if (!strcmp("start", command)) {
            i = scan_for_col(&line[*eaten], 255, tmpstr);
            (*eaten) += i;
            if ((parsetime_error = rrd_parsetime(tmpstr, &start_tv))) {
                rrd_set_error("start time: %s", parsetime_error);
                return 1;
            }
            dprintf("- done parsing:  '%s'\n", &line[*eaten]);
        } else if (!strcmp("end", command)) {
            i = scan_for_col(&line[*eaten], 255, tmpstr);
            (*eaten) += i;
            if ((parsetime_error = rrd_parsetime(tmpstr, &end_tv))) {
                rrd_set_error("end time: %s", parsetime_error);
                return 1;
            }
            dprintf("- done parsing:  '%s'\n", &line[*eaten]);
        } else {
            rrd_set_error("Parse error in '%s'", line);
            return 1;
        }
        if (line[*eaten] == '\0')
            break;
        if (line[*eaten] != ':') {
            dprintf("- Expected to see end of string but got '%s'\n",
                    &line[*eaten]);
            rrd_set_error("Parse error in '%s'", line);
            return 1;
        }
        (*eaten)++;
    }
    if (rrd_proc_start_end(&start_tv, &end_tv, &start_tmp, &end_tmp) == -1) {
        /* error string is set in rrd_parsetime.c */
        return 1;
    }
    if (start_tmp < 3600 * 24 * 365 * 10) {
        rrd_set_error("the first entry to fetch should be "
                      "after 1980 (%ld)", start_tmp);
        return 1;
    }

    if (end_tmp < start_tmp) {
        rrd_set_error("start (%ld) should be less than end (%ld)",
                      start_tmp, end_tmp);
        return 1;
    }

    gdp->start = start_tmp;
    gdp->end = end_tmp;
    gdp->start_orig = start_tmp;
    gdp->end_orig = end_tmp;

    dprintf("- start time %lu\n", gdp->start);
    dprintf("- end   time %lu\n", gdp->end);

    return 0;
}

int rrd_parse_vdef(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    char      tmpstr[MAX_VNAME_LEN + 1];    /* vname\0 */
    int       i = 0;

    dprintf("- parsing '%s'\n", &line[*eaten]);
    if (rrd_parse_make_vname(line, eaten, gdp, im))
        return 1;

    sscanf(&line[*eaten], DEF_NAM_FMT ",%n", tmpstr, &i);
    if (!i) {
        rrd_set_error("Cannot parse line '%s'", line);
        return 1;
    }
    if ((gdp->vidx = find_var(im, tmpstr)) < 0) {
        rrd_set_error("Not a valid vname: %s in line %s", tmpstr, line);
        return 1;
    }
    if (im->gdes[gdp->vidx].gf != GF_DEF && im->gdes[gdp->vidx].gf != GF_CDEF) {
        rrd_set_error("variable '%s' not DEF nor "
                      "CDEF in VDEF '%s'", tmpstr, gdp->vname);
        return 1;
    }
    dprintf("- found vname: '%s' vidx %li\n", tmpstr, gdp->vidx);
    (*eaten) += i;

    dprintf("- calling vdef_parse with param '%s'\n", &line[*eaten]);
    vdef_parse(gdp, &line[*eaten]);
    while (line[*eaten] != '\0' && line[*eaten] != ':')
        (*eaten)++;

    return 0;
}

int rrd_parse_cdef(
    const char *const line,
    unsigned int *const eaten,
    graph_desc_t *const gdp,
    image_desc_t *const im)
{
    dprintf("- parsing '%s'\n", &line[*eaten]);
    if (rrd_parse_make_vname(line, eaten, gdp, im))
        return 1;
    if ((gdp->rpnp = rpn_parse((void *) im, &line[*eaten], &find_var_wrapper)
        ) == NULL) {
        rrd_set_error("invalid rpn expression in: %s", &line[*eaten]);
        return 1;
    };
    while (line[*eaten] != '\0' && line[*eaten] != ':')
        (*eaten)++;
    return 0;
}

void rrd_graph_script(
    int argc,
    char *argv[],
    image_desc_t *const im,
    int optno)
{
    int       i;

    /* save state for STACK backward compat function */
    enum gf_en last_gf = GF_PRINT;
    float     last_linewidth = 0.0;

    for (i = optind + optno; i < argc; i++) {
        graph_desc_t *gdp;
        unsigned int eaten = 0;

        if (gdes_alloc(im)) /* gdes_c ++ */
            return;     /* the error string is already set */
        gdp = &im->gdes[im->gdes_c - 1];
#ifdef DEBUG
        gdp->debug = 1;
#endif

        if (rrd_parse_find_gf(argv[i], &eaten, gdp))
            return;

        switch (gdp->gf) {
        case GF_SHIFT: /* vname:value */
            if (rrd_parse_shift(argv[i], &eaten, gdp, im))
                return;
            break;
        case GF_TEXTALIGN: /* left|right|center|justified */
            if (rrd_parse_textalign(argv[i], &eaten, gdp))
                return;
            break;
        case GF_XPORT:
            if (rrd_parse_xport(argv[i], &eaten, gdp, im))
                return;
            break;
        case GF_PRINT: /* vname:CF:format -or- vname:format */
            im->prt_c++;
        case GF_GPRINT:    /* vname:CF:format -or- vname:format */
            if (rrd_parse_print(argv[i], &eaten, gdp, im))
                return;
            break;
        case GF_COMMENT:   /* text */
            if (rrd_parse_legend(argv[i], &eaten, gdp))
                return;
            break;
        case GF_VRULE: /* value#color[:legend] */
        case GF_HRULE: /* value#color[:legend] */
        case GF_LINE:  /* vname-or-value[#color[:legend]][:STACK] */
        case GF_AREA:  /* vname-or-value[#color[:legend]][:STACK] */
        case GF_TICK:  /* vname#color[:num[:legend]] */
            if (rrd_parse_PVHLAST(argv[i], &eaten, gdp, im))
                return;
            last_gf = gdp->gf;
            last_linewidth = gdp->linewidth;
            break;
        case GF_STACK: /* vname-or-value[#color[:legend]] */
            if (rrd_parse_PVHLAST(argv[i], &eaten, gdp, im))
                return;
            if (last_gf == GF_LINE || last_gf == GF_AREA) {
                gdp->gf = last_gf;
                gdp->linewidth = last_linewidth;
            } else {
                rrd_set_error("STACK must follow LINE or AREA! command:\n%s",
                              &argv[i][eaten], argv[i]);
                return;
            }
            break;
            /* data acquisition */
        case GF_DEF:   /* vname=x:DS:CF:[:step=#][:start=#][:end=#] */
            if (rrd_parse_def(argv[i], &eaten, gdp, im))
                return;
            break;
        case GF_CDEF:  /* vname=rpn-expression */
            if (rrd_parse_cdef(argv[i], &eaten, gdp, im))
                return;
            break;
        case GF_VDEF:  /* vname=rpn-expression */
            if (rrd_parse_vdef(argv[i], &eaten, gdp, im))
                return;
            break;
        }
        if (gdp->debug) {
            dprintf("used %i out of %zi chars\n", eaten, strlen(argv[i]));
            dprintf("parsed line: '%s'\n", argv[i]);
            dprintf("remaining: '%s'\n", &argv[i][eaten]);
            if (eaten >= strlen(argv[i]))
                dprintf("Command finished successfully\n");
        }
        if (eaten < strlen(argv[i])) {
            rrd_set_error("I don't understand '%s' in command: '%s'.",
                          &argv[i][eaten], argv[i]);
            return;
        }
        char *key = gdes_fetch_key((*gdp));
        if (gdp->gf == GF_DEF && !g_hash_table_lookup_extended(im->rrd_map,key,NULL,NULL)){
            g_hash_table_insert(im->gdef_map,g_strdup(key),GINT_TO_POINTER(im->gdes_c-1));
        } 
        free(key);
        if (gdp->gf == GF_DEF || gdp->gf == GF_VDEF || gdp->gf == GF_CDEF){
            g_hash_table_insert(im->gdef_map,g_strdup(gdp->vname),GINT_TO_POINTER(im->gdes_c-1));
        }
    }
}
