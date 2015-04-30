#ifndef _RRD_GRAPH_H
#define _RRD_GRAPH_H

#define y0 cairo_y0
#define y1 cairo_y1
#define index cairo_index

/* this may configure __EXTENSIONS__ without which pango will fail to compile
   so load this early */
#if defined(_WIN32) && !defined(__CYGWIN__) && !defined(__CYGWIN32__)
#include "../win32/config.h"
#else
#ifdef HAVE_CONFIG_H
#include "../rrd_config.h"
#endif
#endif

#include <cairo.h>
#include <cairo-pdf.h>
#include <cairo-svg.h>
#include <cairo-ps.h>

#include <pango/pangocairo.h>


#include "rrd_tool.h"
#include "rrd_rpncalc.h"

#ifdef WIN32
#  include <windows.h>
#  define MAXPATH MAX_PATH
#endif

#define ALTYGRID  	 0x01   /* use alternative y grid algorithm */
#define ALTAUTOSCALE	 0x02   /* use alternative algorithm to find lower and upper bounds */
#define ALTAUTOSCALE_MIN 0x04   /* use alternative algorithm to find lower bounds */
#define ALTAUTOSCALE_MAX 0x08   /* use alternative algorithm to find upper bounds */
#define NOLEGEND	 0x10   /* use no legend */
#define NOMINOR          0x20   /* Turn off minor gridlines */
#define ONLY_GRAPH       0x40   /* use only graph */
#define FORCE_RULES_LEGEND 0x80 /* force printing of HRULE and VRULE legend */

#define FORCE_UNITS 0x100   /* mask for all FORCE_UNITS_* flags */
#define FORCE_UNITS_SI 0x100    /* force use of SI units in Y axis (no effect in linear graph, SI instead of E in log graph) */

#define FULL_SIZE_MODE     0x200    /* -width and -height indicate the total size of the image */
#define NO_RRDTOOL_TAG 0x400  /* disable the rrdtool tag */

#define gdes_fetch_key(x)  sprintf_alloc("%s:%d:%d:%d:%d",x.rrd,x.cf,x.cf_reduce,x.start_orig,x.end_orig,x.step_orig)

enum tmt_en { TMT_SECOND = 0, TMT_MINUTE, TMT_HOUR, TMT_DAY,
    TMT_WEEK, TMT_MONTH, TMT_YEAR
};

enum grc_en { GRC_CANVAS = 0, GRC_BACK, GRC_SHADEA, GRC_SHADEB,
    GRC_GRID, GRC_MGRID, GRC_FONT, GRC_ARROW, GRC_AXIS, GRC_FRAME, __GRC_END__
};

#define MGRIDWIDTH 0.6
#define GRIDWIDTH  0.4

enum gf_en { GF_PRINT = 0, GF_GPRINT, GF_COMMENT, GF_HRULE, GF_VRULE, GF_LINE,
    GF_AREA, GF_STACK, GF_TICK, GF_TEXTALIGN,
    GF_DEF, GF_CDEF, GF_VDEF, GF_SHIFT,
    GF_XPORT
};

enum txa_en { TXA_LEFT = 0, TXA_RIGHT, TXA_CENTER, TXA_JUSTIFIED };

enum vdef_op_en {
    VDEF_MAXIMUM = 0    /* like the MAX in (G)PRINT */
        , VDEF_MINIMUM  /* like the MIN in (G)PRINT */
        , VDEF_AVERAGE  /* like the AVERAGE in (G)PRINT */
        , VDEF_STDEV    /* the standard deviation */
        , VDEF_PERCENT  /* Nth percentile */
        , VDEF_TOTAL    /* average multiplied by time */
        , VDEF_FIRST    /* first non-unknown value and time */
        , VDEF_LAST     /* last  non-unknown value and time */
        , VDEF_LSLSLOPE /* least squares line slope */
        , VDEF_LSLINT   /* least squares line y_intercept */
        , VDEF_LSLCORREL    /* least squares line correlation coefficient */
        , VDEF_PERCENTNAN  /* Nth percentile ignoring NAN*/
};
enum text_prop_en { 
    TEXT_PROP_DEFAULT = 0,  /* default settings */
    TEXT_PROP_TITLE,    /* properties for the title */
    TEXT_PROP_AXIS,     /* for the numbers next to the axis */
    TEXT_PROP_UNIT,     /* for the vertical unit description */
    TEXT_PROP_LEGEND,   /* for the legend below the graph */
    TEXT_PROP_WATERMARK, /* for the little text to the side of the graph */
    TEXT_PROP_LAST
};

enum legend_pos{ NORTH = 0, WEST, SOUTH, EAST };
enum legend_direction { TOP_DOWN = 0, BOTTOM_UP };

enum gfx_if_en { IF_PNG = 0, IF_SVG, IF_EPS, IF_PDF };
enum gfx_en { GFX_LINE = 0, GFX_AREA, GFX_TEXT };
enum gfx_h_align_en { GFX_H_NULL = 0, GFX_H_LEFT, GFX_H_RIGHT, GFX_H_CENTER };
enum gfx_v_align_en { GFX_V_NULL = 0, GFX_V_TOP, GFX_V_BOTTOM, GFX_V_CENTER };

/* cairo color components */
typedef struct gfx_color_t {
    double    red;
    double    green;
    double    blue;
    double    alpha;
} gfx_color_t;


typedef struct text_prop_t {
    double    size;
    char      font[1024];
    PangoFontDescription *font_desc;
} text_prop_t;


typedef struct vdef_t {
    enum vdef_op_en op;
    double    param;    /* parameter for function, if applicable */
    double    val;      /* resulting value */
    time_t    when;     /* timestamp, if applicable */
} vdef_t;

typedef struct xlab_t {
    long      minsec;   /* minimum sec per pix */
    long      length;   /* number of secs on the image */
    enum tmt_en gridtm; /* grid interval in what ? */
    long      gridst;   /* how many whats per grid */
    enum tmt_en mgridtm;    /* label interval in what ? */
    long      mgridst;  /* how many whats per label */
    enum tmt_en labtm;  /* label interval in what ? */
    long      labst;    /* how many whats per label */
    long      precis;   /* label precision -> label placement */
    char     *stst;     /* strftime string */
} xlab_t;

typedef struct ygrid_scale_t {  /* y axis grid scaling info */
    double    gridstep;
    int       labfact;
    char      labfmt[64];
} ygrid_scale_t;

/* sensible y label intervals ...*/

typedef struct ylab_t {
    double    grid;     /* grid spacing */
    int       lfac[4];  /* associated label spacing */
} ylab_t;

/* this structure describes the elements which can make up a graph.
   because they are quite diverse, not all elements will use all the
   possible parts of the structure. */
#ifdef HAVE_SNPRINTF
#define FMT_LEG_LEN 200
#else
#define FMT_LEG_LEN 2000
#endif

typedef struct graph_desc_t {
    enum gf_en gf;      /* graphing function */
    int       stack;    /* boolean */
    int       debug;    /* boolean */
    int       skipscale; /* boolean */
    char      vname[MAX_VNAME_LEN + 1]; /* name of the variable */
    long      vidx;     /* gdes reference */
    char      rrd[1024];    /* name of the rrd_file containing data */
    char      ds_nam[DS_NAM_SIZE];  /* data source name */
    long      ds;       /* data source number */
    enum cf_en cf;      /* consolidation function */
    enum cf_en cf_reduce;   /* consolidation function for reduce_data() */
    struct gfx_color_t col; /* graph color */
    char      format[FMT_LEG_LEN + 5];  /* format for PRINT AND GPRINT */
    char      legend[FMT_LEG_LEN + 5];  /* legend */
    int       strftm;   /* should the VDEF legend be formated with strftime */
    double    leg_x, leg_y; /* location of legend */
    double    yrule;    /* value for y rule line and for VDEF */
    time_t    xrule;    /* time for x rule line and for VDEF */
    vdef_t    vf;       /* instruction for VDEF function */
    rpnp_t   *rpnp;     /* instructions for CDEF function */

    /* SHIFT implementation */
    int       shidx;    /* gdes reference for offset (-1 --> constant) */
    time_t    shval;    /* offset if shidx is -1 */
    time_t    shift;    /* current shift applied */

    /* description of data fetched for the graph element */
    time_t    start, end;   /* timestaps for first and last data element */
    time_t    start_orig, end_orig; /* timestaps for first and last data element */
    unsigned long step; /* time between samples */
    unsigned long step_orig;    /* time between samples */
    unsigned long ds_cnt;   /* how many data sources are there in the fetch */
    long      data_first;   /* first pointer to this data */
    char    **ds_namv;  /* name of datasources  in the fetch. */
    rrd_value_t *data;  /* the raw data drawn from the rrd */
    rrd_value_t *p_data;    /* processed data, xsize elments */
    double    linewidth;    /* linewideth */

    /* dashed line stuff */
    int       dash;     /* boolean, draw dashed line? */
    double   *p_dashes; /* pointer do dash array which keeps the lengths of dashes */
    int       ndash;    /* number of dash segments */
    double    offset;   /* dash offset along the line */


    enum txa_en txtalign;   /* change default alignment strategy for text */
} graph_desc_t;

typedef struct image_desc_t {

    /* configuration of graph */

    char      graphfile[MAXPATH];   /* filename for graphic */
    long      xsize, ysize; /* graph area size in pixels */
    struct gfx_color_t graph_col[__GRC_END__];  /* real colors for the graph */
    text_prop_t text_prop[TEXT_PROP_LAST];  /* text properties */
    char      ylegend[210]; /* legend along the yaxis */
    char      title[210];   /* title for graph */
    char      watermark[110];   /* watermark for graph */
    int       draw_x_grid;  /* no x-grid at all */
    int       draw_y_grid;  /* no y-grid at all */
    unsigned int draw_3d_border; /* size of border in pixels, 0 for off */
    unsigned int dynamic_labels; /* pick the label shape according to the line drawn */
    double    grid_dash_on, grid_dash_off;
    xlab_t    xlab_user;    /* user defined labeling for xaxis */
    char      xlab_form[210];   /* format for the label on the xaxis */
    double    second_axis_scale; /* relative to the first axis (0 to disable) */
    double    second_axis_shift; /* how much is it shifted vs the first axis */
    char      second_axis_legend[210]; /* label to put on the seond axis */
    char      second_axis_format[210]; /* format for the numbers on the scond axis */    

    double    ygridstep;    /* user defined step for y grid */
    int       ylabfact; /* every how many y grid shall a label be written ? */
    double    tabwidth; /* tabwdith */
    time_t    start, end;   /* what time does the graph cover */
    unsigned long step; /* any preference for the default step ? */
    rrd_value_t minval, maxval; /* extreme values in the data */
    int       rigid;    /* do not expand range even with 
                           values outside */
    ygrid_scale_t ygrid_scale;  /* calculated y axis grid info */
    int       gridfit;  /* adjust y-axis range etc so all
                           grindlines falls in integer pixel values */
    char     *imginfo;  /* construct an <IMG ... tag and return 
                           as first retval */
    enum gfx_if_en imgformat;   /* image format */
    char     *daemon_addr;  /* rrdcached connection string */
    int       lazy;     /* only update the image if there is
                           reasonable probablility that the
                           existing one is out of date */
    int       slopemode;    /* connect the dots of the curve directly, not using a stair */
    enum legend_pos legendposition; /* the position of the legend: north, west, south or east */
    enum legend_direction legenddirection; /* The direction of the legend topdown or bottomup */
    int       logarithmic;  /* scale the yaxis logarithmic */
    double    force_scale_min;  /* Force a scale--min */
    double    force_scale_max;  /* Force a scale--max */

    /* status information */
    int       with_markup;
    long      xorigin, yorigin; /* where is (0,0) of the graph */
    long      xOriginTitle, yOriginTitle; /* where is the origin of the title */
    long      xOriginLegendY, yOriginLegendY; /* where is the origin of the y legend */
    long      xOriginLegendY2, yOriginLegendY2; /* where is the origin of the second y legend */
    long      xOriginLegend, yOriginLegend; /* where is the origin of the legend */
    long      ximg, yimg;   /* total size of the image */
    long      legendwidth, legendheight; /* the calculated height and width of the legend */
    size_t    rendered_image_size;
    double    zoom;
    double    magfact;  /* numerical magnitude */
    long      base;     /* 1000 or 1024 depending on what we graph */
    char      symbol;   /* magnitude symbol for y-axis */
    float     viewfactor;   /* how should the numbers on the y-axis be scaled for viewing ? */
    int       unitsexponent;    /* 10*exponent for units on y-asis */
    int       unitslength;  /* width of the yaxis labels */
    int       forceleftspace;   /* do not kill the space to the left of the y-axis if there is no grid */

    int       extra_flags;  /* flags for boolean options */
    /* data elements */

    unsigned char *rendered_image;
    long      prt_c;    /* number of print elements */
    long      gdes_c;   /* number of graphics elements */
    graph_desc_t *gdes; /* points to an array of graph elements */
    cairo_surface_t *surface;   /* graphics library */
    cairo_t  *cr;       /* drawin context */
    cairo_font_options_t *font_options; /* cairo font options */
    cairo_antialias_t graph_antialias;  /* antialiasing for the graph */
    PangoLayout *layout; /* the pango layout we use for writing fonts */
    rrd_info_t *grinfo; /* root pointer to extra graph info */
    rrd_info_t *grinfo_current; /* pointing to current entry */
    GHashTable* gdef_map;  /* a map of all *def gdef entries for quick access */
    GHashTable* rrd_map;  /* a map of all rrd files in use for gdef entries */
} image_desc_t;

/* Prototypes */
int       xtr(
    image_desc_t *,
    time_t);
double    ytr(
    image_desc_t *,
    double);
enum gf_en gf_conv(
    char *);
enum gfx_if_en if_conv(
    char *);
enum tmt_en tmt_conv(
    char *);
enum grc_en grc_conv(
    char *);
enum text_prop_en text_prop_conv(
    char *);
int       im_free(
    image_desc_t *);
void      auto_scale(
    image_desc_t *,
    double *,
    char **,
    double *);
void      si_unit(
    image_desc_t *);
void      expand_range(
    image_desc_t *);
void      apply_gridfit(
    image_desc_t *);
void      reduce_data(
    enum cf_en,
    unsigned long,
    time_t *,
    time_t *,
    unsigned long *,
    unsigned long *,
    rrd_value_t **);
int       data_fetch(
    image_desc_t *);
long      find_var(
    image_desc_t *,
    char *);
long      find_var_wrapper(
    void *arg1,
    char *key);
long      lcd(
    long *);
int       data_calc(
    image_desc_t *);
int       data_proc(
    image_desc_t *);
time_t    find_first_time(
    time_t,
    enum tmt_en,
    long);
time_t    find_next_time(
    time_t,
    enum tmt_en,
    long);
int       print_calc(
    image_desc_t *);
int       leg_place(
    image_desc_t *,
    int);
int       calc_horizontal_grid(
    image_desc_t *);
int       draw_horizontal_grid(
    image_desc_t *);
int       horizontal_log_grid(
    image_desc_t *);
void      vertical_grid(
    image_desc_t *);
void      axis_paint(
    image_desc_t *);
void      grid_paint(
    image_desc_t *);
int       lazy_check(
    image_desc_t *);
int       graph_paint(
    image_desc_t *);

int       gdes_alloc(
    image_desc_t *);
int       scan_for_col(
    const char *const,
    int,
    char *const);
void      rrd_graph_init(
    image_desc_t *);

void      rrd_graph_options(
    int,
    char **,
    image_desc_t *);
void      rrd_graph_script(
    int,
    char **,
    image_desc_t *,
    int);
int       rrd_graph_color(
    image_desc_t *,
    char *,
    char *,
    int);
int       bad_format(
    char *);
int       vdef_parse(
    struct graph_desc_t *,
    const char *const);
int       vdef_calc(
    image_desc_t *,
    int);
int       vdef_percent_compar(
    const void *,
    const void *);
int       graph_size_location(
    image_desc_t *,
    int);


/* create a new line */
void      gfx_line(
    image_desc_t *im,
    double X0,
    double Y0,
    double X1,
    double Y1,
    double width,
    gfx_color_t color);

void      gfx_dashed_line(
    image_desc_t *im,
    double X0,
    double Y0,
    double X1,
    double Y1,
    double width,
    gfx_color_t color,
    double dash_on,
    double dash_off);

/* create a new area */
void      gfx_new_area(
    image_desc_t *im,
    double X0,
    double Y0,
    double X1,
    double Y1,
    double X2,
    double Y2,
    gfx_color_t color);

/* add a point to a line or to an area */
void      gfx_add_point(
    image_desc_t *im,
    double x,
    double y);

/* close current path so it ends at the same point as it started */
void      gfx_close_path(
    image_desc_t *im);


/* create a text node */
void      gfx_text(
    image_desc_t *im,
    double x,
    double y,
    gfx_color_t color,
    PangoFontDescription *font_desc,
    double tabwidth,
    double angle,
    enum gfx_h_align_en h_align,
    enum gfx_v_align_en v_align,
    const char *text);

/* measure width of a text string */
double    gfx_get_text_width(
    image_desc_t *im,
    double start,
    PangoFontDescription *font_desc,
    double tabwidth,
    char *text);


/* convert color */
gfx_color_t gfx_hex_to_col(
    long unsigned int);

void      gfx_line_fit(
    image_desc_t *im,
    double *x,
    double *y);

void      gfx_area_fit(
    image_desc_t *im,
    double *x,
    double *y);

#endif

void      grinfo_push(
    image_desc_t *im,
    char *key,
    rrd_info_type_t type,    rrd_infoval_t value);
