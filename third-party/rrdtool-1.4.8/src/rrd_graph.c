/****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 ****************************************************************************
 * rrd__graph.c  produce graphs from data in rrdfiles
 ****************************************************************************/


#include <sys/stat.h>

#ifdef WIN32
#include "strftime.h"
#endif

#include "rrd_tool.h"

/* for basename */
#ifdef HAVE_LIBGEN_H
#  include <libgen.h>
#else
#include "plbasename.h"
#endif

#if defined(WIN32) && !defined(__CYGWIN__) && !defined(__CYGWIN32__)
#include <io.h>
#include <fcntl.h>
#endif

#include <time.h>

#include <locale.h>

#ifdef HAVE_LANGINFO_H
#include <langinfo.h>
#endif

#include "rrd_graph.h"
#include "rrd_client.h"

/* some constant definitions */



#ifndef RRD_DEFAULT_FONT
/* there is special code later to pick Cour.ttf when running on windows */
#define RRD_DEFAULT_FONT "DejaVu Sans Mono,Bitstream Vera Sans Mono,monospace,Courier"
#endif

text_prop_t text_prop[] = {
    {8.0, RRD_DEFAULT_FONT,NULL}
    ,                   /* default */
    {9.0, RRD_DEFAULT_FONT,NULL}
    ,                   /* title */
    {7.0, RRD_DEFAULT_FONT,NULL}
    ,                   /* axis */
    {8.0, RRD_DEFAULT_FONT,NULL}
    ,                   /* unit */
    {8.0, RRD_DEFAULT_FONT,NULL} /* legend */
    ,
    {5.5, RRD_DEFAULT_FONT,NULL} /* watermark */
};

xlab_t    xlab[] = {
    {0, 0, TMT_SECOND, 30, TMT_MINUTE, 5, TMT_MINUTE, 5, 0, "%H:%M"}
    ,
    {2, 0, TMT_MINUTE, 1, TMT_MINUTE, 5, TMT_MINUTE, 5, 0, "%H:%M"}
    ,
    {5, 0, TMT_MINUTE, 2, TMT_MINUTE, 10, TMT_MINUTE, 10, 0, "%H:%M"}
    ,
    {10, 0, TMT_MINUTE, 5, TMT_MINUTE, 20, TMT_MINUTE, 20, 0, "%H:%M"}
    ,
    {30, 0, TMT_MINUTE, 10, TMT_HOUR, 1, TMT_HOUR, 1, 0, "%H:%M"}
    ,
    {60, 0, TMT_MINUTE, 30, TMT_HOUR, 2, TMT_HOUR, 2, 0, "%H:%M"}
    ,
    {60, 24 * 3600, TMT_MINUTE, 30, TMT_HOUR, 2, TMT_HOUR, 6, 0, "%a %H:%M"}
    ,
    {180, 0, TMT_HOUR, 1, TMT_HOUR, 6, TMT_HOUR, 6, 0, "%H:%M"}
    ,
    {180, 24 * 3600, TMT_HOUR, 1, TMT_HOUR, 6, TMT_HOUR, 12, 0, "%a %H:%M"}
    ,
    /*{300,             0,   TMT_HOUR,3,    TMT_HOUR,12,   TMT_HOUR,12,    12*3600,"%a %p"},  this looks silly */
    {600, 0, TMT_HOUR, 6, TMT_DAY, 1, TMT_DAY, 1, 24 * 3600, "%a"}
    ,
    {1200, 0, TMT_HOUR, 6, TMT_DAY, 1, TMT_DAY, 1, 24 * 3600, "%d"}
    ,
    {1800, 0, TMT_HOUR, 12, TMT_DAY, 1, TMT_DAY, 2, 24 * 3600, "%a %d"}
    ,
    {2400, 0, TMT_HOUR, 12, TMT_DAY, 1, TMT_DAY, 2, 24 * 3600, "%a"}
    ,
    {3600, 0, TMT_DAY, 1, TMT_WEEK, 1, TMT_WEEK, 1, 7 * 24 * 3600, "Week %V"}
    ,
    {3 * 3600, 0, TMT_WEEK, 1, TMT_MONTH, 1, TMT_WEEK, 2, 7 * 24 * 3600, "Week %V"}
    ,
    {6 * 3600, 0, TMT_MONTH, 1, TMT_MONTH, 1, TMT_MONTH, 1, 30 * 24 * 3600,
     "%b"}
    ,
    {48 * 3600, 0, TMT_MONTH, 1, TMT_MONTH, 3, TMT_MONTH, 3, 30 * 24 * 3600,
     "%b"}
    ,
    {315360, 0, TMT_MONTH, 3, TMT_YEAR, 1, TMT_YEAR, 1, 365 * 24 * 3600, "%Y"}
    ,
    {10 * 24 * 3600, 0, TMT_YEAR, 1, TMT_YEAR, 1, TMT_YEAR, 1,
     365 * 24 * 3600, "%y"}
    ,
    {-1, 0, TMT_MONTH, 0, TMT_MONTH, 0, TMT_MONTH, 0, 0, ""}
};

/* sensible y label intervals ...*/

ylab_t    ylab[] = {
    {0.1, {1, 2, 5, 10}
     }
    ,
    {0.2, {1, 5, 10, 20}
     }
    ,
    {0.5, {1, 2, 4, 10}
     }
    ,
    {1.0, {1, 2, 5, 10}
     }
    ,
    {2.0, {1, 5, 10, 20}
     }
    ,
    {5.0, {1, 2, 4, 10}
     }
    ,
    {10.0, {1, 2, 5, 10}
     }
    ,
    {20.0, {1, 5, 10, 20}
     }
    ,
    {50.0, {1, 2, 4, 10}
     }
    ,
    {100.0, {1, 2, 5, 10}
     }
    ,
    {200.0, {1, 5, 10, 20}
     }
    ,
    {500.0, {1, 2, 4, 10}
     }
    ,
    {0.0, {0, 0, 0, 0}
     }
};


gfx_color_t graph_col[] =   /* default colors */
{
    {1.00, 1.00, 1.00, 1.00},   /* canvas     */
    {0.95, 0.95, 0.95, 1.00},   /* background */
    {0.81, 0.81, 0.81, 1.00},   /* shade A    */
    {0.62, 0.62, 0.62, 1.00},   /* shade B    */
    {0.56, 0.56, 0.56, 0.75},   /* grid       */
    {0.87, 0.31, 0.31, 0.60},   /* major grid */
    {0.00, 0.00, 0.00, 1.00},   /* font       */
    {0.50, 0.12, 0.12, 1.00},   /* arrow      */
    {0.12, 0.12, 0.12, 1.00},   /* axis       */
    {0.00, 0.00, 0.00, 1.00}    /* frame      */
};


/* #define DEBUG */

#ifdef DEBUG
# define DPRINT(x)    (void)(printf x, printf("\n"))
#else
# define DPRINT(x)
#endif


/* initialize with xtr(im,0); */
int xtr(
    image_desc_t *im,
    time_t mytime)
{
    static double pixie;

    if (mytime == 0) {
        pixie = (double) im->xsize / (double) (im->end - im->start);
        return im->xorigin;
    }
    return (int) ((double) im->xorigin + pixie * (mytime - im->start));
}

/* translate data values into y coordinates */
double ytr(
    image_desc_t *im,
    double value)
{
    static double pixie;
    double    yval;

    if (isnan(value)) {
        if (!im->logarithmic)
            pixie = (double) im->ysize / (im->maxval - im->minval);
        else
            pixie =
                (double) im->ysize / (log10(im->maxval) - log10(im->minval));
        yval = im->yorigin;
    } else if (!im->logarithmic) {
        yval = im->yorigin - pixie * (value - im->minval);
    } else {
        if (value < im->minval) {
            yval = im->yorigin;
        } else {
            yval = im->yorigin - pixie * (log10(value) - log10(im->minval));
        }
    }
    return yval;
}



/* conversion function for symbolic entry names */


#define conv_if(VV,VVV) \
   if (strcmp(#VV, string) == 0) return VVV ;

enum gf_en gf_conv(
    char *string)
{

    conv_if(PRINT, GF_PRINT);
    conv_if(GPRINT, GF_GPRINT);
    conv_if(COMMENT, GF_COMMENT);
    conv_if(HRULE, GF_HRULE);
    conv_if(VRULE, GF_VRULE);
    conv_if(LINE, GF_LINE);
    conv_if(AREA, GF_AREA);
    conv_if(STACK, GF_STACK);
    conv_if(TICK, GF_TICK);
    conv_if(TEXTALIGN, GF_TEXTALIGN);
    conv_if(DEF, GF_DEF);
    conv_if(CDEF, GF_CDEF);
    conv_if(VDEF, GF_VDEF);
    conv_if(XPORT, GF_XPORT);
    conv_if(SHIFT, GF_SHIFT);

    return (enum gf_en)(-1);
}

enum gfx_if_en if_conv(
    char *string)
{

    conv_if(PNG, IF_PNG);
    conv_if(SVG, IF_SVG);
    conv_if(EPS, IF_EPS);
    conv_if(PDF, IF_PDF);

    return (enum gfx_if_en)(-1);
}

enum tmt_en tmt_conv(
    char *string)
{

    conv_if(SECOND, TMT_SECOND);
    conv_if(MINUTE, TMT_MINUTE);
    conv_if(HOUR, TMT_HOUR);
    conv_if(DAY, TMT_DAY);
    conv_if(WEEK, TMT_WEEK);
    conv_if(MONTH, TMT_MONTH);
    conv_if(YEAR, TMT_YEAR);
    return (enum tmt_en)(-1);
}

enum grc_en grc_conv(
    char *string)
{

    conv_if(BACK, GRC_BACK);
    conv_if(CANVAS, GRC_CANVAS);
    conv_if(SHADEA, GRC_SHADEA);
    conv_if(SHADEB, GRC_SHADEB);
    conv_if(GRID, GRC_GRID);
    conv_if(MGRID, GRC_MGRID);
    conv_if(FONT, GRC_FONT);
    conv_if(ARROW, GRC_ARROW);
    conv_if(AXIS, GRC_AXIS);
    conv_if(FRAME, GRC_FRAME);

    return (enum grc_en)(-1);
}

enum text_prop_en text_prop_conv(
    char *string)
{

    conv_if(DEFAULT, TEXT_PROP_DEFAULT);
    conv_if(TITLE, TEXT_PROP_TITLE);
    conv_if(AXIS, TEXT_PROP_AXIS);
    conv_if(UNIT, TEXT_PROP_UNIT);
    conv_if(LEGEND, TEXT_PROP_LEGEND);
    conv_if(WATERMARK, TEXT_PROP_WATERMARK);
    return (enum text_prop_en)(-1);
}


#undef conv_if

int im_free(
    image_desc_t *im)
{
    unsigned long i, ii;
    cairo_status_t status = (cairo_status_t) 0;

    if (im == NULL)
        return 0;

    if (im->daemon_addr != NULL)
      free(im->daemon_addr);

    if (im->gdef_map){
        g_hash_table_destroy(im->gdef_map);        
    }

    if (im->rrd_map){
        g_hash_table_destroy(im->rrd_map);        
    }

    for (i = 0; i < (unsigned) im->gdes_c; i++) {
        if (im->gdes[i].data_first) {
            /* careful here, because a single pointer can occur several times */
            free(im->gdes[i].data);
            if (im->gdes[i].ds_namv) {
                for (ii = 0; ii < im->gdes[i].ds_cnt; ii++)
                    free(im->gdes[i].ds_namv[ii]);
                free(im->gdes[i].ds_namv);
            }
        }
        /* free allocated memory used for dashed lines */
        if (im->gdes[i].p_dashes != NULL)
            free(im->gdes[i].p_dashes);

        free(im->gdes[i].p_data);
        free(im->gdes[i].rpnp);
    }
    free(im->gdes);

    for (i = 0; i < DIM(text_prop);i++){
        pango_font_description_free(im->text_prop[i].font_desc);
        im->text_prop[i].font_desc = NULL;
    }

    if (im->font_options)
        cairo_font_options_destroy(im->font_options);

    if (im->cr) {
        status = cairo_status(im->cr);
        cairo_destroy(im->cr);
    }


    if (im->rendered_image) {
        free(im->rendered_image);
    }

    if (im->layout) {
        g_object_unref (im->layout);
    }

    if (im->surface)
        cairo_surface_destroy(im->surface);

    if (status)
        fprintf(stderr, "OOPS: Cairo has issues it can't even die: %s\n",
                cairo_status_to_string(status));

    return 0;
}

/* find SI magnitude symbol for the given number*/
void auto_scale(
    image_desc_t *im,   /* image description */
    double *value,
    char **symb_ptr,
    double *magfact)
{

    char     *symbol[] = { "a", /* 10e-18 Atto */
        "f",            /* 10e-15 Femto */
        "p",            /* 10e-12 Pico */
        "n",            /* 10e-9  Nano */
        "u",            /* 10e-6  Micro */
        "m",            /* 10e-3  Milli */
        " ",            /* Base */
        "k",            /* 10e3   Kilo */
        "M",            /* 10e6   Mega */
        "G",            /* 10e9   Giga */
        "T",            /* 10e12  Tera */
        "P",            /* 10e15  Peta */
        "E"
    };                  /* 10e18  Exa */

    int       symbcenter = 6;
    int       sindex;

    if (*value == 0.0 || isnan(*value)) {
        sindex = 0;
        *magfact = 1.0;
    } else {
        sindex = floor(log(fabs(*value)) / log((double) im->base));
        *magfact = pow((double) im->base, (double) sindex);
        (*value) /= (*magfact);
    }
    if (sindex <= symbcenter && sindex >= -symbcenter) {
        (*symb_ptr) = symbol[sindex + symbcenter];
    } else {
        (*symb_ptr) = "?";
    }
}

/* power prefixes */

static char si_symbol[] = {
    'y',                /* 10e-24 Yocto */
    'z',                /* 10e-21 Zepto */
    'a',                /* 10e-18 Atto */
    'f',                /* 10e-15 Femto */
    'p',                /* 10e-12 Pico */
    'n',                /* 10e-9  Nano */
    'u',                /* 10e-6  Micro */
    'm',                /* 10e-3  Milli */
    ' ',                /* Base */
    'k',                /* 10e3   Kilo */
    'M',                /* 10e6   Mega */
    'G',                /* 10e9   Giga */
    'T',                /* 10e12  Tera */
    'P',                /* 10e15  Peta */
    'E',                /* 10e18  Exa */
    'Z',                /* 10e21  Zeta */
    'Y'                 /* 10e24  Yotta */
};
static const int si_symbcenter = 8;

/* find SI magnitude symbol for the numbers on the y-axis*/
void si_unit(
    image_desc_t *im    /* image description */
    )
{

    double    digits, viewdigits = 0;

    digits =
        floor(log(max(fabs(im->minval), fabs(im->maxval))) /
              log((double) im->base));

    if (im->unitsexponent != 9999) {
        /* unitsexponent = 9, 6, 3, 0, -3, -6, -9, etc */
        viewdigits = floor((double)(im->unitsexponent / 3));
    } else {
        viewdigits = digits;
    }

    im->magfact = pow((double) im->base, digits);

#ifdef DEBUG
    printf("digits %6.3f  im->magfact %6.3f\n", digits, im->magfact);
#endif

    im->viewfactor = im->magfact / pow((double) im->base, viewdigits);

    if (((viewdigits + si_symbcenter) < sizeof(si_symbol)) &&
        ((viewdigits + si_symbcenter) >= 0))
        im->symbol = si_symbol[(int) viewdigits + si_symbcenter];
    else
        im->symbol = '?';
}

/*  move min and max values around to become sensible */

void expand_range(
    image_desc_t *im)
{
    double    sensiblevalues[] = { 1000.0, 900.0, 800.0, 750.0, 700.0,
        600.0, 500.0, 400.0, 300.0, 250.0,
        200.0, 125.0, 100.0, 90.0, 80.0,
        75.0, 70.0, 60.0, 50.0, 40.0, 30.0,
        25.0, 20.0, 10.0, 9.0, 8.0,
        7.0, 6.0, 5.0, 4.0, 3.5, 3.0,
        2.5, 2.0, 1.8, 1.5, 1.2, 1.0,
        0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0, -1
    };

    double    scaled_min, scaled_max;
    double    adj;
    int       i;



#ifdef DEBUG
    printf("Min: %6.2f Max: %6.2f MagFactor: %6.2f\n",
           im->minval, im->maxval, im->magfact);
#endif

    if (isnan(im->ygridstep)) {
        if (im->extra_flags & ALTAUTOSCALE) {
            /* measure the amplitude of the function. Make sure that
               graph boundaries are slightly higher then max/min vals
               so we can see amplitude on the graph */
            double    delt, fact;

            delt = im->maxval - im->minval;
            adj = delt * 0.1;
            fact = 2.0 * pow(10.0,
                             floor(log10
                                   (max(fabs(im->minval), fabs(im->maxval)) /
                                    im->magfact)) - 2);
            if (delt < fact) {
                adj = (fact - delt) * 0.55;
#ifdef DEBUG
                printf
                    ("Min: %6.2f Max: %6.2f delt: %6.2f fact: %6.2f adj: %6.2f\n",
                     im->minval, im->maxval, delt, fact, adj);
#endif
            }
            im->minval -= adj;
            im->maxval += adj;
        } else if (im->extra_flags & ALTAUTOSCALE_MIN) {
            /* measure the amplitude of the function. Make sure that
               graph boundaries are slightly lower than min vals
               so we can see amplitude on the graph */
            adj = (im->maxval - im->minval) * 0.1;
            im->minval -= adj;
        } else if (im->extra_flags & ALTAUTOSCALE_MAX) {
            /* measure the amplitude of the function. Make sure that
               graph boundaries are slightly higher than max vals
               so we can see amplitude on the graph */
            adj = (im->maxval - im->minval) * 0.1;
            im->maxval += adj;
        } else {
            scaled_min = im->minval / im->magfact;
            scaled_max = im->maxval / im->magfact;

            for (i = 1; sensiblevalues[i] > 0; i++) {
                if (sensiblevalues[i - 1] >= scaled_min &&
                    sensiblevalues[i] <= scaled_min)
                    im->minval = sensiblevalues[i] * (im->magfact);

                if (-sensiblevalues[i - 1] <= scaled_min &&
                    -sensiblevalues[i] >= scaled_min)
                    im->minval = -sensiblevalues[i - 1] * (im->magfact);

                if (sensiblevalues[i - 1] >= scaled_max &&
                    sensiblevalues[i] <= scaled_max)
                    im->maxval = sensiblevalues[i - 1] * (im->magfact);

                if (-sensiblevalues[i - 1] <= scaled_max &&
                    -sensiblevalues[i] >= scaled_max)
                    im->maxval = -sensiblevalues[i] * (im->magfact);
            }
        }
    } else {
        /* adjust min and max to the grid definition if there is one */
        im->minval = (double) im->ylabfact * im->ygridstep *
            floor(im->minval / ((double) im->ylabfact * im->ygridstep));
        im->maxval = (double) im->ylabfact * im->ygridstep *
            ceil(im->maxval / ((double) im->ylabfact * im->ygridstep));
    }

#ifdef DEBUG
    fprintf(stderr, "SCALED Min: %6.2f Max: %6.2f Factor: %6.2f\n",
            im->minval, im->maxval, im->magfact);
#endif
}


void apply_gridfit(
    image_desc_t *im)
{
    if (isnan(im->minval) || isnan(im->maxval))
        return;
    ytr(im, DNAN);
    if (im->logarithmic) {
        double    ya, yb, ypix, ypixfrac;
        double    log10_range = log10(im->maxval) - log10(im->minval);

        ya = pow((double) 10, floor(log10(im->minval)));
        while (ya < im->minval)
            ya *= 10;
        if (ya > im->maxval)
            return;     /* don't have y=10^x gridline */
        yb = ya * 10;
        if (yb <= im->maxval) {
            /* we have at least 2 y=10^x gridlines.
               Make sure distance between them in pixels
               are an integer by expanding im->maxval */
            double    y_pixel_delta = ytr(im, ya) - ytr(im, yb);
            double    factor = y_pixel_delta / floor(y_pixel_delta);
            double    new_log10_range = factor * log10_range;
            double    new_ymax_log10 = log10(im->minval) + new_log10_range;

            im->maxval = pow(10, new_ymax_log10);
            ytr(im, DNAN);  /* reset precalc */
            log10_range = log10(im->maxval) - log10(im->minval);
        }
        /* make sure first y=10^x gridline is located on
           integer pixel position by moving scale slightly
           downwards (sub-pixel movement) */
        ypix = ytr(im, ya) + im->ysize; /* add im->ysize so it always is positive */
        ypixfrac = ypix - floor(ypix);
        if (ypixfrac > 0 && ypixfrac < 1) {
            double    yfrac = ypixfrac / im->ysize;

            im->minval = pow(10, log10(im->minval) - yfrac * log10_range);
            im->maxval = pow(10, log10(im->maxval) - yfrac * log10_range);
            ytr(im, DNAN);  /* reset precalc */
        }
    } else {
        /* Make sure we have an integer pixel distance between
           each minor gridline */
        double    ypos1 = ytr(im, im->minval);
        double    ypos2 = ytr(im, im->minval + im->ygrid_scale.gridstep);
        double    y_pixel_delta = ypos1 - ypos2;
        double    factor = y_pixel_delta / floor(y_pixel_delta);
        double    new_range = factor * (im->maxval - im->minval);
        double    gridstep = im->ygrid_scale.gridstep;
        double    minor_y, minor_y_px, minor_y_px_frac;

        if (im->maxval > 0.0)
            im->maxval = im->minval + new_range;
        else
            im->minval = im->maxval - new_range;
        ytr(im, DNAN);  /* reset precalc */
        /* make sure first minor gridline is on integer pixel y coord */
        minor_y = gridstep * floor(im->minval / gridstep);
        while (minor_y < im->minval)
            minor_y += gridstep;
        minor_y_px = ytr(im, minor_y) + im->ysize;  /* ensure > 0 by adding ysize */
        minor_y_px_frac = minor_y_px - floor(minor_y_px);
        if (minor_y_px_frac > 0 && minor_y_px_frac < 1) {
            double    yfrac = minor_y_px_frac / im->ysize;
            double    range = im->maxval - im->minval;

            im->minval = im->minval - yfrac * range;
            im->maxval = im->maxval - yfrac * range;
            ytr(im, DNAN);  /* reset precalc */
        }
        calc_horizontal_grid(im);   /* recalc with changed im->maxval */
    }
}

/* reduce data reimplementation by Alex */

void reduce_data(
    enum cf_en cf,      /* which consolidation function ? */
    unsigned long cur_step, /* step the data currently is in */
    time_t *start,      /* start, end and step as requested ... */
    time_t *end,        /* ... by the application will be   ... */
    unsigned long *step,    /* ... adjusted to represent reality    */
    unsigned long *ds_cnt,  /* number of data sources in file */
    rrd_value_t **data)
{                       /* two dimensional array containing the data */
    int       i, reduce_factor = ceil((double) (*step) / (double) cur_step);
    unsigned long col, dst_row, row_cnt, start_offset, end_offset, skiprows =
        0;
    rrd_value_t *srcptr, *dstptr;

    (*step) = cur_step * reduce_factor; /* set new step size for reduced data */
    dstptr = *data;
    srcptr = *data;
    row_cnt = ((*end) - (*start)) / cur_step;

#ifdef DEBUG
#define DEBUG_REDUCE
#endif
#ifdef DEBUG_REDUCE
    printf("Reducing %lu rows with factor %i time %lu to %lu, step %lu\n",
           row_cnt, reduce_factor, *start, *end, cur_step);
    for (col = 0; col < row_cnt; col++) {
        printf("time %10lu: ", *start + (col + 1) * cur_step);
        for (i = 0; i < *ds_cnt; i++)
            printf(" %8.2e", srcptr[*ds_cnt * col + i]);
        printf("\n");
    }
#endif

    /* We have to combine [reduce_factor] rows of the source
     ** into one row for the destination.  Doing this we also
     ** need to take care to combine the correct rows.  First
     ** alter the start and end time so that they are multiples
     ** of the new step time.  We cannot reduce the amount of
     ** time so we have to move the end towards the future and
     ** the start towards the past.
     */
    end_offset = (*end) % (*step);
    start_offset = (*start) % (*step);

    /* If there is a start offset (which cannot be more than
     ** one destination row), skip the appropriate number of
     ** source rows and one destination row.  The appropriate
     ** number is what we do know (start_offset/cur_step) of
     ** the new interval (*step/cur_step aka reduce_factor).
     */
#ifdef DEBUG_REDUCE
    printf("start_offset: %lu  end_offset: %lu\n", start_offset, end_offset);
    printf("row_cnt before:  %lu\n", row_cnt);
#endif
    if (start_offset) {
        (*start) = (*start) - start_offset;
        skiprows = reduce_factor - start_offset / cur_step;
        srcptr += skiprows * *ds_cnt;
        for (col = 0; col < (*ds_cnt); col++)
            *dstptr++ = DNAN;
        row_cnt -= skiprows;
    }
#ifdef DEBUG_REDUCE
    printf("row_cnt between: %lu\n", row_cnt);
#endif

    /* At the end we have some rows that are not going to be
     ** used, the amount is end_offset/cur_step
     */
    if (end_offset) {
        (*end) = (*end) - end_offset + (*step);
        skiprows = end_offset / cur_step;
        row_cnt -= skiprows;
    }
#ifdef DEBUG_REDUCE
    printf("row_cnt after:   %lu\n", row_cnt);
#endif

/* Sanity check: row_cnt should be multiple of reduce_factor */
/* if this gets triggered, something is REALLY WRONG ... we die immediately */

    if (row_cnt % reduce_factor) {
        printf("SANITY CHECK: %lu rows cannot be reduced by %i \n",
               row_cnt, reduce_factor);
        printf("BUG in reduce_data()\n");
        exit(1);
    }

    /* Now combine reduce_factor intervals at a time
     ** into one interval for the destination.
     */

    for (dst_row = 0; (long int) row_cnt >= reduce_factor; dst_row++) {
        for (col = 0; col < (*ds_cnt); col++) {
            rrd_value_t newval = DNAN;
            unsigned long validval = 0;

            for (i = 0; i < reduce_factor; i++) {
                if (isnan(srcptr[i * (*ds_cnt) + col])) {
                    continue;
                }
                validval++;
                if (isnan(newval))
                    newval = srcptr[i * (*ds_cnt) + col];
                else {
                    switch (cf) {
                    case CF_HWPREDICT:
                    case CF_MHWPREDICT:
                    case CF_DEVSEASONAL:
                    case CF_DEVPREDICT:
                    case CF_SEASONAL:
                    case CF_AVERAGE:
                        newval += srcptr[i * (*ds_cnt) + col];
                        break;
                    case CF_MINIMUM:
                        newval = min(newval, srcptr[i * (*ds_cnt) + col]);
                        break;
                    case CF_FAILURES:
                        /* an interval contains a failure if any subintervals contained a failure */
                    case CF_MAXIMUM:
                        newval = max(newval, srcptr[i * (*ds_cnt) + col]);
                        break;
                    case CF_LAST:
                        newval = srcptr[i * (*ds_cnt) + col];
                        break;
                    }
                }
            }
            if (validval == 0) {
                newval = DNAN;
            } else {
                switch (cf) {
                case CF_HWPREDICT:
                case CF_MHWPREDICT:
                case CF_DEVSEASONAL:
                case CF_DEVPREDICT:
                case CF_SEASONAL:
                case CF_AVERAGE:
                    newval /= validval;
                    break;
                case CF_MINIMUM:
                case CF_FAILURES:
                case CF_MAXIMUM:
                case CF_LAST:
                    break;
                }
            }
            *dstptr++ = newval;
        }
        srcptr += (*ds_cnt) * reduce_factor;
        row_cnt -= reduce_factor;
    }
    /* If we had to alter the endtime, we didn't have enough
     ** source rows to fill the last row. Fill it with NaN.
     */
    if (end_offset)
        for (col = 0; col < (*ds_cnt); col++)
            *dstptr++ = DNAN;
#ifdef DEBUG_REDUCE
    row_cnt = ((*end) - (*start)) / *step;
    srcptr = *data;
    printf("Done reducing. Currently %lu rows, time %lu to %lu, step %lu\n",
           row_cnt, *start, *end, *step);
    for (col = 0; col < row_cnt; col++) {
        printf("time %10lu: ", *start + (col + 1) * (*step));
        for (i = 0; i < *ds_cnt; i++)
            printf(" %8.2e", srcptr[*ds_cnt * col + i]);
        printf("\n");
    }
#endif
}


/* get the data required for the graphs from the
   relevant rrds ... */

int data_fetch(
    image_desc_t *im)
{
    int       i, ii;

    /* pull the data from the rrd files ... */
    for (i = 0; i < (int) im->gdes_c; i++) {
        /* only GF_DEF elements fetch data */
        if (im->gdes[i].gf != GF_DEF)
            continue;

        /* do we have it already ? */
        gpointer value;
        char *key = gdes_fetch_key(im->gdes[i]);
        gboolean ok = g_hash_table_lookup_extended(im->rrd_map,key,NULL,&value);
        free(key);
        if (ok){
            ii = GPOINTER_TO_INT(value);
            im->gdes[i].start = im->gdes[ii].start;
            im->gdes[i].end = im->gdes[ii].end;
            im->gdes[i].step = im->gdes[ii].step;
            im->gdes[i].ds_cnt = im->gdes[ii].ds_cnt;
            im->gdes[i].ds_namv = im->gdes[ii].ds_namv;
            im->gdes[i].data = im->gdes[ii].data;
            im->gdes[i].data_first = 0;
        } else {
            unsigned long ft_step = im->gdes[i].step;   /* ft_step will record what we got from fetch */

            /* Flush the file if
             * - a connection to the daemon has been established
             * - this is the first occurrence of that RRD file
             */
            if (rrdc_is_connected(im->daemon_addr))
            {
                int status;

                status = 0;
                for (ii = 0; ii < i; ii++)
                {
                    if (strcmp (im->gdes[i].rrd, im->gdes[ii].rrd) == 0)
                    {
                        status = 1;
                        break;
                    }
                }

                if (status == 0)
                {
                    status = rrdc_flush (im->gdes[i].rrd);
                    if (status != 0)
                    {
                        rrd_set_error ("rrdc_flush (%s) failed with status %i.",
                                im->gdes[i].rrd, status);
                        return (-1);
                    }
                }
            } /* if (rrdc_is_connected()) */

            if ((rrd_fetch_fn(im->gdes[i].rrd,
                              im->gdes[i].cf,
                              &im->gdes[i].start,
                              &im->gdes[i].end,
                              &ft_step,
                              &im->gdes[i].ds_cnt,
                              &im->gdes[i].ds_namv,
                              &im->gdes[i].data)) == -1) {
                return -1;
            }
            im->gdes[i].data_first = 1;

            /* must reduce to at least im->step
               otherwhise we end up with more data than we can handle in the 
               chart and visibility of data will be random */            
            im->gdes[i].step = max(im->gdes[i].step,im->step);
            if (ft_step < im->gdes[i].step) {
                reduce_data(im->gdes[i].cf_reduce,
                            ft_step,
                            &im->gdes[i].start,
                            &im->gdes[i].end,
                            &im->gdes[i].step,
                            &im->gdes[i].ds_cnt, &im->gdes[i].data);
            } else {
                im->gdes[i].step = ft_step;
            }
        }

        /* lets see if the required data source is really there */
        for (ii = 0; ii < (int) im->gdes[i].ds_cnt; ii++) {
            if (strcmp(im->gdes[i].ds_namv[ii], im->gdes[i].ds_nam) == 0) {
                im->gdes[i].ds = ii;
            }
        }
        if (im->gdes[i].ds == -1) {
            rrd_set_error("No DS called '%s' in '%s'",
                          im->gdes[i].ds_nam, im->gdes[i].rrd);
            return -1;
        }

    }
    return 0;
}

/* evaluate the expressions in the CDEF functions */

/*************************************************************
 * CDEF stuff
 *************************************************************/

long find_var_wrapper(
    void *arg1,
    char *key)
{
    return find_var((image_desc_t *) arg1, key);
}

/* find gdes containing var*/
long find_var(
    image_desc_t *im,
    char *key)
{
    long match = -1;
    gpointer value;
    gboolean ok = g_hash_table_lookup_extended(im->gdef_map,key,NULL,&value);
    if (ok){
        match = GPOINTER_TO_INT(value);
    }

    /* printf("%s -> %ld\n",key,match); */

    return match;    
}

/* find the greatest common divisor for all the numbers
   in the 0 terminated num array */
long lcd(
    long *num)
{
    long      rest;
    int       i;

    for (i = 0; num[i + 1] != 0; i++) {
        do {
            rest = num[i] % num[i + 1];
            num[i] = num[i + 1];
            num[i + 1] = rest;
        } while (rest != 0);
        num[i + 1] = num[i];
    }
/*    return i==0?num[i]:num[i-1]; */
    return num[i];
}

/* run the rpn calculator on all the VDEF and CDEF arguments */
int data_calc(
    image_desc_t *im)
{

    int       gdi;
    int       dataidx;
    long     *steparray, rpi;
    int       stepcnt;
    time_t    now;
    rpnstack_t rpnstack;

    rpnstack_init(&rpnstack);

    for (gdi = 0; gdi < im->gdes_c; gdi++) {
        /* Look for GF_VDEF and GF_CDEF in the same loop,
         * so CDEFs can use VDEFs and vice versa
         */
        switch (im->gdes[gdi].gf) {
        case GF_XPORT:
            break;
        case GF_SHIFT:{
            graph_desc_t *vdp = &im->gdes[im->gdes[gdi].vidx];

            /* remove current shift */
            vdp->start -= vdp->shift;
            vdp->end -= vdp->shift;

            /* vdef */
            if (im->gdes[gdi].shidx >= 0)
                vdp->shift = im->gdes[im->gdes[gdi].shidx].vf.val;
            /* constant */
            else
                vdp->shift = im->gdes[gdi].shval;

            /* normalize shift to multiple of consolidated step */
            vdp->shift = (vdp->shift / (long) vdp->step) * (long) vdp->step;

            /* apply shift */
            vdp->start += vdp->shift;
            vdp->end += vdp->shift;
            break;
        }
        case GF_VDEF:
            /* A VDEF has no DS.  This also signals other parts
             * of rrdtool that this is a VDEF value, not a CDEF.
             */
            im->gdes[gdi].ds_cnt = 0;
            if (vdef_calc(im, gdi)) {
                rrd_set_error("Error processing VDEF '%s'",
                              im->gdes[gdi].vname);
                rpnstack_free(&rpnstack);
                return -1;
            }
            break;
        case GF_CDEF:
            im->gdes[gdi].ds_cnt = 1;
            im->gdes[gdi].ds = 0;
            im->gdes[gdi].data_first = 1;
            im->gdes[gdi].start = 0;
            im->gdes[gdi].end = 0;
            steparray = NULL;
            stepcnt = 0;
            dataidx = -1;

            /* Find the variables in the expression.
             * - VDEF variables are substituted by their values
             *   and the opcode is changed into OP_NUMBER.
             * - CDEF variables are analized for their step size,
             *   the lowest common denominator of all the step
             *   sizes of the data sources involved is calculated
             *   and the resulting number is the step size for the
             *   resulting data source.
             */
            for (rpi = 0; im->gdes[gdi].rpnp[rpi].op != OP_END; rpi++) {
                if (im->gdes[gdi].rpnp[rpi].op == OP_VARIABLE ||
                    im->gdes[gdi].rpnp[rpi].op == OP_PREV_OTHER) {
                    long      ptr = im->gdes[gdi].rpnp[rpi].ptr;

                    if (im->gdes[ptr].ds_cnt == 0) {    /* this is a VDEF data source */
#if 0
                        printf
                            ("DEBUG: inside CDEF '%s' processing VDEF '%s'\n",
                             im->gdes[gdi].vname, im->gdes[ptr].vname);
                        printf("DEBUG: value from vdef is %f\n",
                               im->gdes[ptr].vf.val);
#endif
                        im->gdes[gdi].rpnp[rpi].val = im->gdes[ptr].vf.val;
                        im->gdes[gdi].rpnp[rpi].op = OP_NUMBER;
                    } else {    /* normal variables and PREF(variables) */

                        /* add one entry to the array that keeps track of the step sizes of the
                         * data sources going into the CDEF. */
                        if ((steparray =
                             (long*)rrd_realloc(steparray,
                                         (++stepcnt +
                                          1) * sizeof(*steparray))) == NULL) {
                            rrd_set_error("realloc steparray");
                            rpnstack_free(&rpnstack);
                            return -1;
                        };

                        steparray[stepcnt - 1] = im->gdes[ptr].step;

                        /* adjust start and end of cdef (gdi) so
                         * that it runs from the latest start point
                         * to the earliest endpoint of any of the
                         * rras involved (ptr)
                         */

                        if (im->gdes[gdi].start < im->gdes[ptr].start)
                            im->gdes[gdi].start = im->gdes[ptr].start;

                        if (im->gdes[gdi].end == 0 ||
                            im->gdes[gdi].end > im->gdes[ptr].end)
                            im->gdes[gdi].end = im->gdes[ptr].end;

                        /* store pointer to the first element of
                         * the rra providing data for variable,
                         * further save step size and data source
                         * count of this rra
                         */
                        im->gdes[gdi].rpnp[rpi].data =
                            im->gdes[ptr].data + im->gdes[ptr].ds;
                        im->gdes[gdi].rpnp[rpi].step = im->gdes[ptr].step;
                        im->gdes[gdi].rpnp[rpi].ds_cnt = im->gdes[ptr].ds_cnt;

                        /* backoff the *.data ptr; this is done so
                         * rpncalc() function doesn't have to treat
                         * the first case differently
                         */
                    }   /* if ds_cnt != 0 */
                }       /* if OP_VARIABLE */
            }           /* loop through all rpi */

            /* move the data pointers to the correct period */
            for (rpi = 0; im->gdes[gdi].rpnp[rpi].op != OP_END; rpi++) {
                if (im->gdes[gdi].rpnp[rpi].op == OP_VARIABLE ||
                    im->gdes[gdi].rpnp[rpi].op == OP_PREV_OTHER) {
                    long      ptr = im->gdes[gdi].rpnp[rpi].ptr;
                    long      diff =
                        im->gdes[gdi].start - im->gdes[ptr].start;

                    if (diff > 0)
                        im->gdes[gdi].rpnp[rpi].data +=
                            (diff / im->gdes[ptr].step) *
                            im->gdes[ptr].ds_cnt;
                }
            }

            if (steparray == NULL) {
                rrd_set_error("rpn expressions without DEF"
                              " or CDEF variables are not supported");
                rpnstack_free(&rpnstack);
                return -1;
            }
            steparray[stepcnt] = 0;
            /* Now find the resulting step.  All steps in all
             * used RRAs have to be visited
             */
            im->gdes[gdi].step = lcd(steparray);
            free(steparray);
            if ((im->gdes[gdi].data = (rrd_value_t*)malloc(((im->gdes[gdi].end -
                                               im->gdes[gdi].start)
                                              / im->gdes[gdi].step)
                                             * sizeof(double))) == NULL) {
                rrd_set_error("malloc im->gdes[gdi].data");
                rpnstack_free(&rpnstack);
                return -1;
            }

            /* Step through the new cdef results array and
             * calculate the values
             */
            for (now = im->gdes[gdi].start + im->gdes[gdi].step;
                 now <= im->gdes[gdi].end; now += im->gdes[gdi].step) {
                rpnp_t   *rpnp = im->gdes[gdi].rpnp;

                /* 3rd arg of rpn_calc is for OP_VARIABLE lookups;
                 * in this case we are advancing by timesteps;
                 * we use the fact that time_t is a synonym for long
                 */
                if (rpn_calc(rpnp, &rpnstack, (long) now,
                             im->gdes[gdi].data, ++dataidx) == -1) {
                    /* rpn_calc sets the error string */
                    rpnstack_free(&rpnstack);
                    return -1;
                }
            }           /* enumerate over time steps within a CDEF */
            break;
        default:
            continue;
        }
    }                   /* enumerate over CDEFs */
    rpnstack_free(&rpnstack);
    return 0;
}

/* from http://www.cygnus-software.com/papers/comparingfloats/comparingfloats.htm */
/* yes we are loosing precision by doing tos with floats instead of doubles
   but it seems more stable this way. */

static int AlmostEqual2sComplement(
    float A,
    float B,
    int maxUlps)
{

    int       aInt = *(int *) &A;
    int       bInt = *(int *) &B;
    int       intDiff;

    /* Make sure maxUlps is non-negative and small enough that the
       default NAN won't compare as equal to anything.  */

    /* assert(maxUlps > 0 && maxUlps < 4 * 1024 * 1024); */

    /* Make aInt lexicographically ordered as a twos-complement int */

    if (aInt < 0)
        aInt = 0x80000000l - aInt;

    /* Make bInt lexicographically ordered as a twos-complement int */

    if (bInt < 0)
        bInt = 0x80000000l - bInt;

    intDiff = abs(aInt - bInt);

    if (intDiff <= maxUlps)
        return 1;

    return 0;
}

/* massage data so, that we get one value for each x coordinate in the graph */
int data_proc(
    image_desc_t *im)
{
    long      i, ii;
    double    pixstep = (double) (im->end - im->start)
        / (double) im->xsize;   /* how much time
                                   passes in one pixel */
    double    paintval;
    double    minval = DNAN, maxval = DNAN;

    unsigned long gr_time;

    /* memory for the processed data */
    for (i = 0; i < im->gdes_c; i++) {
        if ((im->gdes[i].gf == GF_LINE) ||
            (im->gdes[i].gf == GF_AREA) || (im->gdes[i].gf == GF_TICK)) {
            if ((im->gdes[i].p_data = (rrd_value_t*)malloc((im->xsize + 1)
                                             * sizeof(rrd_value_t))) == NULL) {
                rrd_set_error("malloc data_proc");
                return -1;
            }
        }
    }

    for (i = 0; i < im->xsize; i++) {   /* for each pixel */
        long      vidx;

        gr_time = im->start + pixstep * i;  /* time of the current step */
        paintval = 0.0;

        for (ii = 0; ii < im->gdes_c; ii++) {
            double    value;

            switch (im->gdes[ii].gf) {
            case GF_LINE:
            case GF_AREA:
            case GF_TICK:
                if (!im->gdes[ii].stack)
                    paintval = 0.0;
                value = im->gdes[ii].yrule;
                if (isnan(value) || (im->gdes[ii].gf == GF_TICK)) {
                    /* The time of the data doesn't necessarily match
                     ** the time of the graph. Beware.
                     */
                    vidx = im->gdes[ii].vidx;
                    if (im->gdes[vidx].gf == GF_VDEF) {
                        value = im->gdes[vidx].vf.val;
                    } else
                        if (((long int) gr_time >=
                             (long int) im->gdes[vidx].start)
                            && ((long int) gr_time <
                                (long int) im->gdes[vidx].end)) {
                        value = im->gdes[vidx].data[(unsigned long)
                                                    floor((double)
                                                          (gr_time -
                                                           im->gdes[vidx].
                                                           start)
                                                          /
                                                          im->gdes[vidx].step)
                                                    * im->gdes[vidx].ds_cnt +
                                                    im->gdes[vidx].ds];
                    } else {
                        value = DNAN;
                    }
                };

                if (!isnan(value)) {
                    paintval += value;
                    im->gdes[ii].p_data[i] = paintval;
                    /* GF_TICK: the data values are not
                     ** relevant for min and max
                     */
                    if (finite(paintval) && im->gdes[ii].gf != GF_TICK && !im->gdes[ii].skipscale) {
                        if ((isnan(minval) || paintval < minval) &&
                            !(im->logarithmic && paintval <= 0.0))
                            minval = paintval;
                        if (isnan(maxval) || paintval > maxval)
                            maxval = paintval;
                    }
                } else {
                    im->gdes[ii].p_data[i] = DNAN;
                }
                break;
            case GF_STACK:
                rrd_set_error
                    ("STACK should already be turned into LINE or AREA here");
                return -1;
                break;
            default:
                break;
            }
        }
    }

    /* if min or max have not been asigned a value this is because
       there was no data in the graph ... this is not good ...
       lets set these to dummy values then ... */

    if (im->logarithmic) {
        if (isnan(minval) || isnan(maxval) || maxval <= 0) {
            minval = 0.0;   /* catching this right away below */
            maxval = 5.1;
        }
        /* in logarithm mode, where minval is smaller or equal
           to 0 make the beast just way smaller than maxval */
        if (minval <= 0) {
            minval = maxval / 10e8;
        }
    } else {
        if (isnan(minval) || isnan(maxval)) {
            minval = 0.0;
            maxval = 1.0;
        }
    }

    /* adjust min and max values given by the user */
    /* for logscale we add something on top */
    if (isnan(im->minval)
        || ((!im->rigid) && im->minval > minval)
        ) {
        if (im->logarithmic)
            im->minval = minval / 2.0;
        else
            im->minval = minval;
    }
    if (isnan(im->maxval)
        || (!im->rigid && im->maxval < maxval)
        ) {
        if (im->logarithmic)
            im->maxval = maxval * 2.0;
        else
            im->maxval = maxval;
    }

    /* make sure min is smaller than max */
    if (im->minval > im->maxval) {
        if (im->minval > 0)
            im->minval = 0.99 * im->maxval;
        else
            im->minval = 1.01 * im->maxval;
    }

    /* make sure min and max are not equal */
    if (AlmostEqual2sComplement(im->minval, im->maxval, 4)) {
        if (im->maxval > 0)
            im->maxval *= 1.01;
        else
            im->maxval *= 0.99;

        /* make sure min and max are not both zero */
        if (AlmostEqual2sComplement(im->maxval, 0, 4)) {
            im->maxval = 1.0;
        }
    }
    return 0;
}

static int find_first_weekday(void){
    static int first_weekday = -1;
    if (first_weekday == -1){
#ifdef HAVE__NL_TIME_WEEK_1STDAY
        /* according to http://sourceware.org/ml/libc-locales/2009-q1/msg00011.html */
        /* See correct way here http://pasky.or.cz/dev/glibc/first_weekday.c */
        first_weekday = nl_langinfo (_NL_TIME_FIRST_WEEKDAY)[0];
        int week_1stday;
        long week_1stday_l = (long) nl_langinfo (_NL_TIME_WEEK_1STDAY);
        if (week_1stday_l == 19971130) week_1stday = 0; /* Sun */
        else if (week_1stday_l == 19971201) week_1stday = 1; /* Mon */
        else
        {
            first_weekday = 1;
            return first_weekday; /* we go for a monday default */
        }
        first_weekday=(week_1stday + first_weekday - 1) % 7;
#else
        first_weekday = 1;
#endif
    }
    return first_weekday;
}

/* identify the point where the first gridline, label ... gets placed */

time_t find_first_time(
    time_t start,       /* what is the initial time */
    enum tmt_en baseint,    /* what is the basic interval */
    long basestep       /* how many if these do we jump a time */
    )
{
    struct tm tm;

    localtime_r(&start, &tm);
    /* let mktime figure this dst on its own */
    tm.tm_isdst = -1;

    switch (baseint) {
    case TMT_SECOND:
        tm.       tm_sec -= tm.tm_sec % basestep;

        break;
    case TMT_MINUTE:
        tm.       tm_sec = 0;
        tm.       tm_min -= tm.tm_min % basestep;

        break;
    case TMT_HOUR:
        tm.       tm_sec = 0;
        tm.       tm_min = 0;
        tm.       tm_hour -= tm.tm_hour % basestep;

        break;
    case TMT_DAY:
        /* we do NOT look at the basestep for this ... */
        tm.       tm_sec = 0;
        tm.       tm_min = 0;
        tm.       tm_hour = 0;

        break;
    case TMT_WEEK:
        /* we do NOT look at the basestep for this ... */
        tm.       tm_sec = 0;
        tm.       tm_min = 0;
        tm.       tm_hour = 0;
        tm.       tm_mday -= tm.tm_wday - find_first_weekday();

        if (tm.tm_wday == 0 && find_first_weekday() > 0)
            tm.       tm_mday -= 7; /* we want the *previous* week */

        break;
    case TMT_MONTH:
        tm.       tm_sec = 0;
        tm.       tm_min = 0;
        tm.       tm_hour = 0;
        tm.       tm_mday = 1;
        tm.       tm_mon -= tm.tm_mon % basestep;

        break;

    case TMT_YEAR:
        tm.       tm_sec = 0;
        tm.       tm_min = 0;
        tm.       tm_hour = 0;
        tm.       tm_mday = 1;
        tm.       tm_mon = 0;
        tm.       tm_year -= (
    tm.tm_year + 1900) %basestep;

    }
    return mktime(&tm);
}

/* identify the point where the next gridline, label ... gets placed */
time_t find_next_time(
    time_t current,     /* what is the initial time */
    enum tmt_en baseint,    /* what is the basic interval */
    long basestep       /* how many if these do we jump a time */
    )
{
    struct tm tm;
    time_t    madetime;

    localtime_r(&current, &tm);
    /* let mktime figure this dst on its own */
    tm.tm_isdst = -1;

    int limit = 2;
    switch (baseint) {
    case TMT_SECOND: limit = 7200; break;
    case TMT_MINUTE: limit = 120; break;
    case TMT_HOUR: limit = 2; break;
    default: limit = 2; break;
    }
    do {
        switch (baseint) {
        case TMT_SECOND:
            tm.       tm_sec += basestep;

            break;
        case TMT_MINUTE:
            tm.       tm_min += basestep;

            break;
        case TMT_HOUR:
            tm.       tm_hour += basestep;

            break;
        case TMT_DAY:
            tm.       tm_mday += basestep;

            break;
        case TMT_WEEK:
            tm.       tm_mday += 7 * basestep;

            break;
        case TMT_MONTH:
            tm.       tm_mon += basestep;

            break;
        case TMT_YEAR:
            tm.       tm_year += basestep;
        }
        madetime = mktime(&tm);
    } while (madetime == -1 && limit-- >= 0);   /* this is necessary to skip impossible times
                                   like the daylight saving time skips */
    return madetime;

}


/* calculate values required for PRINT and GPRINT functions */

int print_calc(
    image_desc_t *im)
{
    long      i, ii, validsteps;
    double    printval;
    struct tm tmvdef;
    int       graphelement = 0;
    long      vidx;
    int       max_ii;
    double    magfact = -1;
    char     *si_symb = "";
    char     *percent_s;
    int       prline_cnt = 0;

    /* wow initializing tmvdef is quite a task :-) */
    time_t    now = time(NULL);

    localtime_r(&now, &tmvdef);
    for (i = 0; i < im->gdes_c; i++) {
        vidx = im->gdes[i].vidx;
        switch (im->gdes[i].gf) {
        case GF_PRINT:
        case GF_GPRINT:
            /* PRINT and GPRINT can now print VDEF generated values.
             * There's no need to do any calculations on them as these
             * calculations were already made.
             */
            if (im->gdes[vidx].gf == GF_VDEF) { /* simply use vals */
                printval = im->gdes[vidx].vf.val;
                localtime_r(&im->gdes[vidx].vf.when, &tmvdef);
            } else {    /* need to calculate max,min,avg etcetera */
                max_ii = ((im->gdes[vidx].end - im->gdes[vidx].start)
                          / im->gdes[vidx].step * im->gdes[vidx].ds_cnt);
                printval = DNAN;
                validsteps = 0;
                for (ii = im->gdes[vidx].ds;
                     ii < max_ii; ii += im->gdes[vidx].ds_cnt) {
                    if (!finite(im->gdes[vidx].data[ii]))
                        continue;
                    if (isnan(printval)) {
                        printval = im->gdes[vidx].data[ii];
                        validsteps++;
                        continue;
                    }

                    switch (im->gdes[i].cf) {
                    case CF_HWPREDICT:
                    case CF_MHWPREDICT:
                    case CF_DEVPREDICT:
                    case CF_DEVSEASONAL:
                    case CF_SEASONAL:
                    case CF_AVERAGE:
                        validsteps++;
                        printval += im->gdes[vidx].data[ii];
                        break;
                    case CF_MINIMUM:
                        printval = min(printval, im->gdes[vidx].data[ii]);
                        break;
                    case CF_FAILURES:
                    case CF_MAXIMUM:
                        printval = max(printval, im->gdes[vidx].data[ii]);
                        break;
                    case CF_LAST:
                        printval = im->gdes[vidx].data[ii];
                    }
                }
                if (im->gdes[i].cf == CF_AVERAGE || im->gdes[i].cf > CF_LAST) {
                    if (validsteps > 1) {
                        printval = (printval / validsteps);
                    }
                }
            }           /* prepare printval */

            if (!im->gdes[i].strftm && (percent_s = strstr(im->gdes[i].format, "%S")) != NULL) {
                /* Magfact is set to -1 upon entry to print_calc.  If it
                 * is still less than 0, then we need to run auto_scale.
                 * Otherwise, put the value into the correct units.  If
                 * the value is 0, then do not set the symbol or magnification
                 * so next the calculation will be performed again. */
                if (magfact < 0.0) {
                    auto_scale(im, &printval, &si_symb, &magfact);
                    if (printval == 0.0)
                        magfact = -1.0;
                } else {
                    printval /= magfact;
                }
                *(++percent_s) = 's';
            } else if (!im->gdes[i].strftm && strstr(im->gdes[i].format, "%s") != NULL) {
                auto_scale(im, &printval, &si_symb, &magfact);
            }

            if (im->gdes[i].gf == GF_PRINT) {
                rrd_infoval_t prline;

                if (im->gdes[i].strftm) {
                    prline.u_str = (char*)malloc((FMT_LEG_LEN + 2) * sizeof(char));
                    strftime(prline.u_str,
                             FMT_LEG_LEN, im->gdes[i].format, &tmvdef);
                } else if (bad_format(im->gdes[i].format)) {
                    rrd_set_error
                        ("bad format for PRINT in '%s'", im->gdes[i].format);
                    return -1;
                } else {
                    prline.u_str =
                        sprintf_alloc(im->gdes[i].format, printval, si_symb);
                }
                grinfo_push(im,
                            sprintf_alloc
                            ("print[%ld]", prline_cnt++), RD_I_STR, prline);
                free(prline.u_str);
            } else {
                /* GF_GPRINT */

                if (im->gdes[i].strftm) {
                    strftime(im->gdes[i].legend,
                             FMT_LEG_LEN, im->gdes[i].format, &tmvdef);
                } else {
                    if (bad_format(im->gdes[i].format)) {
                        rrd_set_error
                            ("bad format for GPRINT in '%s'",
                             im->gdes[i].format);
                        return -1;
                    }
#ifdef HAVE_SNPRINTF
                    snprintf(im->gdes[i].legend,
                             FMT_LEG_LEN - 2,
                             im->gdes[i].format, printval, si_symb);
#else
                    sprintf(im->gdes[i].legend,
                            im->gdes[i].format, printval, si_symb);
#endif
                }
                graphelement = 1;
            }
            break;
        case GF_LINE:
        case GF_AREA:
        case GF_TICK:
            graphelement = 1;
            break;
        case GF_HRULE:
            if (isnan(im->gdes[i].yrule)) { /* we must set this here or the legend printer can not decide to print the legend */
                im->gdes[i].yrule = im->gdes[vidx].vf.val;
            };
            graphelement = 1;
            break;
        case GF_VRULE:
            if (im->gdes[i].xrule == 0) {   /* again ... the legend printer needs it */
                im->gdes[i].xrule = im->gdes[vidx].vf.when;
            };
            graphelement = 1;
            break;
        case GF_COMMENT:
        case GF_TEXTALIGN:
        case GF_DEF:
        case GF_CDEF:
        case GF_VDEF:
#ifdef WITH_PIECHART
        case GF_PART:
#endif
        case GF_SHIFT:
        case GF_XPORT:
            break;
        case GF_STACK:
            rrd_set_error
                ("STACK should already be turned into LINE or AREA here");
            return -1;
            break;
        }
    }
    return graphelement;
}



/* place legends with color spots */
int leg_place(
    image_desc_t *im,
    int calc_width)
{
    /* graph labels */
    int       interleg = im->text_prop[TEXT_PROP_LEGEND].size * 2.0;
    int       border = im->text_prop[TEXT_PROP_LEGEND].size * 2.0;
    int       fill = 0, fill_last;
    double    legendwidth; // = im->ximg - 2 * border;
    int       leg_c = 0;
    double    leg_x = border;
    int       leg_y = 0; //im->yimg;
    int       leg_cc;
    double    glue = 0;
    int       i, ii, mark = 0;
    char      default_txtalign = TXA_JUSTIFIED; /*default line orientation */
    int      *legspace;
    char     *tab;
    char      saved_legend[FMT_LEG_LEN + 5];

    if(calc_width){
        legendwidth = 0;
    }
    else{
        legendwidth = im->legendwidth - 2 * border;
    }


    if (!(im->extra_flags & NOLEGEND) && !(im->extra_flags & ONLY_GRAPH)) {
        if ((legspace = (int*)malloc(im->gdes_c * sizeof(int))) == NULL) {
            rrd_set_error("malloc for legspace");
            return -1;
        }

        for (i = 0; i < im->gdes_c; i++) {
            char      prt_fctn; /*special printfunctions */
            if(calc_width){
                strcpy(saved_legend, im->gdes[i].legend);
            }

            fill_last = fill;
            /* hide legends for rules which are not displayed */
            if (im->gdes[i].gf == GF_TEXTALIGN) {
                default_txtalign = im->gdes[i].txtalign;
            }

            if (!(im->extra_flags & FORCE_RULES_LEGEND)) {
                if (im->gdes[i].gf == GF_HRULE
                    && (im->gdes[i].yrule <
                        im->minval || im->gdes[i].yrule > im->maxval))
                    im->gdes[i].legend[0] = '\0';
                if (im->gdes[i].gf == GF_VRULE
                    && (im->gdes[i].xrule <
                        im->start || im->gdes[i].xrule > im->end))
                    im->gdes[i].legend[0] = '\0';
            }

            /* turn \\t into tab */
            while ((tab = strstr(im->gdes[i].legend, "\\t"))) {
                memmove(tab, tab + 1, strlen(tab));
                tab[0] = (char) 9;
            }

            leg_cc = strlen(im->gdes[i].legend);
            /* is there a controle code at the end of the legend string ? */
            if (leg_cc >= 2 && im->gdes[i].legend[leg_cc - 2] == '\\') {
                prt_fctn = im->gdes[i].legend[leg_cc - 1];
                leg_cc -= 2;
                im->gdes[i].legend[leg_cc] = '\0';
            } else {
                prt_fctn = '\0';
            }
            /* only valid control codes */
            if (prt_fctn != 'l' && prt_fctn != 'n' &&   /* a synonym for l */
                prt_fctn != 'r' &&
                prt_fctn != 'j' &&
                prt_fctn != 'c' &&
                prt_fctn != 'u' &&
                prt_fctn != '.' &&
                prt_fctn != 's' && prt_fctn != '\0' && prt_fctn != 'g') {
                free(legspace);
                rrd_set_error
                    ("Unknown control code at the end of '%s\\%c'",
                     im->gdes[i].legend, prt_fctn);
                return -1;
            }
            /* \n -> \l */
            if (prt_fctn == 'n') {
                prt_fctn = 'l';
            }
            /* \. is a null operation to allow strings ending in \x */
            if (prt_fctn == '.') {
                prt_fctn = '\0';
            }

            /* remove exess space from the end of the legend for \g */
            while (prt_fctn == 'g' &&
                   leg_cc > 0 && im->gdes[i].legend[leg_cc - 1] == ' ') {
                leg_cc--;
                im->gdes[i].legend[leg_cc] = '\0';
            }

            if (leg_cc != 0) {

                /* no interleg space if string ends in \g */
                legspace[i] = (prt_fctn == 'g' ? 0 : interleg);
                if (fill > 0) {
                    fill += legspace[i];
                }
                fill +=
                    gfx_get_text_width(im,
                                       fill + border,
                                       im->
                                       text_prop
                                       [TEXT_PROP_LEGEND].
                                       font_desc,
                                       im->tabwidth, im->gdes[i].legend);
                leg_c++;
            } else {
                legspace[i] = 0;
            }
            /* who said there was a special tag ... ? */
            if (prt_fctn == 'g') {
                prt_fctn = '\0';
            }

            if (prt_fctn == '\0') {
                if(calc_width && (fill > legendwidth)){
                    legendwidth = fill;
                }
                if (i == im->gdes_c - 1 || fill > legendwidth) {
                    /* just one legend item is left right or center */
                    switch (default_txtalign) {
                    case TXA_RIGHT:
                        prt_fctn = 'r';
                        break;
                    case TXA_CENTER:
                        prt_fctn = 'c';
                        break;
                    case TXA_JUSTIFIED:
                        prt_fctn = 'j';
                        break;
                    default:
                        prt_fctn = 'l';
                        break;
                    }
                }
                /* is it time to place the legends ? */
                if (fill > legendwidth) {
                    if (leg_c > 1) {
                        /* go back one */
                        i--;
                        fill = fill_last;
                        leg_c--;
                    }
                }
                if (leg_c == 1 && prt_fctn == 'j') {
                    prt_fctn = 'l';
                }
            }

            if (prt_fctn != '\0') {
                leg_x = border;
                if (leg_c >= 2 && prt_fctn == 'j') {
                    glue = (double)(legendwidth - fill) / (double)(leg_c - 1);
                } else {
                    glue = 0;
                }
                if (prt_fctn == 'c')
                    leg_x = border + (double)(legendwidth - fill) / 2.0;
                if (prt_fctn == 'r')
                    leg_x = legendwidth - fill + border;
                for (ii = mark; ii <= i; ii++) {
                    if (im->gdes[ii].legend[0] == '\0')
                        continue;   /* skip empty legends */
                    im->gdes[ii].leg_x = leg_x;
                    im->gdes[ii].leg_y = leg_y + border;
                    leg_x +=
                        (double)gfx_get_text_width(im, leg_x,
                                           im->
                                           text_prop
                                           [TEXT_PROP_LEGEND].
                                           font_desc,
                                           im->tabwidth, im->gdes[ii].legend)
                        +(double)legspace[ii]
                        + glue;
                }
                if (leg_x > border || prt_fctn == 's')
                    leg_y += im->text_prop[TEXT_PROP_LEGEND].size * 1.8;
                if (prt_fctn == 's')
                    leg_y -= im->text_prop[TEXT_PROP_LEGEND].size;
                if (prt_fctn == 'u')
                    leg_y -= im->text_prop[TEXT_PROP_LEGEND].size *1.8;

                if(calc_width && (fill > legendwidth)){
                    legendwidth = fill;
                }
                fill = 0;
                leg_c = 0;
                mark = ii;
            }

            if(calc_width){
                strcpy(im->gdes[i].legend, saved_legend);
            }
        }

        if(calc_width){
            im->legendwidth = legendwidth + 2 * border;
        }
        else{
            im->legendheight = leg_y + border * 0.6;
        }
        free(legspace);
    }
    return 0;
}

/* create a grid on the graph. it determines what to do
   from the values of xsize, start and end */

/* the xaxis labels are determined from the number of seconds per pixel
   in the requested graph */

int calc_horizontal_grid(
    image_desc_t
    *im)
{
    double    range;
    double    scaledrange;
    int       pixel, i;
    int       gridind = 0;
    int       decimals, fractionals;

    im->ygrid_scale.labfact = 2;
    range = im->maxval - im->minval;
    scaledrange = range / im->magfact;
    /* does the scale of this graph make it impossible to put lines
       on it? If so, give up. */
    if (isnan(scaledrange)) {
        return 0;
    }

    /* find grid spaceing */
    pixel = 1;
    if (isnan(im->ygridstep)) {
        if (im->extra_flags & ALTYGRID) {
            /* find the value with max number of digits. Get number of digits */
            decimals =
                ceil(log10
                     (max(fabs(im->maxval), fabs(im->minval)) *
                      im->viewfactor / im->magfact));
            if (decimals <= 0)  /* everything is small. make place for zero */
                decimals = 1;
            im->ygrid_scale.gridstep =
                pow((double) 10,
                    floor(log10(range * im->viewfactor / im->magfact))) /
                im->viewfactor * im->magfact;
            if (im->ygrid_scale.gridstep == 0)  /* range is one -> 0.1 is reasonable scale */
                im->ygrid_scale.gridstep = 0.1;
            /* should have at least 5 lines but no more then 15 */
            if (range / im->ygrid_scale.gridstep < 5
                && im->ygrid_scale.gridstep >= 30)
                im->ygrid_scale.gridstep /= 10;
            if (range / im->ygrid_scale.gridstep > 15)
                im->ygrid_scale.gridstep *= 10;
            if (range / im->ygrid_scale.gridstep > 5) {
                im->ygrid_scale.labfact = 1;
                if (range / im->ygrid_scale.gridstep > 8
                    || im->ygrid_scale.gridstep <
                    1.8 * im->text_prop[TEXT_PROP_AXIS].size)
                    im->ygrid_scale.labfact = 2;
            } else {
                im->ygrid_scale.gridstep /= 5;
                im->ygrid_scale.labfact = 5;
            }
            fractionals =
                floor(log10
                      (im->ygrid_scale.gridstep *
                       (double) im->ygrid_scale.labfact * im->viewfactor /
                       im->magfact));
            if (fractionals < 0) {  /* small amplitude. */
                int       len = decimals - fractionals + 1;

                if (im->unitslength < len + 2)
                    im->unitslength = len + 2;
                sprintf(im->ygrid_scale.labfmt,
                        "%%%d.%df%s", len,
                        -fractionals, (im->symbol != ' ' ? " %c" : ""));
            } else {
                int       len = decimals + 1;

                if (im->unitslength < len + 2)
                    im->unitslength = len + 2;
                sprintf(im->ygrid_scale.labfmt,
                        "%%%d.0f%s", len, (im->symbol != ' ' ? " %c" : ""));
            }
        } else {        /* classic rrd grid */
            for (i = 0; ylab[i].grid > 0; i++) {
                pixel = im->ysize / (scaledrange / ylab[i].grid);
                gridind = i;
                if (pixel >= 5)
                    break;
            }

            for (i = 0; i < 4; i++) {
                if (pixel * ylab[gridind].lfac[i] >=
                    1.8 * im->text_prop[TEXT_PROP_AXIS].size) {
                    im->ygrid_scale.labfact = ylab[gridind].lfac[i];
                    break;
                }
            }

            im->ygrid_scale.gridstep = ylab[gridind].grid * im->magfact;
        }
    } else {
        im->ygrid_scale.gridstep = im->ygridstep;
        im->ygrid_scale.labfact = im->ylabfact;
    }
    return 1;
}

int draw_horizontal_grid(
    image_desc_t
    *im)
{
    int       i;
    double    scaledstep;
    char      graph_label[100];
    int       nlabels = 0;
    double    X0 = im->xorigin;
    double    X1 = im->xorigin + im->xsize;
    int       sgrid = (int) (im->minval / im->ygrid_scale.gridstep - 1);
    int       egrid = (int) (im->maxval / im->ygrid_scale.gridstep + 1);
    double    MaxY;
    double second_axis_magfact = 0;
    char *second_axis_symb = "";

    scaledstep =
        im->ygrid_scale.gridstep /
        (double) im->magfact * (double) im->viewfactor;
    MaxY = scaledstep * (double) egrid;
    for (i = sgrid; i <= egrid; i++) {
        double    Y0 = ytr(im,
                           im->ygrid_scale.gridstep * i);
        double    YN = ytr(im,
                           im->ygrid_scale.gridstep * (i + 1));

        if (floor(Y0 + 0.5) >=
            im->yorigin - im->ysize && floor(Y0 + 0.5) <= im->yorigin) {
            /* Make sure at least 2 grid labels are shown, even if it doesn't agree
               with the chosen settings. Add a label if required by settings, or if
               there is only one label so far and the next grid line is out of bounds. */
            if (i % im->ygrid_scale.labfact == 0
                || (nlabels == 1
                    && (YN < im->yorigin - im->ysize || YN > im->yorigin))) {
                if (im->symbol == ' ') {
                    if (im->extra_flags & ALTYGRID) {
                        sprintf(graph_label,
                                im->ygrid_scale.labfmt,
                                scaledstep * (double) i);
                    } else {
                        if (MaxY < 10) {
                            sprintf(graph_label, "%4.1f",
                                    scaledstep * (double) i);
                        } else {
                            sprintf(graph_label, "%4.0f",
                                    scaledstep * (double) i);
                        }
                    }
                } else {
                    char      sisym = (i == 0 ? ' ' : im->symbol);

                    if (im->extra_flags & ALTYGRID) {
                        sprintf(graph_label,
                                im->ygrid_scale.labfmt,
                                scaledstep * (double) i, sisym);
                    } else {
                        if (MaxY < 10) {
                            sprintf(graph_label, "%4.1f %c",
                                    scaledstep * (double) i, sisym);
                        } else {
                            sprintf(graph_label, "%4.0f %c",
                                    scaledstep * (double) i, sisym);
                        }
                    }
                }
                nlabels++;
                if (im->second_axis_scale != 0){
                        char graph_label_right[100];
                        double sval = im->ygrid_scale.gridstep*(double)i*im->second_axis_scale+im->second_axis_shift;
                        if (im->second_axis_format[0] == '\0'){
                            if (!second_axis_magfact){
                                double dummy = im->ygrid_scale.gridstep*(double)(sgrid+egrid)/2.0*im->second_axis_scale+im->second_axis_shift;
                                auto_scale(im,&dummy,&second_axis_symb,&second_axis_magfact);
                            }
                            sval /= second_axis_magfact;

                            if(MaxY < 10) {
                                sprintf(graph_label_right,"%5.1f %s",sval,second_axis_symb);
                            } else {
                                sprintf(graph_label_right,"%5.0f %s",sval,second_axis_symb);
                            }
                        }
                        else {
                           sprintf(graph_label_right,im->second_axis_format,sval,"");
                        }
                        gfx_text ( im,
                               X1+7, Y0,
                               im->graph_col[GRC_FONT],
                               im->text_prop[TEXT_PROP_AXIS].font_desc,
                               im->tabwidth,0.0, GFX_H_LEFT, GFX_V_CENTER,
                               graph_label_right );
                }

                gfx_text(im,
                         X0 -
                         im->
                         text_prop[TEXT_PROP_AXIS].
                         size, Y0,
                         im->graph_col[GRC_FONT],
                         im->
                         text_prop[TEXT_PROP_AXIS].
                         font_desc,
                         im->tabwidth, 0.0,
                         GFX_H_RIGHT, GFX_V_CENTER, graph_label);
                gfx_line(im, X0 - 2, Y0, X0, Y0,
                         MGRIDWIDTH, im->graph_col[GRC_MGRID]);
                gfx_line(im, X1, Y0, X1 + 2, Y0,
                         MGRIDWIDTH, im->graph_col[GRC_MGRID]);
                gfx_dashed_line(im, X0 - 2, Y0,
                                X1 + 2, Y0,
                                MGRIDWIDTH,
                                im->
                                graph_col
                                [GRC_MGRID],
                                im->grid_dash_on, im->grid_dash_off);
            } else if (!(im->extra_flags & NOMINOR)) {
                gfx_line(im,
                         X0 - 2, Y0,
                         X0, Y0, GRIDWIDTH, im->graph_col[GRC_GRID]);
                gfx_line(im, X1, Y0, X1 + 2, Y0,
                         GRIDWIDTH, im->graph_col[GRC_GRID]);
                gfx_dashed_line(im, X0 - 1, Y0,
                                X1 + 1, Y0,
                                GRIDWIDTH,
                                im->
                                graph_col[GRC_GRID],
                                im->grid_dash_on, im->grid_dash_off);
            }
        }
    }
    return 1;
}

/* this is frexp for base 10 */
double    frexp10(
    double,
    double *);
double frexp10(
    double x,
    double *e)
{
    double    mnt;
    int       iexp;

    iexp = floor(log((double)fabs(x)) / log((double)10));
    mnt = x / pow(10.0, iexp);
    if (mnt >= 10.0) {
        iexp++;
        mnt = x / pow(10.0, iexp);
    }
    *e = iexp;
    return mnt;
}


/* logaritmic horizontal grid */
int horizontal_log_grid(
    image_desc_t
    *im)
{
    double    yloglab[][10] = {
        {
         1.0, 10., 0.0, 0.0, 0.0, 0.0, 0.0,
         0.0, 0.0, 0.0}, {
                          1.0, 5.0, 10., 0.0, 0.0, 0.0, 0.0,
                          0.0, 0.0, 0.0}, {
                                           1.0, 2.0, 5.0, 7.0, 10., 0.0, 0.0,
                                           0.0, 0.0, 0.0}, {
                                                            1.0, 2.0, 4.0,
                                                            6.0, 8.0, 10.,
                                                            0.0,
                                                            0.0, 0.0, 0.0}, {
                                                                             1.0,
                                                                             2.0,
                                                                             3.0,
                                                                             4.0,
                                                                             5.0,
                                                                             6.0,
                                                                             7.0,
                                                                             8.0,
                                                                             9.0,
                                                                             10.},
        {
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0}  /* last line */
    };
    int       i, j, val_exp, min_exp;
    double    nex;      /* number of decades in data */
    double    logscale; /* scale in logarithmic space */
    int       exfrac = 1;   /* decade spacing */
    int       mid = -1; /* row in yloglab for major grid */
    double    mspac;    /* smallest major grid spacing (pixels) */
    int       flab;     /* first value in yloglab to use */
    double    value, tmp, pre_value;
    double    X0, X1, Y0;
    char      graph_label[100];

    nex = log10(im->maxval / im->minval);
    logscale = im->ysize / nex;
    /* major spacing for data with high dynamic range */
    while (logscale * exfrac < 3 * im->text_prop[TEXT_PROP_LEGEND].size) {
        if (exfrac == 1)
            exfrac = 3;
        else
            exfrac += 3;
    }

    /* major spacing for less dynamic data */
    do {
        /* search best row in yloglab */
        mid++;
        for (i = 0; yloglab[mid][i + 1] < 10.0; i++);
        mspac = logscale * log10(10.0 / yloglab[mid][i]);
    }
    while (mspac >
           2 * im->text_prop[TEXT_PROP_LEGEND].size && yloglab[mid][0] > 0);
    if (mid)
        mid--;
    /* find first value in yloglab */
    for (flab = 0;
         yloglab[mid][flab] < 10
         && frexp10(im->minval, &tmp) > yloglab[mid][flab]; flab++);
    if (yloglab[mid][flab] == 10.0) {
        tmp += 1.0;
        flab = 0;
    }
    val_exp = tmp;
    if (val_exp % exfrac)
        val_exp += abs(-val_exp % exfrac);
    X0 = im->xorigin;
    X1 = im->xorigin + im->xsize;
    /* draw grid */
    pre_value = DNAN;
    while (1) {

        value = yloglab[mid][flab] * pow(10.0, val_exp);
        if (AlmostEqual2sComplement(value, pre_value, 4))
            break;      /* it seems we are not converging */
        pre_value = value;
        Y0 = ytr(im, value);
        if (floor(Y0 + 0.5) <= im->yorigin - im->ysize)
            break;
        /* major grid line */
        gfx_line(im,
                 X0 - 2, Y0, X0, Y0, MGRIDWIDTH, im->graph_col[GRC_MGRID]);
        gfx_line(im, X1, Y0, X1 + 2, Y0,
                 MGRIDWIDTH, im->graph_col[GRC_MGRID]);
        gfx_dashed_line(im, X0 - 2, Y0,
                        X1 + 2, Y0,
                        MGRIDWIDTH,
                        im->
                        graph_col
                        [GRC_MGRID], im->grid_dash_on, im->grid_dash_off);
        /* label */
        if (im->extra_flags & FORCE_UNITS_SI) {
            int       scale;
            double    pvalue;
            char      symbol;

            scale = floor(val_exp / 3.0);
            if (value >= 1.0)
                pvalue = pow(10.0, val_exp % 3);
            else
                pvalue = pow(10.0, ((val_exp + 1) % 3) + 2);
            pvalue *= yloglab[mid][flab];
            if (((scale + si_symbcenter) < (int) sizeof(si_symbol))
                && ((scale + si_symbcenter) >= 0))
                symbol = si_symbol[scale + si_symbcenter];
            else
                symbol = '?';
            sprintf(graph_label, "%3.0f %c", pvalue, symbol);
        } else {
            sprintf(graph_label, "%3.0e", value);
        }
        if (im->second_axis_scale != 0){
                char graph_label_right[100];
                double sval = value*im->second_axis_scale+im->second_axis_shift;
                if (im->second_axis_format[0] == '\0'){
                        if (im->extra_flags & FORCE_UNITS_SI) {
                                double mfac = 1;
                                char   *symb = "";
                                auto_scale(im,&sval,&symb,&mfac);
                                sprintf(graph_label_right,"%4.0f %s", sval,symb);
                        }
                        else {
                                sprintf(graph_label_right,"%3.0e", sval);
                        }
                }
                else {
                      sprintf(graph_label_right,im->second_axis_format,sval,"");
                }

                gfx_text ( im,
                               X1+7, Y0,
                               im->graph_col[GRC_FONT],
                               im->text_prop[TEXT_PROP_AXIS].font_desc,
                               im->tabwidth,0.0, GFX_H_LEFT, GFX_V_CENTER,
                               graph_label_right );
        }

        gfx_text(im,
                 X0 -
                 im->
                 text_prop[TEXT_PROP_AXIS].
                 size, Y0,
                 im->graph_col[GRC_FONT],
                 im->
                 text_prop[TEXT_PROP_AXIS].
                 font_desc,
                 im->tabwidth, 0.0,
                 GFX_H_RIGHT, GFX_V_CENTER, graph_label);
        /* minor grid */
        if (mid < 4 && exfrac == 1) {
            /* find first and last minor line behind current major line
             * i is the first line and j tha last */
            if (flab == 0) {
                min_exp = val_exp - 1;
                for (i = 1; yloglab[mid][i] < 10.0; i++);
                i = yloglab[mid][i - 1] + 1;
                j = 10;
            } else {
                min_exp = val_exp;
                i = yloglab[mid][flab - 1] + 1;
                j = yloglab[mid][flab];
            }

            /* draw minor lines below current major line */
            for (; i < j; i++) {

                value = i * pow(10.0, min_exp);
                if (value < im->minval)
                    continue;
                Y0 = ytr(im, value);
                if (floor(Y0 + 0.5) <= im->yorigin - im->ysize)
                    break;
                /* draw lines */
                gfx_line(im,
                         X0 - 2, Y0,
                         X0, Y0, GRIDWIDTH, im->graph_col[GRC_GRID]);
                gfx_line(im, X1, Y0, X1 + 2, Y0,
                         GRIDWIDTH, im->graph_col[GRC_GRID]);
                gfx_dashed_line(im, X0 - 1, Y0,
                                X1 + 1, Y0,
                                GRIDWIDTH,
                                im->
                                graph_col[GRC_GRID],
                                im->grid_dash_on, im->grid_dash_off);
            }
        } else if (exfrac > 1) {
            for (i = val_exp - exfrac / 3 * 2; i < val_exp; i += exfrac / 3) {
                value = pow(10.0, i);
                if (value < im->minval)
                    continue;
                Y0 = ytr(im, value);
                if (floor(Y0 + 0.5) <= im->yorigin - im->ysize)
                    break;
                /* draw lines */
                gfx_line(im,
                         X0 - 2, Y0,
                         X0, Y0, GRIDWIDTH, im->graph_col[GRC_GRID]);
                gfx_line(im, X1, Y0, X1 + 2, Y0,
                         GRIDWIDTH, im->graph_col[GRC_GRID]);
                gfx_dashed_line(im, X0 - 1, Y0,
                                X1 + 1, Y0,
                                GRIDWIDTH,
                                im->
                                graph_col[GRC_GRID],
                                im->grid_dash_on, im->grid_dash_off);
            }
        }

        /* next decade */
        if (yloglab[mid][++flab] == 10.0) {
            flab = 0;
            val_exp += exfrac;
        }
    }

    /* draw minor lines after highest major line */
    if (mid < 4 && exfrac == 1) {
        /* find first and last minor line below current major line
         * i is the first line and j tha last */
        if (flab == 0) {
            min_exp = val_exp - 1;
            for (i = 1; yloglab[mid][i] < 10.0; i++);
            i = yloglab[mid][i - 1] + 1;
            j = 10;
        } else {
            min_exp = val_exp;
            i = yloglab[mid][flab - 1] + 1;
            j = yloglab[mid][flab];
        }

        /* draw minor lines below current major line */
        for (; i < j; i++) {

            value = i * pow(10.0, min_exp);
            if (value < im->minval)
                continue;
            Y0 = ytr(im, value);
            if (floor(Y0 + 0.5) <= im->yorigin - im->ysize)
                break;
            /* draw lines */
            gfx_line(im,
                     X0 - 2, Y0, X0, Y0, GRIDWIDTH, im->graph_col[GRC_GRID]);
            gfx_line(im, X1, Y0, X1 + 2, Y0,
                     GRIDWIDTH, im->graph_col[GRC_GRID]);
            gfx_dashed_line(im, X0 - 1, Y0,
                            X1 + 1, Y0,
                            GRIDWIDTH,
                            im->
                            graph_col[GRC_GRID],
                            im->grid_dash_on, im->grid_dash_off);
        }
    }
    /* fancy minor gridlines */
    else if (exfrac > 1) {
        for (i = val_exp - exfrac / 3 * 2; i < val_exp; i += exfrac / 3) {
            value = pow(10.0, i);
            if (value < im->minval)
                continue;
            Y0 = ytr(im, value);
            if (floor(Y0 + 0.5) <= im->yorigin - im->ysize)
                break;
            /* draw lines */
            gfx_line(im,
                     X0 - 2, Y0, X0, Y0, GRIDWIDTH, im->graph_col[GRC_GRID]);
            gfx_line(im, X1, Y0, X1 + 2, Y0,
                     GRIDWIDTH, im->graph_col[GRC_GRID]);
            gfx_dashed_line(im, X0 - 1, Y0,
                            X1 + 1, Y0,
                            GRIDWIDTH,
                            im->
                            graph_col[GRC_GRID],
                            im->grid_dash_on, im->grid_dash_off);
        }
    }

    return 1;
}


void vertical_grid(
    image_desc_t *im)
{
    int       xlab_sel; /* which sort of label and grid ? */
    time_t    ti, tilab, timajor;
    long      factor;
    char      graph_label[100];
    double    X0, Y0, Y1;   /* points for filled graph and more */
    struct tm tm;

    /* the type of time grid is determined by finding
       the number of seconds per pixel in the graph */
    if (im->xlab_user.minsec == -1) {
        factor = (im->end - im->start) / im->xsize;
        xlab_sel = 0;
        while (xlab[xlab_sel + 1].minsec !=
               -1 && xlab[xlab_sel + 1].minsec <= factor) {
            xlab_sel++;
        }               /* pick the last one */
        while (xlab[xlab_sel - 1].minsec ==
               xlab[xlab_sel].minsec
               && xlab[xlab_sel].length > (im->end - im->start)) {
            xlab_sel--;
        }               /* go back to the smallest size */
        im->xlab_user.gridtm = xlab[xlab_sel].gridtm;
        im->xlab_user.gridst = xlab[xlab_sel].gridst;
        im->xlab_user.mgridtm = xlab[xlab_sel].mgridtm;
        im->xlab_user.mgridst = xlab[xlab_sel].mgridst;
        im->xlab_user.labtm = xlab[xlab_sel].labtm;
        im->xlab_user.labst = xlab[xlab_sel].labst;
        im->xlab_user.precis = xlab[xlab_sel].precis;
        im->xlab_user.stst = xlab[xlab_sel].stst;
    }

    /* y coords are the same for every line ... */
    Y0 = im->yorigin;
    Y1 = im->yorigin - im->ysize;
    /* paint the minor grid */
    if (!(im->extra_flags & NOMINOR)) {
        for (ti = find_first_time(im->start,
                                  im->
                                  xlab_user.
                                  gridtm,
                                  im->
                                  xlab_user.
                                  gridst),
             timajor =
             find_first_time(im->start,
                             im->xlab_user.
                             mgridtm,
                             im->xlab_user.
                             mgridst);
             ti < im->end && ti != -1;
             ti =
             find_next_time(ti, im->xlab_user.gridtm, im->xlab_user.gridst)
            ) {
            /* are we inside the graph ? */
            if (ti < im->start || ti > im->end)
                continue;
            while (timajor < ti && timajor != -1) {
                timajor = find_next_time(timajor,
                                         im->
                                         xlab_user.
                                         mgridtm, im->xlab_user.mgridst);
            }
            if (timajor == -1) break; /* fail in case of problems with time increments */
            if (ti == timajor)
                continue;   /* skip as falls on major grid line */
            X0 = xtr(im, ti);
            gfx_line(im, X0, Y1 - 2, X0, Y1,
                     GRIDWIDTH, im->graph_col[GRC_GRID]);
            gfx_line(im, X0, Y0, X0, Y0 + 2,
                     GRIDWIDTH, im->graph_col[GRC_GRID]);
            gfx_dashed_line(im, X0, Y0 + 1, X0,
                            Y1 - 1, GRIDWIDTH,
                            im->
                            graph_col[GRC_GRID],
                            im->grid_dash_on, im->grid_dash_off);
        }
    }

    /* paint the major grid */
    for (ti = find_first_time(im->start,
                              im->
                              xlab_user.
                              mgridtm,
                              im->
                              xlab_user.
                              mgridst);
         ti < im->end && ti != -1;
         ti = find_next_time(ti, im->xlab_user.mgridtm, im->xlab_user.mgridst)
        ) {
        /* are we inside the graph ? */
        if (ti < im->start || ti > im->end)
            continue;
        X0 = xtr(im, ti);
        gfx_line(im, X0, Y1 - 2, X0, Y1,
                 MGRIDWIDTH, im->graph_col[GRC_MGRID]);
        gfx_line(im, X0, Y0, X0, Y0 + 3,
                 MGRIDWIDTH, im->graph_col[GRC_MGRID]);
        gfx_dashed_line(im, X0, Y0 + 3, X0,
                        Y1 - 2, MGRIDWIDTH,
                        im->
                        graph_col
                        [GRC_MGRID], im->grid_dash_on, im->grid_dash_off);
    }
    /* paint the labels below the graph */
    for (ti =
         find_first_time(im->start -
                         im->xlab_user.
                         precis / 2,
                         im->xlab_user.
                         labtm,
                         im->xlab_user.
                         labst);
         (ti <=
         im->end -
         im->xlab_user.precis / 2) && ti != -1;
         ti = find_next_time(ti, im->xlab_user.labtm, im->xlab_user.labst)
        ) {
        tilab = ti + im->xlab_user.precis / 2;  /* correct time for the label */
        /* are we inside the graph ? */
        if (tilab < im->start || tilab > im->end)
            continue;
#if HAVE_STRFTIME
        localtime_r(&tilab, &tm);
        strftime(graph_label, 99, im->xlab_user.stst, &tm);
#else
# error "your libc has no strftime I guess we'll abort the exercise here."
#endif
        gfx_text(im,
                 xtr(im, tilab),
                 Y0 + 3,
                 im->graph_col[GRC_FONT],
                 im->
                 text_prop[TEXT_PROP_AXIS].
                 font_desc,
                 im->tabwidth, 0.0,
                 GFX_H_CENTER, GFX_V_TOP, graph_label);
    }

}


void axis_paint(
    image_desc_t *im)
{
    /* draw x and y axis */
    /* gfx_line ( im->canvas, im->xorigin+im->xsize,im->yorigin,
       im->xorigin+im->xsize,im->yorigin-im->ysize,
       GRIDWIDTH, im->graph_col[GRC_AXIS]);

       gfx_line ( im->canvas, im->xorigin,im->yorigin-im->ysize,
       im->xorigin+im->xsize,im->yorigin-im->ysize,
       GRIDWIDTH, im->graph_col[GRC_AXIS]); */

    gfx_line(im, im->xorigin - 4,
             im->yorigin,
             im->xorigin + im->xsize +
             4, im->yorigin, MGRIDWIDTH, im->graph_col[GRC_AXIS]);
    gfx_line(im, im->xorigin,
             im->yorigin + 4,
             im->xorigin,
             im->yorigin - im->ysize -
             4, MGRIDWIDTH, im->graph_col[GRC_AXIS]);
    /* arrow for X and Y axis direction */
    gfx_new_area(im, im->xorigin + im->xsize + 2, im->yorigin - 3, im->xorigin + im->xsize + 2, im->yorigin + 3, im->xorigin + im->xsize + 7, im->yorigin,  /* horyzontal */
                 im->graph_col[GRC_ARROW]);
    gfx_close_path(im);
    gfx_new_area(im, im->xorigin - 3, im->yorigin - im->ysize - 2, im->xorigin + 3, im->yorigin - im->ysize - 2, im->xorigin, im->yorigin - im->ysize - 7,  /* vertical */
                 im->graph_col[GRC_ARROW]);
    gfx_close_path(im);
    if (im->second_axis_scale != 0){
       gfx_line ( im, im->xorigin+im->xsize,im->yorigin+4,
                         im->xorigin+im->xsize,im->yorigin-im->ysize-4,
                         MGRIDWIDTH, im->graph_col[GRC_AXIS]);
       gfx_new_area ( im,
                   im->xorigin+im->xsize-2,  im->yorigin-im->ysize-2,
                   im->xorigin+im->xsize+3,  im->yorigin-im->ysize-2,
                   im->xorigin+im->xsize,    im->yorigin-im->ysize-7, /* LINEOFFSET */
                   im->graph_col[GRC_ARROW]);
       gfx_close_path(im);
    }

}

void grid_paint(
    image_desc_t *im)
{
    long      i;
    int       res = 0;
    double    X0, Y0;   /* points for filled graph and more */
    struct gfx_color_t water_color;

    if (im->draw_3d_border > 0) {
	    /* draw 3d border */
	    i = im->draw_3d_border;
	    gfx_new_area(im, 0, im->yimg,
			 i, im->yimg - i, i, i, im->graph_col[GRC_SHADEA]);
	    gfx_add_point(im, im->ximg - i, i);
	    gfx_add_point(im, im->ximg, 0);
	    gfx_add_point(im, 0, 0);
	    gfx_close_path(im);
	    gfx_new_area(im, i, im->yimg - i,
			 im->ximg - i,
			 im->yimg - i, im->ximg - i, i, im->graph_col[GRC_SHADEB]);
	    gfx_add_point(im, im->ximg, 0);
	    gfx_add_point(im, im->ximg, im->yimg);
	    gfx_add_point(im, 0, im->yimg);
	    gfx_close_path(im);
    }
    if (im->draw_x_grid == 1)
        vertical_grid(im);
    if (im->draw_y_grid == 1) {
        if (im->logarithmic) {
            res = horizontal_log_grid(im);
        } else {
            res = draw_horizontal_grid(im);
        }

        /* dont draw horizontal grid if there is no min and max val */
        if (!res) {
            char     *nodata = "No Data found";

            gfx_text(im, im->ximg / 2,
                     (2 * im->yorigin -
                      im->ysize) / 2,
                     im->graph_col[GRC_FONT],
                     im->
                     text_prop[TEXT_PROP_AXIS].
                     font_desc,
                     im->tabwidth, 0.0,
                     GFX_H_CENTER, GFX_V_CENTER, nodata);
        }
    }

    /* yaxis unit description */
    if (im->ylegend[0] != '\0'){
        gfx_text(im,
                 im->xOriginLegendY+10,
                 im->yOriginLegendY,
                 im->graph_col[GRC_FONT],
                 im->
                 text_prop[TEXT_PROP_UNIT].
                 font_desc,
                 im->tabwidth,
                 RRDGRAPH_YLEGEND_ANGLE, GFX_H_CENTER, GFX_V_CENTER, im->ylegend);

    }
    if (im->second_axis_legend[0] != '\0'){
            gfx_text( im,
                  im->xOriginLegendY2+10,
                  im->yOriginLegendY2,
                  im->graph_col[GRC_FONT],
                  im->text_prop[TEXT_PROP_UNIT].font_desc,
                  im->tabwidth,
                  RRDGRAPH_YLEGEND_ANGLE,
                  GFX_H_CENTER, GFX_V_CENTER,
                  im->second_axis_legend);
    }

    /* graph title */
    gfx_text(im,
             im->xOriginTitle, im->yOriginTitle+6,
             im->graph_col[GRC_FONT],
             im->
             text_prop[TEXT_PROP_TITLE].
             font_desc,
             im->tabwidth, 0.0, GFX_H_CENTER, GFX_V_TOP, im->title);
    /* rrdtool 'logo' */
    if (!(im->extra_flags & NO_RRDTOOL_TAG)){
        water_color = im->graph_col[GRC_FONT];
        water_color.alpha = 0.3;
        double xpos = im->legendposition == EAST ? im->xOriginLegendY : im->ximg - 4;
        gfx_text(im, xpos, 5,
                 water_color,
                 im->
                 text_prop[TEXT_PROP_WATERMARK].
                 font_desc, im->tabwidth,
                 -90, GFX_H_LEFT, GFX_V_TOP, "RRDTOOL / TOBI OETIKER");
    }
    /* graph watermark */
    if (im->watermark[0] != '\0') {
        water_color = im->graph_col[GRC_FONT];
        water_color.alpha = 0.3;
        gfx_text(im,
                 im->ximg / 2, im->yimg - 6,
                 water_color,
                 im->
                 text_prop[TEXT_PROP_WATERMARK].
                 font_desc, im->tabwidth, 0,
                 GFX_H_CENTER, GFX_V_BOTTOM, im->watermark);
    }

    /* graph labels */
    if (!(im->extra_flags & NOLEGEND) && !(im->extra_flags & ONLY_GRAPH)) {
        for (i = 0; i < im->gdes_c; i++) {
            if (im->gdes[i].legend[0] == '\0')
                continue;
            /* im->gdes[i].leg_y is the bottom of the legend */
            X0 = im->xOriginLegend + im->gdes[i].leg_x;
            Y0 = im->legenddirection == TOP_DOWN ? im->yOriginLegend + im->gdes[i].leg_y : im->yOriginLegend + im->legendheight - im->gdes[i].leg_y;
            gfx_text(im, X0, Y0,
                     im->graph_col[GRC_FONT],
                     im->
                     text_prop
                     [TEXT_PROP_LEGEND].font_desc,
                     im->tabwidth, 0.0,
                     GFX_H_LEFT, GFX_V_BOTTOM, im->gdes[i].legend);
            /* The legend for GRAPH items starts with "M " to have
               enough space for the box */
            if (im->gdes[i].gf != GF_PRINT &&
                im->gdes[i].gf != GF_GPRINT && im->gdes[i].gf != GF_COMMENT) {
                double    boxH, boxV;
                double    X1, Y1;

                boxH = gfx_get_text_width(im, 0,
                                          im->
                                          text_prop
                                          [TEXT_PROP_LEGEND].
                                          font_desc,
                                          im->tabwidth, "o") * 1.2;
                boxV = boxH;
                /* shift the box up a bit */
                Y0 -= boxV * 0.4;

        if (im->dynamic_labels && im->gdes[i].gf == GF_HRULE) { /* [-] */ 
			cairo_save(im->cr);
			cairo_new_path(im->cr);
			cairo_set_line_width(im->cr, 1.0);
			gfx_line(im,
				X0, Y0 - boxV / 2,
				X0 + boxH, Y0 - boxV / 2,
				1.0, im->gdes[i].col);
            		gfx_close_path(im);
		} else if (im->dynamic_labels && im->gdes[i].gf == GF_VRULE) { /* [|] */
			cairo_save(im->cr);
			cairo_new_path(im->cr);
			cairo_set_line_width(im->cr, 1.0);
			gfx_line(im,
				X0 + boxH / 2, Y0,
				X0 + boxH / 2, Y0 - boxV,
				1.0, im->gdes[i].col);
            		gfx_close_path(im);
		} else if (im->dynamic_labels && im->gdes[i].gf == GF_LINE) { /* [/] */
			cairo_save(im->cr);
			cairo_new_path(im->cr);
			cairo_set_line_width(im->cr, im->gdes[i].linewidth);
			gfx_line(im,
				X0, Y0,
				X0 + boxH, Y0 - boxV,
				im->gdes[i].linewidth, im->gdes[i].col);
            		gfx_close_path(im);
		} else {
		/* make sure transparent colors show up the same way as in the graph */
			gfx_new_area(im,
				     X0, Y0 - boxV,
				     X0, Y0, X0 + boxH, Y0, im->graph_col[GRC_BACK]);
			gfx_add_point(im, X0 + boxH, Y0 - boxV);
			gfx_close_path(im);
			gfx_new_area(im, X0, Y0 - boxV, X0,
				     Y0, X0 + boxH, Y0, im->gdes[i].col);
			gfx_add_point(im, X0 + boxH, Y0 - boxV);
			gfx_close_path(im);
			cairo_save(im->cr);
			cairo_new_path(im->cr);
			cairo_set_line_width(im->cr, 1.0);
			X1 = X0 + boxH;
			Y1 = Y0 - boxV;
			gfx_line_fit(im, &X0, &Y0);
			gfx_line_fit(im, &X1, &Y1);
			cairo_move_to(im->cr, X0, Y0);
			cairo_line_to(im->cr, X1, Y0);
			cairo_line_to(im->cr, X1, Y1);
			cairo_line_to(im->cr, X0, Y1);
			cairo_close_path(im->cr);
			cairo_set_source_rgba(im->cr,
					      im->graph_col[GRC_FRAME].red,
					      im->graph_col[GRC_FRAME].green,
					      im->graph_col[GRC_FRAME].blue,
					      im->graph_col[GRC_FRAME].alpha);
		}
                if (im->gdes[i].dash) {
                    /* make box borders in legend dashed if the graph is dashed */
                    double    dashes[] = {
                        3.0
                    };
                    cairo_set_dash(im->cr, dashes, 1, 0.0);
                }
                cairo_stroke(im->cr);
                cairo_restore(im->cr);
            }
        }
    }
}


/*****************************************************
 * lazy check make sure we rely need to create this graph
 *****************************************************/

int lazy_check(
    image_desc_t *im)
{
    FILE     *fd = NULL;
    int       size = 1;
    struct stat imgstat;

    if (im->lazy == 0)
        return 0;       /* no lazy option */
    if (strlen(im->graphfile) == 0)
        return 0;       /* inmemory option */
    if (stat(im->graphfile, &imgstat) != 0)
        return 0;       /* can't stat */
    /* one pixel in the existing graph is more then what we would
       change here ... */
    if (time(NULL) - imgstat.st_mtime > (im->end - im->start) / im->xsize)
        return 0;
    if ((fd = fopen(im->graphfile, "rb")) == NULL)
        return 0;       /* the file does not exist */
    switch (im->imgformat) {
    case IF_PNG:
        size = PngSize(fd, &(im->ximg), &(im->yimg));
        break;
    default:
        size = 1;
    }
    fclose(fd);
    return size;
}


int graph_size_location(
    image_desc_t
    *im,
    int elements)
{
    /* The actual size of the image to draw is determined from
     ** several sources.  The size given on the command line is
     ** the graph area but we need more as we have to draw labels
     ** and other things outside the graph area. If the option
     ** --full-size-mode is selected the size defines the total
     ** image size and the size available for the graph is
     ** calculated.
     */

    /** +---+-----------------------------------+
     ** | y |...............graph title.........|
     ** |   +---+-------------------------------+
     ** | a | y |                               |
     ** | x |   |                               |
     ** | i | a |                               |
     ** | s | x |       main graph area         |
     ** |   | i |                               |
     ** | t | s |                               |
     ** | i |   |                               |
     ** | t | l |                               |
     ** | l | b +-------------------------------+
     ** | e | l |       x axis labels           |
     ** +---+---+-------------------------------+
     ** |....................legends............|
     ** +---------------------------------------+
     ** |                   watermark           |
     ** +---------------------------------------+
     */

    int       Xvertical = 0, Xvertical2 = 0, Ytitle =
        0, Xylabel = 0, Xmain = 0, Ymain =
        0, Yxlabel = 0, Xspacing = 15, Yspacing = 15, Ywatermark = 4;

    // no legends and no the shall be plotted it's easy
    if (im->extra_flags & ONLY_GRAPH) {
        im->xorigin = 0;
        im->ximg = im->xsize;
        im->yimg = im->ysize;
        im->yorigin = im->ysize;
        xtr(im, 0);
        ytr(im, DNAN);
        return 0;
    }

    if(im->watermark[0] != '\0') {
        Ywatermark = im->text_prop[TEXT_PROP_WATERMARK].size * 2;
    }

    // calculate the width of the left vertical legend
    if (im->ylegend[0] != '\0') {
        Xvertical = im->text_prop[TEXT_PROP_UNIT].size * 2;
    }

    // calculate the width of the right vertical legend
    if (im->second_axis_legend[0] != '\0') {
        Xvertical2 = im->text_prop[TEXT_PROP_UNIT].size * 2;
    }
    else{
        Xvertical2 = Xspacing;
    }

    if (im->title[0] != '\0') {
        /* The title is placed "inbetween" two text lines so it
         ** automatically has some vertical spacing.  The horizontal
         ** spacing is added here, on each side.
         */
        /* if necessary, reduce the font size of the title until it fits the image width */
        Ytitle = im->text_prop[TEXT_PROP_TITLE].size * 2.6 + 10;
    }
    else{
        // we have no title; get a little clearing from the top
        Ytitle = Yspacing;
    }

    if (elements) {
        if (im->draw_x_grid) {
            // calculate the height of the horizontal labelling
            Yxlabel = im->text_prop[TEXT_PROP_AXIS].size * 2.5;
        }
        if (im->draw_y_grid || im->forceleftspace) {
            // calculate the width of the vertical labelling
            Xylabel =
                gfx_get_text_width(im, 0,
                                   im->text_prop[TEXT_PROP_AXIS].font_desc,
                                   im->tabwidth, "0") * im->unitslength;
        }
    }

    // add some space to the labelling
    Xylabel += Xspacing;

    /* If the legend is printed besides the graph the width has to be
     ** calculated first. Placing the legend north or south of the
     ** graph requires the width calculation first, so the legend is
     ** skipped for the moment.
     */
    im->legendheight = 0;
    im->legendwidth = 0;
    if (!(im->extra_flags & NOLEGEND)) {
        if(im->legendposition == WEST || im->legendposition == EAST){
            if (leg_place(im, 1) == -1){
                return -1;
            }
        }
    }

    if (im->extra_flags & FULL_SIZE_MODE) {

        /* The actual size of the image to draw has been determined by the user.
         ** The graph area is the space remaining after accounting for the legend,
         ** the watermark, the axis labels, and the title.
         */
        im->ximg = im->xsize;
        im->yimg = im->ysize;
        Xmain = im->ximg;
        Ymain = im->yimg;

        /* Now calculate the total size.  Insert some spacing where
           desired.  im->xorigin and im->yorigin need to correspond
           with the lower left corner of the main graph area or, if
           this one is not set, the imaginary box surrounding the
           pie chart area. */
        /* Initial size calculation for the main graph area */

        Xmain -= Xylabel;// + Xspacing;
        if((im->legendposition == WEST || im->legendposition == EAST) && !(im->extra_flags & NOLEGEND) ){
            Xmain -= im->legendwidth;// + Xspacing;
        }
        if (im->second_axis_scale != 0){
            Xmain -= Xylabel;
        }
        if (!(im->extra_flags & NO_RRDTOOL_TAG)){
            Xmain -= Xspacing;
        }

        Xmain -= Xvertical + Xvertical2;

        /* limit the remaining space to 0 */
        if(Xmain < 1){
            Xmain = 1;
        }
        im->xsize = Xmain;

        /* Putting the legend north or south, the height can now be calculated */
        if (!(im->extra_flags & NOLEGEND)) {
            if(im->legendposition == NORTH || im->legendposition == SOUTH){
                im->legendwidth = im->ximg;
                if (leg_place(im, 0) == -1){
                    return -1;
                }
            }
        }

        if( (im->legendposition == NORTH || im->legendposition == SOUTH)  && !(im->extra_flags & NOLEGEND) ){
            Ymain -=  Yxlabel + im->legendheight;
        }
        else{
            Ymain -= Yxlabel;
        }

        /* reserve space for the title *or* some padding above the graph */
        Ymain -= Ytitle;

            /* reserve space for padding below the graph */
        if (im->extra_flags & NOLEGEND) {
            Ymain -= 0.5*Yspacing;
        }

        if (im->watermark[0] != '\0') {
            Ymain -= Ywatermark;
        }
        /* limit the remaining height to 0 */
        if(Ymain < 1){
            Ymain = 1;
        }
        im->ysize = Ymain;
    } else {            /* dimension options -width and -height refer to the dimensions of the main graph area */

        /* The actual size of the image to draw is determined from
         ** several sources.  The size given on the command line is
         ** the graph area but we need more as we have to draw labels
         ** and other things outside the graph area.
         */

        if (elements) {
            Xmain = im->xsize; // + Xspacing;
            Ymain = im->ysize;
        }

        im->ximg = Xmain + Xylabel;
        if (!(im->extra_flags & NO_RRDTOOL_TAG)){
            im->ximg += Xspacing;
        }

        if( (im->legendposition == WEST || im->legendposition == EAST) && !(im->extra_flags & NOLEGEND) ){
            im->ximg += im->legendwidth;// + Xspacing;
        }
        if (im->second_axis_scale != 0){
            im->ximg += Xylabel;
        }

        im->ximg += Xvertical + Xvertical2;

        if (!(im->extra_flags & NOLEGEND)) {
            if(im->legendposition == NORTH || im->legendposition == SOUTH){
                im->legendwidth = im->ximg;
                if (leg_place(im, 0) == -1){
                    return -1;
                }
            }
        }

        im->yimg = Ymain + Yxlabel;
        if( (im->legendposition == NORTH || im->legendposition == SOUTH)  && !(im->extra_flags & NOLEGEND) ){
             im->yimg += im->legendheight;
        }

        /* reserve space for the title *or* some padding above the graph */
        if (Ytitle) {
            im->yimg += Ytitle;
        } else {
            im->yimg += 1.5 * Yspacing;
        }
        /* reserve space for padding below the graph */
        if (im->extra_flags & NOLEGEND) {
            im->yimg += 0.5*Yspacing;
        }

        if (im->watermark[0] != '\0') {
            im->yimg += Ywatermark;
        }
    }


    /* In case of putting the legend in west or east position the first
     ** legend calculation might lead to wrong positions if some items
     ** are not aligned on the left hand side (e.g. centered) as the
     ** legendwidth wight have been increased after the item was placed.
     ** In this case the positions have to be recalculated.
     */
    if (!(im->extra_flags & NOLEGEND)) {
        if(im->legendposition == WEST || im->legendposition == EAST){
            if (leg_place(im, 0) == -1){
                return -1;
            }
        }
    }

    /* After calculating all dimensions
     ** it is now possible to calculate
     ** all offsets.
     */
    switch(im->legendposition){
        case NORTH:
            im->xOriginTitle   = (im->ximg / 2);
            im->yOriginTitle   = 0;

            im->xOriginLegend  = 0;
            im->yOriginLegend  = Ytitle;

            im->xOriginLegendY = 0;
            im->yOriginLegendY = Ytitle + im->legendheight + (Ymain / 2) + Yxlabel;

            im->xorigin        = Xvertical + Xylabel;
            im->yorigin        = Ytitle + im->legendheight + Ymain;

            im->xOriginLegendY2 = Xvertical + Xylabel + Xmain;
            if (im->second_axis_scale != 0){
                im->xOriginLegendY2 += Xylabel;
            }
            im->yOriginLegendY2 = Ytitle + im->legendheight + (Ymain / 2) + Yxlabel;

            break;

        case WEST:
            im->xOriginTitle   = im->legendwidth + im->xsize / 2;
            im->yOriginTitle   = 0;

            im->xOriginLegend  = 0;
            im->yOriginLegend  = Ytitle;

            im->xOriginLegendY = im->legendwidth;
            im->yOriginLegendY = Ytitle + (Ymain / 2);

            im->xorigin        = im->legendwidth + Xvertical + Xylabel;
            im->yorigin        = Ytitle + Ymain;

            im->xOriginLegendY2 = im->legendwidth + Xvertical + Xylabel + Xmain;
            if (im->second_axis_scale != 0){
                im->xOriginLegendY2 += Xylabel;
            }
            im->yOriginLegendY2 = Ytitle + (Ymain / 2);

            break;

        case SOUTH:
            im->xOriginTitle   = im->ximg / 2;
            im->yOriginTitle   = 0;

            im->xOriginLegend  = 0;
            im->yOriginLegend  = Ytitle + Ymain + Yxlabel;

            im->xOriginLegendY = 0;
            im->yOriginLegendY = Ytitle + (Ymain / 2);

            im->xorigin        = Xvertical + Xylabel;
            im->yorigin        = Ytitle + Ymain;

            im->xOriginLegendY2 = Xvertical + Xylabel + Xmain;
            if (im->second_axis_scale != 0){
                im->xOriginLegendY2 += Xylabel;
            }
            im->yOriginLegendY2 = Ytitle + (Ymain / 2);

            break;

        case EAST:
            im->xOriginTitle   = im->xsize / 2;
            im->yOriginTitle   = 0;

            im->xOriginLegend  = Xvertical + Xylabel + Xmain + Xvertical2;
            if (im->second_axis_scale != 0){
                im->xOriginLegend += Xylabel;
            }
            im->yOriginLegend  = Ytitle;

            im->xOriginLegendY = 0;
            im->yOriginLegendY = Ytitle + (Ymain / 2);

            im->xorigin        = Xvertical + Xylabel;
            im->yorigin        = Ytitle + Ymain;

            im->xOriginLegendY2 = Xvertical + Xylabel + Xmain;
            if (im->second_axis_scale != 0){
                im->xOriginLegendY2 += Xylabel;
            }
            im->yOriginLegendY2 = Ytitle + (Ymain / 2);

            if (!(im->extra_flags & NO_RRDTOOL_TAG)){
                im->xOriginTitle    += Xspacing;
                im->xOriginLegend   += Xspacing;
                im->xOriginLegendY  += Xspacing;
                im->xorigin         += Xspacing;
                im->xOriginLegendY2 += Xspacing;
            }
            break;
    }

    xtr(im, 0);
    ytr(im, DNAN);
    return 0;
}

static cairo_status_t cairo_output(
    void *closure,
    const unsigned char
    *data,
    unsigned int length)
{
    image_desc_t *im = (image_desc_t*)closure;

    im->rendered_image =
        (unsigned char*)realloc(im->rendered_image, im->rendered_image_size + length);
    if (im->rendered_image == NULL)
        return CAIRO_STATUS_WRITE_ERROR;
    memcpy(im->rendered_image + im->rendered_image_size, data, length);
    im->rendered_image_size += length;
    return CAIRO_STATUS_SUCCESS;
}

/* draw that picture thing ... */
int graph_paint(
    image_desc_t *im)
{
    int       i, ii;
    int       lazy = lazy_check(im);
    double    areazero = 0.0;
    graph_desc_t *lastgdes = NULL;
    rrd_infoval_t info;

//    PangoFontMap *font_map = pango_cairo_font_map_get_default();

    /* pull the data from the rrd files ... */
    if (data_fetch(im) == -1)
        return -1;
    /* evaluate VDEF and CDEF operations ... */
    if (data_calc(im) == -1)
        return -1;
    /* calculate and PRINT and GPRINT definitions. We have to do it at
     * this point because it will affect the length of the legends
     * if there are no graph elements (i==0) we stop here ...
     * if we are lazy, try to quit ...
     */
    i = print_calc(im);
    if (i < 0)
        return -1;

    /* if we want and can be lazy ... quit now */
    if (i == 0)
        return 0;

/**************************************************************
 *** Calculating sizes and locations became a bit confusing ***
 *** so I moved this into a separate function.              ***
 **************************************************************/
    if (graph_size_location(im, i) == -1)
        return -1;

    info.u_cnt = im->xorigin;
    grinfo_push(im, sprintf_alloc("graph_left"), RD_I_CNT, info);
    info.u_cnt = im->yorigin - im->ysize;
    grinfo_push(im, sprintf_alloc("graph_top"), RD_I_CNT, info);
    info.u_cnt = im->xsize;
    grinfo_push(im, sprintf_alloc("graph_width"), RD_I_CNT, info);
    info.u_cnt = im->ysize;
    grinfo_push(im, sprintf_alloc("graph_height"), RD_I_CNT, info);
    info.u_cnt = im->ximg;
    grinfo_push(im, sprintf_alloc("image_width"), RD_I_CNT, info);
    info.u_cnt = im->yimg;
    grinfo_push(im, sprintf_alloc("image_height"), RD_I_CNT, info);
    info.u_cnt = im->start;
    grinfo_push(im, sprintf_alloc("graph_start"), RD_I_CNT, info);
    info.u_cnt = im->end;
    grinfo_push(im, sprintf_alloc("graph_end"), RD_I_CNT, info);

    /* if we want and can be lazy ... quit now */
    if (lazy)
        return 0;

    /* get actual drawing data and find min and max values */
    if (data_proc(im) == -1)
        return -1;
    if (!im->logarithmic) {
        si_unit(im);
    }

    /* identify si magnitude Kilo, Mega Giga ? */
    if (!im->rigid && !im->logarithmic)
        expand_range(im);   /* make sure the upper and lower limit are
                               sensible values */

    info.u_val = im->minval;
    grinfo_push(im, sprintf_alloc("value_min"), RD_I_VAL, info);
    info.u_val = im->maxval;
    grinfo_push(im, sprintf_alloc("value_max"), RD_I_VAL, info);


    if (!calc_horizontal_grid(im))
        return -1;
    /* reset precalc */
    ytr(im, DNAN);
/*   if (im->gridfit)
     apply_gridfit(im); */
    /* the actual graph is created by going through the individual
       graph elements and then drawing them */
    cairo_surface_destroy(im->surface);
    switch (im->imgformat) {
    case IF_PNG:
        im->surface =
            cairo_image_surface_create(CAIRO_FORMAT_ARGB32,
                                       im->ximg * im->zoom,
                                       im->yimg * im->zoom);
        break;
    case IF_PDF:
        im->gridfit = 0;
        im->surface = strlen(im->graphfile)
            ? cairo_pdf_surface_create(im->graphfile, im->ximg * im->zoom,
                                       im->yimg * im->zoom)
            : cairo_pdf_surface_create_for_stream
            (&cairo_output, im, im->ximg * im->zoom, im->yimg * im->zoom);
        break;
    case IF_EPS:
        im->gridfit = 0;
        im->surface = strlen(im->graphfile)
            ?
            cairo_ps_surface_create(im->graphfile, im->ximg * im->zoom,
                                    im->yimg * im->zoom)
            : cairo_ps_surface_create_for_stream
            (&cairo_output, im, im->ximg * im->zoom, im->yimg * im->zoom);
        break;
    case IF_SVG:
        im->gridfit = 0;
        im->surface = strlen(im->graphfile)
            ?
            cairo_svg_surface_create(im->
                                     graphfile,
                                     im->ximg * im->zoom, im->yimg * im->zoom)
            : cairo_svg_surface_create_for_stream
            (&cairo_output, im, im->ximg * im->zoom, im->yimg * im->zoom);
        cairo_svg_surface_restrict_to_version
            (im->surface, CAIRO_SVG_VERSION_1_1);
        break;
    };
    cairo_destroy(im->cr);
    im->cr = cairo_create(im->surface);
    cairo_set_antialias(im->cr, im->graph_antialias);
    cairo_scale(im->cr, im->zoom, im->zoom);
//    pango_cairo_font_map_set_resolution(PANGO_CAIRO_FONT_MAP(font_map), 100);
    gfx_new_area(im, 0, 0, 0, im->yimg,
                 im->ximg, im->yimg, im->graph_col[GRC_BACK]);
    gfx_add_point(im, im->ximg, 0);
    gfx_close_path(im);
    gfx_new_area(im, im->xorigin,
                 im->yorigin,
                 im->xorigin +
                 im->xsize, im->yorigin,
                 im->xorigin +
                 im->xsize,
                 im->yorigin - im->ysize, im->graph_col[GRC_CANVAS]);
    gfx_add_point(im, im->xorigin, im->yorigin - im->ysize);
    gfx_close_path(im);
    cairo_rectangle(im->cr, im->xorigin, im->yorigin - im->ysize - 1.0,
                    im->xsize, im->ysize + 2.0);
    cairo_clip(im->cr);
    if (im->minval > 0.0)
        areazero = im->minval;
    if (im->maxval < 0.0)
        areazero = im->maxval;
    for (i = 0; i < im->gdes_c; i++) {
        switch (im->gdes[i].gf) {
        case GF_CDEF:
        case GF_VDEF:
        case GF_DEF:
        case GF_PRINT:
        case GF_GPRINT:
        case GF_COMMENT:
        case GF_TEXTALIGN:
        case GF_HRULE:
        case GF_VRULE:
        case GF_XPORT:
        case GF_SHIFT:
            break;
        case GF_TICK:
            for (ii = 0; ii < im->xsize; ii++) {
                if (!isnan(im->gdes[i].p_data[ii])
                    && im->gdes[i].p_data[ii] != 0.0) {
                    if (im->gdes[i].yrule > 0) {
                        gfx_line(im,
                                 im->xorigin + ii,
                                 im->yorigin + 1.0,
                                 im->xorigin + ii,
                                 im->yorigin -
                                 im->gdes[i].yrule *
                                 im->ysize, 1.0, im->gdes[i].col);
                    } else if (im->gdes[i].yrule < 0) {
                        gfx_line(im,
                                 im->xorigin + ii,
                                 im->yorigin - im->ysize - 1.0,
                                 im->xorigin + ii,
                                 im->yorigin - im->ysize -
                                                im->gdes[i].
                                                yrule *
                                 im->ysize, 1.0, im->gdes[i].col);
                    }
                }
            }
            break;
        case GF_LINE:
        case GF_AREA: {
            rrd_value_t diffval = im->maxval - im->minval;
            rrd_value_t maxlimit = im->maxval + 9 * diffval;
            rrd_value_t minlimit = im->minval - 9 * diffval;        
            for (ii = 0; ii < im->xsize; ii++) {
               /* fix data points at oo and -oo */
                if (isinf(im->gdes[i].p_data[ii])) {
                    if (im->gdes[i].p_data[ii] > 0) {
                        im->gdes[i].p_data[ii] = im->maxval;
                    } else {
                        im->gdes[i].p_data[ii] = im->minval;
                    }
                }
                /* some versions of cairo go unstable when trying
                   to draw way out of the canvas ... lets not even try */
                if (im->gdes[i].p_data[ii] > maxlimit) {
                    im->gdes[i].p_data[ii] = maxlimit;
                }
                if (im->gdes[i].p_data[ii] < minlimit) {
                    im->gdes[i].p_data[ii] = minlimit;
                }
            }           /* for */

            /* *******************************************************
               a           ___. (a,t)
               |   |    ___
               ____|   |   |   |
               |       |___|
               -------|--t-1--t--------------------------------

               if we know the value at time t was a then
               we draw a square from t-1 to t with the value a.

               ********************************************************* */
            if (im->gdes[i].col.alpha != 0.0) {
                /* GF_LINE and friend */
                if (im->gdes[i].gf == GF_LINE) {
                    double    last_y = 0.0;
                    int       draw_on = 0;

                    cairo_save(im->cr);
                    cairo_new_path(im->cr);
                    cairo_set_line_width(im->cr, im->gdes[i].linewidth);
                    if (im->gdes[i].dash) {
                        cairo_set_dash(im->cr,
                                       im->gdes[i].p_dashes,
                                       im->gdes[i].ndash, im->gdes[i].offset);
                    }

                    for (ii = 1; ii < im->xsize; ii++) {
                        if (isnan(im->gdes[i].p_data[ii])
                            || (im->slopemode == 1
                                && isnan(im->gdes[i].p_data[ii - 1]))) {
                            draw_on = 0;
                            continue;
                        }
                        if (draw_on == 0) {
                            last_y = ytr(im, im->gdes[i].p_data[ii]);
                            if (im->slopemode == 0) {
                                double    x = ii - 1 + im->xorigin;
                                double    y = last_y;

                                gfx_line_fit(im, &x, &y);
                                cairo_move_to(im->cr, x, y);
                                x = ii + im->xorigin;
                                y = last_y;
                                gfx_line_fit(im, &x, &y);
                                cairo_line_to(im->cr, x, y);
                            } else {
                                double    x = ii - 1 + im->xorigin;
                                double    y =
                                    ytr(im, im->gdes[i].p_data[ii - 1]);
                                gfx_line_fit(im, &x, &y);
                                cairo_move_to(im->cr, x, y);
                                x = ii + im->xorigin;
                                y = last_y;
                                gfx_line_fit(im, &x, &y);
                                cairo_line_to(im->cr, x, y);
                            }
                            draw_on = 1;
                        } else {
                            double    x1 = ii + im->xorigin;
                            double    y1 = ytr(im, im->gdes[i].p_data[ii]);

                            if (im->slopemode == 0
                                && !AlmostEqual2sComplement(y1, last_y, 4)) {
                                double    x = ii - 1 + im->xorigin;
                                double    y = y1;

                                gfx_line_fit(im, &x, &y);
                                cairo_line_to(im->cr, x, y);
                            };
                            last_y = y1;
                            gfx_line_fit(im, &x1, &y1);
                            cairo_line_to(im->cr, x1, y1);
                        };
                    }
                    cairo_set_source_rgba(im->cr,
                                          im->gdes[i].
                                          col.red,
                                          im->gdes[i].
                                          col.green,
                                          im->gdes[i].
                                          col.blue, im->gdes[i].col.alpha);
                    cairo_set_line_cap(im->cr, CAIRO_LINE_CAP_ROUND);
                    cairo_set_line_join(im->cr, CAIRO_LINE_JOIN_ROUND);
                    cairo_stroke(im->cr);
                    cairo_restore(im->cr);
                } else {
                    int       idxI = -1;
                    double   *foreY =
                        (double *) malloc(sizeof(double) * im->xsize * 2);
                    double   *foreX =
                        (double *) malloc(sizeof(double) * im->xsize * 2);
                    double   *backY =
                        (double *) malloc(sizeof(double) * im->xsize * 2);
                    double   *backX =
                        (double *) malloc(sizeof(double) * im->xsize * 2);
                    int       drawem = 0;

                    for (ii = 0; ii <= im->xsize; ii++) {
                        double    ybase, ytop;

                        if (idxI > 0 && (drawem != 0 || ii == im->xsize)) {
                            int       cntI = 1;
                            int       lastI = 0;

                            while (cntI < idxI
                                   &&
                                   AlmostEqual2sComplement(foreY
                                                           [lastI],
                                                           foreY[cntI], 4)
                                   &&
                                   AlmostEqual2sComplement(foreY
                                                           [lastI],
                                                           foreY
                                                           [cntI + 1], 4)) {
                                cntI++;
                            }
                            gfx_new_area(im,
                                         backX[0], backY[0],
                                         foreX[0], foreY[0],
                                         foreX[cntI],
                                         foreY[cntI], im->gdes[i].col);
                            while (cntI < idxI) {
                                lastI = cntI;
                                cntI++;
                                while (cntI < idxI
                                       &&
                                       AlmostEqual2sComplement(foreY
                                                               [lastI],
                                                               foreY[cntI], 4)
                                       &&
                                       AlmostEqual2sComplement(foreY
                                                               [lastI],
                                                               foreY
                                                               [cntI
                                                                + 1], 4)) {
                                    cntI++;
                                }
                                gfx_add_point(im, foreX[cntI], foreY[cntI]);
                            }
                            gfx_add_point(im, backX[idxI], backY[idxI]);
                            while (idxI > 1) {
                                lastI = idxI;
                                idxI--;
                                while (idxI > 1
                                       &&
                                       AlmostEqual2sComplement(backY
                                                               [lastI],
                                                               backY[idxI], 4)
                                       &&
                                       AlmostEqual2sComplement(backY
                                                               [lastI],
                                                               backY
                                                               [idxI
                                                                - 1], 4)) {
                                    idxI--;
                                }
                                gfx_add_point(im, backX[idxI], backY[idxI]);
                            }
                            idxI = -1;
                            drawem = 0;
                            gfx_close_path(im);
                        }
                        if (drawem != 0) {
                            drawem = 0;
                            idxI = -1;
                        }
                        if (ii == im->xsize)
                            break;
                        if (im->slopemode == 0 && ii == 0) {
                            continue;
                        }
                        if (isnan(im->gdes[i].p_data[ii])) {
                            drawem = 1;
                            continue;
                        }
                        ytop = ytr(im, im->gdes[i].p_data[ii]);
                        if (lastgdes && im->gdes[i].stack) {
                            ybase = ytr(im, lastgdes->p_data[ii]);
                        } else {
                            ybase = ytr(im, areazero);
                        }
                        if (ybase == ytop) {
                            drawem = 1;
                            continue;
                        }

                        if (ybase > ytop) {
                            double    extra = ytop;

                            ytop = ybase;
                            ybase = extra;
                        }
                        if (im->slopemode == 0) {
                            backY[++idxI] = ybase - 0.2;
                            backX[idxI] = ii + im->xorigin - 1;
                            foreY[idxI] = ytop + 0.2;
                            foreX[idxI] = ii + im->xorigin - 1;
                        }
                        backY[++idxI] = ybase - 0.2;
                        backX[idxI] = ii + im->xorigin;
                        foreY[idxI] = ytop + 0.2;
                        foreX[idxI] = ii + im->xorigin;
                    }
                    /* close up any remaining area */
                    free(foreY);
                    free(foreX);
                    free(backY);
                    free(backX);
                }       /* else GF_LINE */
            }
            /* if color != 0x0 */
            /* make sure we do not run into trouble when stacking on NaN */
            for (ii = 0; ii < im->xsize; ii++) {
                if (isnan(im->gdes[i].p_data[ii])) {
                    if (lastgdes && (im->gdes[i].stack)) {
                        im->gdes[i].p_data[ii] = lastgdes->p_data[ii];
                    } else {
                        im->gdes[i].p_data[ii] = areazero;
                    }
                }
            }
            lastgdes = &(im->gdes[i]);
            break;
        } /* GF_AREA, GF_LINE, GF_GRAD */
        case GF_STACK:
            rrd_set_error
                ("STACK should already be turned into LINE or AREA here");
            return -1;
            break;
        }               /* switch */
    }
    cairo_reset_clip(im->cr);

    /* grid_paint also does the text */
    if (!(im->extra_flags & ONLY_GRAPH))
        grid_paint(im);
    if (!(im->extra_flags & ONLY_GRAPH))
        axis_paint(im);
    /* the RULES are the last thing to paint ... */
    for (i = 0; i < im->gdes_c; i++) {

        switch (im->gdes[i].gf) {
        case GF_HRULE:
            if (im->gdes[i].yrule >= im->minval
                && im->gdes[i].yrule <= im->maxval) {
                cairo_save(im->cr);
                if (im->gdes[i].dash) {
                    cairo_set_dash(im->cr,
                                   im->gdes[i].p_dashes,
                                   im->gdes[i].ndash, im->gdes[i].offset);
                }
                gfx_line(im, im->xorigin,
                         ytr(im, im->gdes[i].yrule),
                         im->xorigin + im->xsize,
                         ytr(im, im->gdes[i].yrule), 1.0, im->gdes[i].col);
                cairo_stroke(im->cr);
                cairo_restore(im->cr);
            }
            break;
        case GF_VRULE:
            if (im->gdes[i].xrule >= im->start
                && im->gdes[i].xrule <= im->end) {
                cairo_save(im->cr);
                if (im->gdes[i].dash) {
                    cairo_set_dash(im->cr,
                                   im->gdes[i].p_dashes,
                                   im->gdes[i].ndash, im->gdes[i].offset);
                }
                gfx_line(im,
                         xtr(im, im->gdes[i].xrule),
                         im->yorigin, xtr(im,
                                          im->
                                          gdes[i].
                                          xrule),
                         im->yorigin - im->ysize, 1.0, im->gdes[i].col);
                cairo_stroke(im->cr);
                cairo_restore(im->cr);
            }
            break;
        default:
            break;
        }
    }


    switch (im->imgformat) {
    case IF_PNG:
    {
        cairo_status_t status;

        status = strlen(im->graphfile) ?
            cairo_surface_write_to_png(im->surface, im->graphfile)
            : cairo_surface_write_to_png_stream(im->surface, &cairo_output,
                                                im);

        if (status != CAIRO_STATUS_SUCCESS) {
            rrd_set_error("Could not save png to '%s'", im->graphfile);
            return 1;
        }
        break;
    }
    default:
        if (strlen(im->graphfile)) {
            cairo_show_page(im->cr);
        } else {
            cairo_surface_finish(im->surface);
        }
        break;
    }

    return 0;
}


/*****************************************************
 * graph stuff
 *****************************************************/

int gdes_alloc(
    image_desc_t *im)
{

    im->gdes_c++;
    if ((im->gdes = (graph_desc_t *)
         rrd_realloc(im->gdes, (im->gdes_c)
                     * sizeof(graph_desc_t))) == NULL) {
        rrd_set_error("realloc graph_descs");
        return -1;
    }


    im->gdes[im->gdes_c - 1].step = im->step;
    im->gdes[im->gdes_c - 1].step_orig = im->step;
    im->gdes[im->gdes_c - 1].stack = 0;
    im->gdes[im->gdes_c - 1].skipscale = 0;
    im->gdes[im->gdes_c - 1].linewidth = 0;
    im->gdes[im->gdes_c - 1].debug = 0;
    im->gdes[im->gdes_c - 1].start = im->start;
    im->gdes[im->gdes_c - 1].start_orig = im->start;
    im->gdes[im->gdes_c - 1].end = im->end;
    im->gdes[im->gdes_c - 1].end_orig = im->end;
    im->gdes[im->gdes_c - 1].vname[0] = '\0';
    im->gdes[im->gdes_c - 1].data = NULL;
    im->gdes[im->gdes_c - 1].ds_namv = NULL;
    im->gdes[im->gdes_c - 1].data_first = 0;
    im->gdes[im->gdes_c - 1].p_data = NULL;
    im->gdes[im->gdes_c - 1].rpnp = NULL;
    im->gdes[im->gdes_c - 1].p_dashes = NULL;
    im->gdes[im->gdes_c - 1].shift = 0.0;
    im->gdes[im->gdes_c - 1].dash = 0;
    im->gdes[im->gdes_c - 1].ndash = 0;
    im->gdes[im->gdes_c - 1].offset = 0;
    im->gdes[im->gdes_c - 1].col.red = 0.0;
    im->gdes[im->gdes_c - 1].col.green = 0.0;
    im->gdes[im->gdes_c - 1].col.blue = 0.0;
    im->gdes[im->gdes_c - 1].col.alpha = 0.0;
    im->gdes[im->gdes_c - 1].legend[0] = '\0';
    im->gdes[im->gdes_c - 1].format[0] = '\0';
    im->gdes[im->gdes_c - 1].strftm = 0;
    im->gdes[im->gdes_c - 1].rrd[0] = '\0';
    im->gdes[im->gdes_c - 1].ds = -1;
    im->gdes[im->gdes_c - 1].cf_reduce = CF_AVERAGE;
    im->gdes[im->gdes_c - 1].cf = CF_AVERAGE;
    im->gdes[im->gdes_c - 1].yrule = DNAN;
    im->gdes[im->gdes_c - 1].xrule = 0;
    return 0;
}

/* copies input untill the first unescaped colon is found
   or until input ends. backslashes have to be escaped as well */
int scan_for_col(
    const char *const input,
    int len,
    char *const output)
{
    int       inp, outp = 0;

    for (inp = 0; inp < len && input[inp] != ':' && input[inp] != '\0'; inp++) {
        if (input[inp] == '\\'
            && input[inp + 1] != '\0'
            && (input[inp + 1] == '\\' || input[inp + 1] == ':')) {
            output[outp++] = input[++inp];
        } else {
            output[outp++] = input[inp];
        }
    }
    output[outp] = '\0';
    return inp;
}

/* Now just a wrapper around rrd_graph_v */
int rrd_graph(
    int argc,
    char **argv,
    char ***prdata,
    int *xsize,
    int *ysize,
    FILE * stream,
    double *ymin,
    double *ymax)
{
    int       prlines = 0;
    rrd_info_t *grinfo = NULL;
    rrd_info_t *walker;

    grinfo = rrd_graph_v(argc, argv);
    if (grinfo == NULL)
        return -1;
    walker = grinfo;
    (*prdata) = NULL;
    while (walker) {
        if (strcmp(walker->key, "image_info") == 0) {
            prlines++;
            if (((*prdata) =
                 (char**)rrd_realloc((*prdata),
                             (prlines + 1) * sizeof(char *))) == NULL) {
                rrd_set_error("realloc prdata");
                return 0;
            }
            /* imginfo goes to position 0 in the prdata array */
            (*prdata)[prlines - 1] = (char*)malloc((strlen(walker->value.u_str)
                                             + 2) * sizeof(char));
            strcpy((*prdata)[prlines - 1], walker->value.u_str);
            (*prdata)[prlines] = NULL;
        }
        /* skip anything else */
        walker = walker->next;
    }
    walker = grinfo;
    *xsize = 0;
    *ysize = 0;
    *ymin = 0;
    *ymax = 0;
    while (walker) {
        if (strcmp(walker->key, "image_width") == 0) {
            *xsize = walker->value.u_cnt;
        } else if (strcmp(walker->key, "image_height") == 0) {
            *ysize = walker->value.u_cnt;
        } else if (strcmp(walker->key, "value_min") == 0) {
            *ymin = walker->value.u_val;
        } else if (strcmp(walker->key, "value_max") == 0) {
            *ymax = walker->value.u_val;
        } else if (strncmp(walker->key, "print", 5) == 0) { /* keys are prdate[0..] */
            prlines++;
            if (((*prdata) =
                 (char**)rrd_realloc((*prdata),
                             (prlines + 1) * sizeof(char *))) == NULL) {
                rrd_set_error("realloc prdata");
                return 0;
            }
            (*prdata)[prlines - 1] = (char*)malloc((strlen(walker->value.u_str)
                                             + 2) * sizeof(char));
            (*prdata)[prlines] = NULL;
            strcpy((*prdata)[prlines - 1], walker->value.u_str);
        } else if (strcmp(walker->key, "image") == 0) {
            if ( fwrite(walker->value.u_blo.ptr, walker->value.u_blo.size, 1,
                   (stream ? stream : stdout)) == 0 && ferror(stream ? stream : stdout)){
                rrd_set_error("writing image");
                return 0;
            }
        }
        /* skip anything else */
        walker = walker->next;
    }
    rrd_info_free(grinfo);
    return 0;
}


/* Some surgery done on this function, it became ridiculously big.
** Things moved:
** - initializing     now in rrd_graph_init()
** - options parsing  now in rrd_graph_options()
** - script parsing   now in rrd_graph_script()
*/
rrd_info_t *rrd_graph_v(
    int argc,
    char **argv)
{
    image_desc_t im;
    rrd_info_t *grinfo;
    char *old_locale;
    rrd_graph_init(&im);
    /* a dummy surface so that we can measure text sizes for placements */
    old_locale = setlocale(LC_NUMERIC, NULL);
    setlocale(LC_NUMERIC, "C");
    rrd_graph_options(argc, argv, &im);
    if (rrd_test_error()) {
        rrd_info_free(im.grinfo);
        im_free(&im);
        return NULL;
    }

    if (optind >= argc) {
        rrd_info_free(im.grinfo);
        im_free(&im);
        rrd_set_error("missing filename");
        return NULL;
    }

    if (strlen(argv[optind]) >= MAXPATH) {
        rrd_set_error("filename (including path) too long");
        rrd_info_free(im.grinfo);
        im_free(&im);
        return NULL;
    }

    strncpy(im.graphfile, argv[optind], MAXPATH - 1);
    im.graphfile[MAXPATH - 1] = '\0';

    if (strcmp(im.graphfile, "-") == 0) {
        im.graphfile[0] = '\0';
    }

    rrd_graph_script(argc, argv, &im, 1);
    setlocale(LC_NUMERIC, old_locale); /* reenable locale for rendering the graph */

    if (rrd_test_error()) {
        rrd_info_free(im.grinfo);
        im_free(&im);
        return NULL;
    }

    /* Everything is now read and the actual work can start */

    if (graph_paint(&im) == -1) {
        rrd_info_free(im.grinfo);
        im_free(&im);
        return NULL;
    }


    /* The image is generated and needs to be output.
     ** Also, if needed, print a line with information about the image.
     */

    if (im.imginfo) {
        rrd_infoval_t info;
        char     *path;
        char     *filename;

        path = strdup(im.graphfile);
        filename = basename(path);
        info.u_str =
            sprintf_alloc(im.imginfo,
                          filename,
                          (long) (im.zoom *
                                  im.ximg), (long) (im.zoom * im.yimg));
        grinfo_push(&im, sprintf_alloc("image_info"), RD_I_STR, info);
        free(info.u_str);
        free(path);
    }
    if (im.rendered_image) {
        rrd_infoval_t img;

        img.u_blo.size = im.rendered_image_size;
        img.u_blo.ptr = im.rendered_image;
        grinfo_push(&im, sprintf_alloc("image"), RD_I_BLO, img);
    }
    grinfo = im.grinfo;
    im_free(&im);
    return grinfo;
}

static void
rrd_set_font_desc (
    image_desc_t *im,int prop,char *font, double size ){
    if (font){
        strncpy(im->text_prop[prop].font, font, sizeof(text_prop[prop].font) - 1);
        im->text_prop[prop].font[sizeof(text_prop[prop].font) - 1] = '\0';
        /* if we already got one, drop it first */
        pango_font_description_free(im->text_prop[prop].font_desc);
        im->text_prop[prop].font_desc = pango_font_description_from_string( font );
    };
    if (size > 0){
        im->text_prop[prop].size = size;
    };
    if (im->text_prop[prop].font_desc && im->text_prop[prop].size ){
        pango_font_description_set_size(im->text_prop[prop].font_desc, im->text_prop[prop].size * PANGO_SCALE);
    };
}

void rrd_graph_init(
    image_desc_t
    *im)
{
    unsigned int i;
    char     *deffont = getenv("RRD_DEFAULT_FONT");
    static PangoFontMap *fontmap = NULL;
    PangoContext *context;

#ifdef HAVE_TZSET
    tzset();
#endif
    im->gdef_map = g_hash_table_new_full(g_str_hash, g_str_equal,g_free,NULL);
    im->rrd_map = g_hash_table_new_full(g_str_hash, g_str_equal,g_free,NULL);
    im->base = 1000;
    im->daemon_addr = NULL;
    im->draw_x_grid = 1;
    im->draw_y_grid = 1;
    im->draw_3d_border = 2;
    im->dynamic_labels = 0;
    im->extra_flags = 0;
    im->font_options = cairo_font_options_create();
    im->forceleftspace = 0;
    im->gdes_c = 0;
    im->gdes = NULL;
    im->graph_antialias = CAIRO_ANTIALIAS_GRAY;
    im->grid_dash_off = 1;
    im->grid_dash_on = 1;
    im->gridfit = 1;
    im->grinfo = (rrd_info_t *) NULL;
    im->grinfo_current = (rrd_info_t *) NULL;
    im->imgformat = IF_PNG;
    im->imginfo = NULL;
    im->lazy = 0;
    im->legenddirection = TOP_DOWN;
    im->legendheight = 0;
    im->legendposition = SOUTH;
    im->legendwidth = 0;
    im->logarithmic = 0;
    im->maxval = DNAN;
    im->minval = 0;
    im->minval = DNAN;
    im->magfact = 1;
    im->prt_c = 0;
    im->rigid = 0;
    im->rendered_image_size = 0;
    im->rendered_image = NULL;
    im->slopemode = 0;
    im->step = 0;
    im->symbol = ' ';
    im->tabwidth = 40.0;
    im->title[0] = '\0';
    im->unitsexponent = 9999;
    im->unitslength = 6;
    im->viewfactor = 1.0;
    im->watermark[0] = '\0';
    im->with_markup = 0;
    im->ximg = 0;
    im->xlab_user.minsec = -1;
    im->xorigin = 0;
    im->xOriginLegend = 0;
    im->xOriginLegendY = 0;
    im->xOriginLegendY2 = 0;
    im->xOriginTitle = 0;
    im->xsize = 400;
    im->ygridstep = DNAN;
    im->yimg = 0;
    im->ylegend[0] = '\0';
    im->second_axis_scale = 0; /* 0 disables it */
    im->second_axis_shift = 0; /* no shift by default */
    im->second_axis_legend[0] = '\0';
    im->second_axis_format[0] = '\0';
    im->yorigin = 0;
    im->yOriginLegend = 0;
    im->yOriginLegendY = 0;
    im->yOriginLegendY2 = 0;
    im->yOriginTitle = 0;
    im->ysize = 100;
    im->zoom = 1;

    im->surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 10, 10);
    im->cr = cairo_create(im->surface);

    for (i = 0; i < DIM(text_prop); i++) {
        im->text_prop[i].size = -1;
        im->text_prop[i].font_desc = NULL;
        rrd_set_font_desc(im,i, deffont ? deffont : text_prop[i].font,text_prop[i].size);
    }

    if (fontmap == NULL){
        fontmap = pango_cairo_font_map_get_default();
    }

    context =  pango_cairo_font_map_create_context((PangoCairoFontMap*)fontmap);

    pango_cairo_context_set_resolution(context, 100);

    pango_cairo_update_context(im->cr,context);

    im->layout = pango_layout_new(context);
    g_object_unref (context);

//  im->layout = pango_cairo_create_layout(im->cr);


    cairo_font_options_set_hint_style
        (im->font_options, CAIRO_HINT_STYLE_FULL);
    cairo_font_options_set_hint_metrics
        (im->font_options, CAIRO_HINT_METRICS_ON);
    cairo_font_options_set_antialias(im->font_options, CAIRO_ANTIALIAS_GRAY);



    for (i = 0; i < DIM(graph_col); i++)
        im->graph_col[i] = graph_col[i];


}


void rrd_graph_options(
    int argc,
    char *argv[],
    image_desc_t
    *im)
{
    int       stroff;
    char     *parsetime_error = NULL;
    char      scan_gtm[12], scan_mtm[12], scan_ltm[12], col_nam[12];
    time_t    start_tmp = 0, end_tmp = 0;
    long      long_tmp;
    rrd_time_value_t start_tv, end_tv;
    long unsigned int color;

    /* defines for long options without a short equivalent. should be bytes,
       and may not collide with (the ASCII value of) short options */
#define LONGOPT_UNITS_SI 255

/* *INDENT-OFF* */
    struct option long_options[] = {
        { "alt-autoscale",      no_argument,       0, 'A'},
        { "imgformat",          required_argument, 0, 'a'},
        { "font-smoothing-threshold", required_argument, 0, 'B'},
        { "base",               required_argument, 0, 'b'},
        { "color",              required_argument, 0, 'c'},
        { "full-size-mode",     no_argument,       0, 'D'},
        { "daemon",             required_argument, 0, 'd'},
        { "slope-mode",         no_argument,       0, 'E'},
        { "end",                required_argument, 0, 'e'},
        { "force-rules-legend", no_argument,       0, 'F'},
        { "imginfo",            required_argument, 0, 'f'},
        { "graph-render-mode",  required_argument, 0, 'G'},
        { "no-legend",          no_argument,       0, 'g'},
        { "height",             required_argument, 0, 'h'},
        { "no-minor",           no_argument,       0, 'I'},
        { "interlaced",         no_argument,       0, 'i'},
        { "alt-autoscale-min",  no_argument,       0, 'J'},
        { "only-graph",         no_argument,       0, 'j'},
        { "units-length",       required_argument, 0, 'L'},
        { "lower-limit",        required_argument, 0, 'l'},
        { "alt-autoscale-max",  no_argument,       0, 'M'},
        { "zoom",               required_argument, 0, 'm'},
        { "no-gridfit",         no_argument,       0, 'N'},
        { "font",               required_argument, 0, 'n'},
        { "logarithmic",        no_argument,       0, 'o'},
        { "pango-markup",       no_argument,       0, 'P'},
        { "font-render-mode",   required_argument, 0, 'R'},
        { "rigid",              no_argument,       0, 'r'},
        { "step",               required_argument, 0, 'S'},
        { "start",              required_argument, 0, 's'},
        { "tabwidth",           required_argument, 0, 'T'},
        { "title",              required_argument, 0, 't'},
        { "upper-limit",        required_argument, 0, 'u'},
        { "vertical-label",     required_argument, 0, 'v'},
        { "watermark",          required_argument, 0, 'W'},
        { "width",              required_argument, 0, 'w'},
        { "units-exponent",     required_argument, 0, 'X'},
        { "x-grid",             required_argument, 0, 'x'},
        { "alt-y-grid",         no_argument,       0, 'Y'},
        { "y-grid",             required_argument, 0, 'y'},
        { "lazy",               no_argument,       0, 'z'},
        { "units",              required_argument, 0, LONGOPT_UNITS_SI},
        { "alt-y-mrtg",         no_argument,       0, 1000},    /* this has no effect it is just here to save old apps from crashing when they use it */
        { "disable-rrdtool-tag",no_argument,       0, 1001},
        { "right-axis",         required_argument, 0, 1002},
        { "right-axis-label",   required_argument, 0, 1003},
        { "right-axis-format",  required_argument, 0, 1004},
        { "legend-position",    required_argument, 0, 1005},
        { "legend-direction",   required_argument, 0, 1006},
        { "border",             required_argument, 0, 1007},
        { "grid-dash",          required_argument, 0, 1008},
        { "dynamic-labels",     no_argument,       0, 1009},
        {  0, 0, 0, 0}
};
/* *INDENT-ON* */

    optind = 0;
    opterr = 0;         /* initialize getopt */
    rrd_parsetime("end-24h", &start_tv);
    rrd_parsetime("now", &end_tv);
    while (1) {
        int       option_index = 0;
        int       opt;
        int       col_start, col_end;

        opt = getopt_long(argc, argv,
                          "Aa:B:b:c:Dd:Ee:Ff:G:gh:IiJjL:l:Mm:Nn:oPR:rS:s:T:t:u:v:W:w:X:x:Yy:z",
                          long_options, &option_index);
        if (opt == EOF)
            break;
        switch (opt) {
        case 'I':
            im->extra_flags |= NOMINOR;
            break;
        case 'Y':
            im->extra_flags |= ALTYGRID;
            break;
        case 'A':
            im->extra_flags |= ALTAUTOSCALE;
            break;
        case 'J':
            im->extra_flags |= ALTAUTOSCALE_MIN;
            break;
        case 'M':
            im->extra_flags |= ALTAUTOSCALE_MAX;
            break;
        case 'j':
            im->extra_flags |= ONLY_GRAPH;
            break;
        case 'g':
            im->extra_flags |= NOLEGEND;
            break;
        case 1005:
            if (strcmp(optarg, "north") == 0) {
                im->legendposition = NORTH;
            } else if (strcmp(optarg, "west") == 0) {
                im->legendposition = WEST;
            } else if (strcmp(optarg, "south") == 0) {
                im->legendposition = SOUTH;
            } else if (strcmp(optarg, "east") == 0) {
                im->legendposition = EAST;
            } else {
                rrd_set_error("unknown legend-position '%s'", optarg);
                return;
            }
            break;
        case 1006:
            if (strcmp(optarg, "topdown") == 0) {
                im->legenddirection = TOP_DOWN;
            } else if (strcmp(optarg, "bottomup") == 0) {
                im->legenddirection = BOTTOM_UP;
            } else {
                rrd_set_error("unknown legend-position '%s'", optarg);
                return;
            }
            break;
        case 'F':
            im->extra_flags |= FORCE_RULES_LEGEND;
            break;
        case 1001:
            im->extra_flags |= NO_RRDTOOL_TAG;
            break;
        case LONGOPT_UNITS_SI:
            if (im->extra_flags & FORCE_UNITS) {
                rrd_set_error("--units can only be used once!");
                return;
            }
            if (strcmp(optarg, "si") == 0)
                im->extra_flags |= FORCE_UNITS_SI;
            else {
                rrd_set_error("invalid argument for --units: %s", optarg);
                return;
            }
            break;
        case 'X':
            im->unitsexponent = atoi(optarg);
            break;
        case 'L':
            im->unitslength = atoi(optarg);
            im->forceleftspace = 1;
            break;
        case 'T':
            im->tabwidth = atof(optarg);
            break;
        case 'S':
            im->step = atoi(optarg);
            break;
        case 'N':
            im->gridfit = 0;
            break;
        case 'P':
            im->with_markup = 1;
            break;
        case 's':
            if ((parsetime_error = rrd_parsetime(optarg, &start_tv))) {
                rrd_set_error("start time: %s", parsetime_error);
                return;
            }
            break;
        case 'e':
            if ((parsetime_error = rrd_parsetime(optarg, &end_tv))) {
                rrd_set_error("end time: %s", parsetime_error);
                return;
            }
            break;
        case 'x':
            if (strcmp(optarg, "none") == 0) {
                im->draw_x_grid = 0;
                break;
            };
            if (sscanf(optarg,
                       "%10[A-Z]:%ld:%10[A-Z]:%ld:%10[A-Z]:%ld:%ld:%n",
                       scan_gtm,
                       &im->xlab_user.gridst,
                       scan_mtm,
                       &im->xlab_user.mgridst,
                       scan_ltm,
                       &im->xlab_user.labst,
                       &im->xlab_user.precis, &stroff) == 7 && stroff != 0) {
                strncpy(im->xlab_form, optarg + stroff,
                        sizeof(im->xlab_form) - 1);
                im->xlab_form[sizeof(im->xlab_form) - 1] = '\0';
                if ((int)
                    (im->xlab_user.gridtm = tmt_conv(scan_gtm)) == -1) {
                    rrd_set_error("unknown keyword %s", scan_gtm);
                    return;
                } else if ((int)
                           (im->xlab_user.mgridtm = tmt_conv(scan_mtm))
                           == -1) {
                    rrd_set_error("unknown keyword %s", scan_mtm);
                    return;
                } else if ((int)
                           (im->xlab_user.labtm = tmt_conv(scan_ltm)) == -1) {
                    rrd_set_error("unknown keyword %s", scan_ltm);
                    return;
                }
                im->xlab_user.minsec = 1;
                im->xlab_user.stst = im->xlab_form;
            } else {
                rrd_set_error("invalid x-grid format");
                return;
            }
            break;
        case 'y':

            if (strcmp(optarg, "none") == 0) {
                im->draw_y_grid = 0;
                break;
            };
            if (sscanf(optarg, "%lf:%d", &im->ygridstep, &im->ylabfact) == 2) {
                if (im->ygridstep <= 0) {
                    rrd_set_error("grid step must be > 0");
                    return;
                } else if (im->ylabfact < 1) {
                    rrd_set_error("label factor must be > 0");
                    return;
                }
            } else {
                rrd_set_error("invalid y-grid format");
                return;
            }
            break;
        case 1007:
            im->draw_3d_border = atoi(optarg);
            break;
        case 1008: /* grid-dash */
            if(sscanf(optarg,
                      "%lf:%lf",
                      &im->grid_dash_on,
                      &im->grid_dash_off) != 2) {
                rrd_set_error("expected grid-dash format float:float");
                return;
            }
            break;   
        case 1009: /* enable dynamic labels */
            im->dynamic_labels = 1;
            break;         
        case 1002: /* right y axis */

            if(sscanf(optarg,
                      "%lf:%lf",
                      &im->second_axis_scale,
                      &im->second_axis_shift) == 2) {
                if(im->second_axis_scale==0){
                    rrd_set_error("the second_axis_scale  must not be 0");
                    return;
                }
            } else {
                rrd_set_error("invalid right-axis format expected scale:shift");
                return;
            }
            break;
        case 1003:
            strncpy(im->second_axis_legend,optarg,150);
            im->second_axis_legend[150]='\0';
            break;
        case 1004:
            if (bad_format(optarg)){
                rrd_set_error("use either %le or %lf formats");
                return;
            }
            strncpy(im->second_axis_format,optarg,150);
            im->second_axis_format[150]='\0';
            break;
        case 'v':
            strncpy(im->ylegend, optarg, 150);
            im->ylegend[150] = '\0';
            break;
        case 'u':
            im->maxval = atof(optarg);
            break;
        case 'l':
            im->minval = atof(optarg);
            break;
        case 'b':
            im->base = atol(optarg);
            if (im->base != 1024 && im->base != 1000) {
                rrd_set_error
                    ("the only sensible value for base apart from 1000 is 1024");
                return;
            }
            break;
        case 'w':
            long_tmp = atol(optarg);
            if (long_tmp < 10) {
                rrd_set_error("width below 10 pixels");
                return;
            }
            im->xsize = long_tmp;
            break;
        case 'h':
            long_tmp = atol(optarg);
            if (long_tmp < 10) {
                rrd_set_error("height below 10 pixels");
                return;
            }
            im->ysize = long_tmp;
            break;
        case 'D':
            im->extra_flags |= FULL_SIZE_MODE;
            break;
        case 'i':
            /* interlaced png not supported at the moment */
            break;
        case 'r':
            im->rigid = 1;
            break;
        case 'f':
            im->imginfo = optarg;
            break;
        case 'a':
            if ((int)
                (im->imgformat = if_conv(optarg)) == -1) {
                rrd_set_error("unsupported graphics format '%s'", optarg);
                return;
            }
            break;
        case 'z':
            im->lazy = 1;
            break;
        case 'E':
            im->slopemode = 1;
            break;
        case 'o':
            im->logarithmic = 1;
            break;
        case 'c':
            if (sscanf(optarg,
                       "%10[A-Z]#%n%8lx%n",
                       col_nam, &col_start, &color, &col_end) == 2) {
                int       ci;
                int       col_len = col_end - col_start;

                switch (col_len) {
                case 3:
                    color =
                        (((color & 0xF00) * 0x110000) | ((color & 0x0F0) *
                                                         0x011000) |
                         ((color & 0x00F)
                          * 0x001100)
                         | 0x000000FF);
                    break;
                case 4:
                    color =
                        (((color & 0xF000) *
                          0x11000) | ((color & 0x0F00) *
                                      0x01100) | ((color &
                                                   0x00F0) *
                                                  0x00110) |
                         ((color & 0x000F) * 0x00011)
                        );
                    break;
                case 6:
                    color = (color << 8) + 0xff /* shift left by 8 */ ;
                    break;
                case 8:
                    break;
                default:
                    rrd_set_error("the color format is #RRGGBB[AA]");
                    return;
                }
                if ((ci = grc_conv(col_nam)) != -1) {
                    im->graph_col[ci] = gfx_hex_to_col(color);
                } else {
                    rrd_set_error("invalid color name '%s'", col_nam);
                    return;
                }
            } else {
                rrd_set_error("invalid color def format");
                return;
            }
            break;
        case 'n':{
            char      prop[15];
            double    size = 1;
            int       end;

            if (sscanf(optarg, "%10[A-Z]:%lf%n", prop, &size, &end) >= 2) {
                int       sindex, propidx;

                if ((sindex = text_prop_conv(prop)) != -1) {
                    for (propidx = sindex;
                         propidx < TEXT_PROP_LAST; propidx++) {
                        if (size > 0) {
                            rrd_set_font_desc(im,propidx,NULL,size);
                        }
                        if ((int) strlen(optarg) > end+2) {
                            if (optarg[end] == ':') {
                                rrd_set_font_desc(im,propidx,optarg + end + 1,0);
                            } else {
                                rrd_set_error
                                    ("expected : after font size in '%s'",
                                     optarg);
                                return;
                            }
                        }
                        /* only run the for loop for DEFAULT (0) for
                           all others, we break here. woodo programming */
                        if (propidx == sindex && sindex != 0)
                            break;
                    }
                } else {
                    rrd_set_error("invalid fonttag '%s'", prop);
                    return;
                }
            } else {
                rrd_set_error("invalid text property format");
                return;
            }
            break;
        }
        case 'm':
            im->zoom = atof(optarg);
            if (im->zoom <= 0.0) {
                rrd_set_error("zoom factor must be > 0");
                return;
            }
            break;
        case 't':
            strncpy(im->title, optarg, 150);
            im->title[150] = '\0';
            break;
        case 'R':
            if (strcmp(optarg, "normal") == 0) {
                cairo_font_options_set_antialias
                    (im->font_options, CAIRO_ANTIALIAS_GRAY);
                cairo_font_options_set_hint_style
                    (im->font_options, CAIRO_HINT_STYLE_FULL);
            } else if (strcmp(optarg, "light") == 0) {
                cairo_font_options_set_antialias
                    (im->font_options, CAIRO_ANTIALIAS_GRAY);
                cairo_font_options_set_hint_style
                    (im->font_options, CAIRO_HINT_STYLE_SLIGHT);
            } else if (strcmp(optarg, "mono") == 0) {
                cairo_font_options_set_antialias
                    (im->font_options, CAIRO_ANTIALIAS_NONE);
                cairo_font_options_set_hint_style
                    (im->font_options, CAIRO_HINT_STYLE_FULL);
            } else {
                rrd_set_error("unknown font-render-mode '%s'", optarg);
                return;
            }
            break;
        case 'G':
            if (strcmp(optarg, "normal") == 0)
                im->graph_antialias = CAIRO_ANTIALIAS_GRAY;
            else if (strcmp(optarg, "mono") == 0)
                im->graph_antialias = CAIRO_ANTIALIAS_NONE;
            else {
                rrd_set_error("unknown graph-render-mode '%s'", optarg);
                return;
            }
            break;
        case 'B':
            /* not supported curently */
            break;
        case 'W':
            strncpy(im->watermark, optarg, 100);
            im->watermark[99] = '\0';
            break;
        case 'd':
        {
            if (im->daemon_addr != NULL)
            {
                rrd_set_error ("You cannot specify --daemon "
                        "more than once.");
                return;
            }

            im->daemon_addr = strdup(optarg);
            if (im->daemon_addr == NULL)
            {
              rrd_set_error("strdup failed");
              return;
            }

            break;
        }
        case '?':
            if (optopt != 0)
                rrd_set_error("unknown option '%c'", optopt);
            else
                rrd_set_error("unknown option '%s'", argv[optind - 1]);
            return;
        }
    } /* while (1) */

    {   /* try to connect to rrdcached */
        int status = rrdc_connect(im->daemon_addr);
        if (status != 0) return;
    }

    pango_cairo_context_set_font_options(pango_layout_get_context(im->layout), im->font_options);
    pango_layout_context_changed(im->layout);



    if (im->logarithmic && im->minval <= 0) {
        rrd_set_error
            ("for a logarithmic yaxis you must specify a lower-limit > 0");
        return;
    }

    if (rrd_proc_start_end(&start_tv, &end_tv, &start_tmp, &end_tmp) == -1) {
        /* error string is set in rrd_parsetime.c */
        return;
    }

    if (start_tmp < 3600 * 24 * 365 * 10) {
        rrd_set_error
            ("the first entry to fetch should be after 1980 (%ld)",
             start_tmp);
        return;
    }

    if (end_tmp < start_tmp) {
        rrd_set_error
            ("start (%ld) should be less than end (%ld)", start_tmp, end_tmp);
        return;
    }

    im->start = start_tmp;
    im->end = end_tmp;
    im->step = max((long) im->step, (im->end - im->start) / im->xsize);
}

int rrd_graph_color(
    image_desc_t
    *im,
    char *var,
    char *err,
    int optional)
{
    char     *color;
    graph_desc_t *gdp = &im->gdes[im->gdes_c - 1];

    color = strstr(var, "#");
    if (color == NULL) {
        if (optional == 0) {
            rrd_set_error("Found no color in %s", err);
            return 0;
        }
        return 0;
    } else {
        int       n = 0;
        char     *rest;
        long unsigned int col;

        rest = strstr(color, ":");
        if (rest != NULL)
            n = rest - color;
        else
            n = strlen(color);
        switch (n) {
        case 7:
            sscanf(color, "#%6lx%n", &col, &n);
            col = (col << 8) + 0xff /* shift left by 8 */ ;
            if (n != 7)
                rrd_set_error("Color problem in %s", err);
            break;
        case 9:
            sscanf(color, "#%8lx%n", &col, &n);
            if (n == 9)
                break;
        default:
            rrd_set_error("Color problem in %s", err);
        }
        if (rrd_test_error())
            return 0;
        gdp->col = gfx_hex_to_col(col);
        return n;
    }
}


int bad_format(
    char *fmt)
{
    char     *ptr;
    int       n = 0;

    ptr = fmt;
    while (*ptr != '\0')
        if (*ptr++ == '%') {

            /* line cannot end with percent char */
            if (*ptr == '\0')
                return 1;
            /* '%s', '%S' and '%%' are allowed */
            if (*ptr == 's' || *ptr == 'S' || *ptr == '%')
                ptr++;
            /* %c is allowed (but use only with vdef!) */
            else if (*ptr == 'c') {
                ptr++;
                n = 1;
            }

            /* or else '% 6.2lf' and such are allowed */
            else {
                /* optional padding character */
                if (*ptr == ' ' || *ptr == '+' || *ptr == '-')
                    ptr++;
                /* This should take care of 'm.n' with all three optional */
                while (*ptr >= '0' && *ptr <= '9')
                    ptr++;
                if (*ptr == '.')
                    ptr++;
                while (*ptr >= '0' && *ptr <= '9')
                    ptr++;
                /* Either 'le', 'lf' or 'lg' must follow here */
                if (*ptr++ != 'l')
                    return 1;
                if (*ptr == 'e' || *ptr == 'f' || *ptr == 'g')
                    ptr++;
                else
                    return 1;
                n++;
            }
        }

    return (n != 1);
}


int vdef_parse(
    struct graph_desc_t
    *gdes,
    const char *const str)
{
    /* A VDEF currently is either "func" or "param,func"
     * so the parsing is rather simple.  Change if needed.
     */
    double    param;
    char      func[30];
    int       n;

    n = 0;
    sscanf(str, "%le,%29[A-Z]%n", &param, func, &n);
    if (n == (int) strlen(str)) {   /* matched */
        ;
    } else {
        n = 0;
        sscanf(str, "%29[A-Z]%n", func, &n);
        if (n == (int) strlen(str)) {   /* matched */
            param = DNAN;
        } else {
            rrd_set_error
                ("Unknown function string '%s' in VDEF '%s'",
                 str, gdes->vname);
            return -1;
        }
    }
    if (!strcmp("PERCENT", func))
        gdes->vf.op = VDEF_PERCENT;
    else if (!strcmp("PERCENTNAN", func))
        gdes->vf.op = VDEF_PERCENTNAN;
    else if (!strcmp("MAXIMUM", func))
        gdes->vf.op = VDEF_MAXIMUM;
    else if (!strcmp("AVERAGE", func))
        gdes->vf.op = VDEF_AVERAGE;
    else if (!strcmp("STDEV", func))
        gdes->vf.op = VDEF_STDEV;
    else if (!strcmp("MINIMUM", func))
        gdes->vf.op = VDEF_MINIMUM;
    else if (!strcmp("TOTAL", func))
        gdes->vf.op = VDEF_TOTAL;
    else if (!strcmp("FIRST", func))
        gdes->vf.op = VDEF_FIRST;
    else if (!strcmp("LAST", func))
        gdes->vf.op = VDEF_LAST;
    else if (!strcmp("LSLSLOPE", func))
        gdes->vf.op = VDEF_LSLSLOPE;
    else if (!strcmp("LSLINT", func))
        gdes->vf.op = VDEF_LSLINT;
    else if (!strcmp("LSLCORREL", func))
        gdes->vf.op = VDEF_LSLCORREL;
    else {
        rrd_set_error
            ("Unknown function '%s' in VDEF '%s'\n", func, gdes->vname);
        return -1;
    };
    switch (gdes->vf.op) {
    case VDEF_PERCENT:
    case VDEF_PERCENTNAN:
        if (isnan(param)) { /* no parameter given */
            rrd_set_error
                ("Function '%s' needs parameter in VDEF '%s'\n",
                 func, gdes->vname);
            return -1;
        };
        if (param >= 0.0 && param <= 100.0) {
            gdes->vf.param = param;
            gdes->vf.val = DNAN;    /* undefined */
            gdes->vf.when = 0;  /* undefined */
        } else {
            rrd_set_error
                ("Parameter '%f' out of range in VDEF '%s'\n",
                 param, gdes->vname);
            return -1;
        };
        break;
    case VDEF_MAXIMUM:
    case VDEF_AVERAGE:
    case VDEF_STDEV:
    case VDEF_MINIMUM:
    case VDEF_TOTAL:
    case VDEF_FIRST:
    case VDEF_LAST:
    case VDEF_LSLSLOPE:
    case VDEF_LSLINT:
    case VDEF_LSLCORREL:
        if (isnan(param)) {
            gdes->vf.param = DNAN;
            gdes->vf.val = DNAN;
            gdes->vf.when = 0;
        } else {
            rrd_set_error
                ("Function '%s' needs no parameter in VDEF '%s'\n",
                 func, gdes->vname);
            return -1;
        };
        break;
    };
    return 0;
}


int vdef_calc(
    image_desc_t *im,
    int gdi)
{
    graph_desc_t *src, *dst;
    rrd_value_t *data;
    long      step, steps;

    dst = &im->gdes[gdi];
    src = &im->gdes[dst->vidx];
    data = src->data + src->ds;

    steps = (src->end - src->start) / src->step;
#if 0
    printf
        ("DEBUG: start == %lu, end == %lu, %lu steps\n",
         src->start, src->end, steps);
#endif
    switch (dst->vf.op) {
    case VDEF_PERCENT:{
        rrd_value_t *array;
        int       field;
        if ((array = (rrd_value_t*)malloc(steps * sizeof(double))) == NULL) {
            rrd_set_error("malloc VDEV_PERCENT");
            return -1;
        }
        for (step = 0; step < steps; step++) {
            array[step] = data[step * src->ds_cnt];
        }
        qsort(array, step, sizeof(double), vdef_percent_compar);
        field = round((dst->vf.param * (double)(steps - 1)) / 100.0);
        dst->vf.val = array[field];
        dst->vf.when = 0;   /* no time component */
        free(array);
#if 0
        for (step = 0; step < steps; step++)
            printf("DEBUG: %3li:%10.2f %c\n",
                   step, array[step], step == field ? '*' : ' ');
#endif
    }
        break;
    case VDEF_PERCENTNAN:{
        rrd_value_t *array;
        int       field;
       /* count number of "valid" values */
       int nancount=0;
       for (step = 0; step < steps; step++) {
         if (!isnan(data[step * src->ds_cnt])) { nancount++; }
       }
       /* and allocate it */
        if ((array = (rrd_value_t*)malloc(nancount * sizeof(double))) == NULL) {
            rrd_set_error("malloc VDEV_PERCENT");
            return -1;
        }
       /* and fill it in */
       field=0;
        for (step = 0; step < steps; step++) {
           if (!isnan(data[step * src->ds_cnt])) {
                array[field] = data[step * src->ds_cnt];
               field++;
            }
        }
        qsort(array, nancount, sizeof(double), vdef_percent_compar);
        field = round( dst->vf.param * (double)(nancount - 1) / 100.0);
        dst->vf.val = array[field];
        dst->vf.when = 0;   /* no time component */
        free(array);
    }
        break;
    case VDEF_MAXIMUM:
        step = 0;
        while (step != steps && isnan(data[step * src->ds_cnt]))
            step++;
        if (step == steps) {
            dst->vf.val = DNAN;
            dst->vf.when = 0;
        } else {
            dst->vf.val = data[step * src->ds_cnt];
            dst->vf.when = src->start + (step + 1) * src->step;
        }
        while (step != steps) {
            if (finite(data[step * src->ds_cnt])) {
                if (data[step * src->ds_cnt] > dst->vf.val) {
                    dst->vf.val = data[step * src->ds_cnt];
                    dst->vf.when = src->start + (step + 1) * src->step;
                }
            }
            step++;
        }
        break;
    case VDEF_TOTAL:
    case VDEF_STDEV:
    case VDEF_AVERAGE:{
        int       cnt = 0;
        double    sum = 0.0;
        double    average = 0.0;

        for (step = 0; step < steps; step++) {
            if (finite(data[step * src->ds_cnt])) {
                sum += data[step * src->ds_cnt];
                cnt++;
            };
        }
        if (cnt) {
            if (dst->vf.op == VDEF_TOTAL) {
                dst->vf.val = sum * src->step;
                dst->vf.when = 0;   /* no time component */
            } else if (dst->vf.op == VDEF_AVERAGE) {
                dst->vf.val = sum / cnt;
                dst->vf.when = 0;   /* no time component */
            } else {
                average = sum / cnt;
                sum = 0.0;
                for (step = 0; step < steps; step++) {
                    if (finite(data[step * src->ds_cnt])) {
                        sum += pow((data[step * src->ds_cnt] - average), 2.0);
                    };
                }
                dst->vf.val = pow(sum / cnt, 0.5);
                dst->vf.when = 0;   /* no time component */
            };
        } else {
            dst->vf.val = DNAN;
            dst->vf.when = 0;
        }
    }
        break;
    case VDEF_MINIMUM:
        step = 0;
        while (step != steps && isnan(data[step * src->ds_cnt]))
            step++;
        if (step == steps) {
            dst->vf.val = DNAN;
            dst->vf.when = 0;
        } else {
            dst->vf.val = data[step * src->ds_cnt];
            dst->vf.when = src->start + (step + 1) * src->step;
        }
        while (step != steps) {
            if (finite(data[step * src->ds_cnt])) {
                if (data[step * src->ds_cnt] < dst->vf.val) {
                    dst->vf.val = data[step * src->ds_cnt];
                    dst->vf.when = src->start + (step + 1) * src->step;
                }
            }
            step++;
        }
        break;
    case VDEF_FIRST:
        /* The time value returned here is one step before the
         * actual time value.  This is the start of the first
         * non-NaN interval.
         */
        step = 0;
        while (step != steps && isnan(data[step * src->ds_cnt]))
            step++;
        if (step == steps) {    /* all entries were NaN */
            dst->vf.val = DNAN;
            dst->vf.when = 0;
        } else {
            dst->vf.val = data[step * src->ds_cnt];
            dst->vf.when = src->start + step * src->step;
        }
        break;
    case VDEF_LAST:
        /* The time value returned here is the
         * actual time value.  This is the end of the last
         * non-NaN interval.
         */
        step = steps - 1;
        while (step >= 0 && isnan(data[step * src->ds_cnt]))
            step--;
        if (step < 0) { /* all entries were NaN */
            dst->vf.val = DNAN;
            dst->vf.when = 0;
        } else {
            dst->vf.val = data[step * src->ds_cnt];
            dst->vf.when = src->start + (step + 1) * src->step;
        }
        break;
    case VDEF_LSLSLOPE:
    case VDEF_LSLINT:
    case VDEF_LSLCORREL:{
        /* Bestfit line by linear least squares method */

        int       cnt = 0;
        double    SUMx, SUMy, SUMxy, SUMxx, SUMyy, slope, y_intercept, correl;

        SUMx = 0;
        SUMy = 0;
        SUMxy = 0;
        SUMxx = 0;
        SUMyy = 0;
        for (step = 0; step < steps; step++) {
            if (finite(data[step * src->ds_cnt])) {
                cnt++;
                SUMx += step;
                SUMxx += step * step;
                SUMxy += step * data[step * src->ds_cnt];
                SUMy += data[step * src->ds_cnt];
                SUMyy += data[step * src->ds_cnt] * data[step * src->ds_cnt];
            };
        }

        slope = (SUMx * SUMy - cnt * SUMxy) / (SUMx * SUMx - cnt * SUMxx);
        y_intercept = (SUMy - slope * SUMx) / cnt;
        correl =
            (SUMxy -
             (SUMx * SUMy) / cnt) /
            sqrt((SUMxx -
                  (SUMx * SUMx) / cnt) * (SUMyy - (SUMy * SUMy) / cnt));
        if (cnt) {
            if (dst->vf.op == VDEF_LSLSLOPE) {
                dst->vf.val = slope;
                dst->vf.when = 0;
            } else if (dst->vf.op == VDEF_LSLINT) {
                dst->vf.val = y_intercept;
                dst->vf.when = 0;
            } else if (dst->vf.op == VDEF_LSLCORREL) {
                dst->vf.val = correl;
                dst->vf.when = 0;
            };
        } else {
            dst->vf.val = DNAN;
            dst->vf.when = 0;
        }
    }
        break;
    }
    return 0;
}

/* NaN < -INF < finite_values < INF */
int vdef_percent_compar(
    const void
    *a,
    const void
    *b)
{
    /* Equality is not returned; this doesn't hurt except
     * (maybe) for a little performance.
     */

    /* First catch NaN values. They are smallest */
    if (isnan(*(double *) a))
        return -1;
    if (isnan(*(double *) b))
        return 1;
    /* NaN doesn't reach this part so INF and -INF are extremes.
     * The sign from isinf() is compatible with the sign we return
     */
    if (isinf(*(double *) a))
        return isinf(*(double *) a);
    if (isinf(*(double *) b))
        return isinf(*(double *) b);
    /* If we reach this, both values must be finite */
    if (*(double *) a < *(double *) b)
        return -1;
    else
        return 1;
}

void grinfo_push(
    image_desc_t *im,
    char *key,
    rrd_info_type_t type,
    rrd_infoval_t value)
{
    im->grinfo_current = rrd_info_push(im->grinfo_current, key, type, value);
    if (im->grinfo == NULL) {
        im->grinfo = im->grinfo_current;
    }
}
