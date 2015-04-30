/****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 ****************************************************************************
 * rrd_gfx.c  graphics wrapper for rrdtool
  **************************************************************************/

/* #define DEBUG */

/* stupid MSVC doesnt support variadic macros = no debug for now! */
#ifdef _MSC_VER
# define RRDPRINTF()
#else
# ifdef DEBUG
#  define RRDPRINTF(...)  fprintf(stderr, __VA_ARGS__);
# else
#  define RRDPRINTF(...)
# endif                         /* DEBUG */
#endif                          /* _MSC_VER */

#include "rrd_tool.h"
#include "rrd_graph.h"


/* create a new line */
void gfx_line(
    image_desc_t *im,
    double X0,
    double Y0,
    double X1,
    double Y1,
    double width,
    gfx_color_t color)
{
    gfx_dashed_line(im, X0, Y0, X1, Y1, width, color, 0, 0);
}

void gfx_dashed_line(
    image_desc_t *im,
    double X0,
    double Y0,
    double X1,
    double Y1,
    double width,
    gfx_color_t color,
    double dash_on,
    double dash_off)
{
    cairo_t  *cr = im->cr;
    double    dashes[2];
    double    x = 0;
    double    y = 0;

    dashes[0] = dash_on;
    dashes[1] = dash_off;

    cairo_save(cr);
    cairo_new_path(cr);
    cairo_set_line_width(cr, width);
    gfx_line_fit(im, &x, &y);
    gfx_line_fit(im, &X0, &Y0);
    cairo_move_to(cr, X0, Y0);
    gfx_line_fit(im, &X1, &Y1);
    cairo_line_to(cr, X1, Y1);
    if (dash_on > 0 || dash_off > 0)
        cairo_set_dash(cr, dashes, 2, x);
    cairo_set_source_rgba(cr, color.red, color.green, color.blue,
                          color.alpha);
    cairo_stroke(cr);
    cairo_restore(cr);
}

/* create a new area */
void gfx_new_area(
    image_desc_t *im,
    double X0,
    double Y0,
    double X1,
    double Y1,
    double X2,
    double Y2,
    gfx_color_t color)
{
    cairo_t  *cr = im->cr;

    cairo_new_path(cr);
    gfx_area_fit(im, &X0, &Y0);
    cairo_move_to(cr, X0, Y0);
    gfx_area_fit(im, &X1, &Y1);
    cairo_line_to(cr, X1, Y1);
    gfx_area_fit(im, &X2, &Y2);
    cairo_line_to(cr, X2, Y2);
    cairo_set_source_rgba(cr, color.red, color.green, color.blue,
                          color.alpha);
}

/* add a point to a line or to an area */
void gfx_add_point(
    image_desc_t *im,
    double x,
    double y)
{
    cairo_t  *cr = im->cr;

    gfx_area_fit(im, &x, &y);
    cairo_line_to(cr, x, y);
}

void gfx_close_path(
    image_desc_t *im)
{
    cairo_t  *cr = im->cr;

    cairo_close_path(cr);
    cairo_fill(cr);
}

/* create a text node */
static PangoLayout *gfx_prep_text(
    image_desc_t *im,
    double x,
    gfx_color_t color,
    PangoFontDescription *font_desc,
    double tabwidth,
    const char *text)
{
    PangoLayout  *layout = im->layout;
    const PangoFontDescription *pfd;
    cairo_t  *cr = im->cr;

    static double last_tabwidth = -1;



    /* for performance reasons we might
       want todo that only once ... tabs will always
       be the same */
    long      i;
    long      tab_count = strlen(text);
    long      tab_shift = fmod(x, tabwidth);
    int       border = im->text_prop[TEXT_PROP_LEGEND].size * 2.0;
    
    gchar    *utf8_text;

    if (last_tabwidth < 0 || last_tabwidth != tabwidth){
        PangoTabArray *tab_array;
        // fprintf(stderr,"t");
        last_tabwidth = tabwidth;
        tab_array = pango_tab_array_new(tab_count, (gboolean) (1));
        for (i = 1; i <= tab_count; i++) {
             pango_tab_array_set_tab(tab_array,
                                     i, PANGO_TAB_LEFT,
                                     tabwidth * i - tab_shift + border);
        }
        pango_layout_set_tabs(layout, tab_array);
        pango_tab_array_free(tab_array);
    }
   pfd = pango_layout_get_font_description(layout);

   if (!pfd || !pango_font_description_equal (pfd,font_desc)){
        pango_layout_set_font_description(layout, font_desc);
  }
//   fprintf(stderr,"%s\n",pango_font_description_to_string(pango_layout_get_font_description(layout))); 

   cairo_new_path(cr);
   cairo_set_source_rgba(cr, color.red, color.green, color.blue,
                          color.alpha);
/*     layout = pango_cairo_create_layout(cr); */

//    pango_cairo_context_set_font_options(pango_context, im->font_options);
//    pango_cairo_context_set_resolution(pango_context, 100);

/*     pango_cairo_update_context(cr, pango_context); */


    /* pango expects the string to be utf-8 encoded */
    utf8_text = g_locale_to_utf8((const gchar *) text, -1, NULL, NULL, NULL);

    /* In case of an error, i.e. utf8_text == NULL (locale settings messed
     * up?), we fall back to a possible "invalid UTF-8 string" warning instead
     * of provoking a failed assertion in libpango. */
    if (im->with_markup)
        pango_layout_set_markup(layout, utf8_text ? utf8_text : text, -1);
    else
        pango_layout_set_text(layout, utf8_text ? utf8_text : text, -1);

    g_free(utf8_text);
    return layout;
}

/* Size Text Node */
double gfx_get_text_width(
    image_desc_t *im,
    double start,
    PangoFontDescription *font_desc,
    double tabwidth,
    char *text)
{
    PangoLayout *layout;
    PangoRectangle log_rect;
    gfx_color_t color = { 0, 0, 0, 0 };
    layout = gfx_prep_text(im, start, color, font_desc, tabwidth, text);
    pango_layout_get_pixel_extents(layout, NULL, &log_rect);
/*    g_object_unref(layout); */
    return log_rect.width;
}

void gfx_text(
    image_desc_t *im,
    double x,
    double y,
    gfx_color_t color,
    PangoFontDescription *font_desc,
    double tabwidth,
    double angle,
    enum gfx_h_align_en h_align,
    enum gfx_v_align_en v_align,
    const char *text)
{
    PangoLayout *layout;
    PangoRectangle log_rect;
    cairo_t  *cr = im->cr;
    double    sx = 0;
    double    sy = 0;

    cairo_save(cr);
    cairo_translate(cr, x, y);
/*    gfx_line(cr,-2,0,2,0,1,color);
    gfx_line(cr,0,-2,0,2,1,color); */
    layout = gfx_prep_text(im, x, color, font_desc, tabwidth, text);
    pango_layout_get_pixel_extents(layout, NULL, &log_rect);
    cairo_rotate(cr, -angle * G_PI / 180.0);
    sx = log_rect.x;
    switch (h_align) {
    case GFX_H_RIGHT:
        sx -= log_rect.width;
        break;
    case GFX_H_CENTER:
        sx -= log_rect.width / 2;
        break;
    case GFX_H_LEFT:
        break;
    case GFX_H_NULL:
        break;
    }
    sy = log_rect.y;
    switch (v_align) {
    case GFX_V_TOP:
        break;
    case GFX_V_CENTER:
        sy -= log_rect.height / 2;
        break;
    case GFX_V_BOTTOM:
        sy -= log_rect.height;
        break;
    case GFX_V_NULL:
        break;
    }
    pango_cairo_update_layout(cr, layout);
    cairo_move_to(cr, sx, sy);
    pango_cairo_show_layout(cr, layout);
/*    g_object_unref(layout); */
    cairo_restore(cr);

}

/* convert color */
struct gfx_color_t gfx_hex_to_col(
    long unsigned int color)
{
    struct gfx_color_t gfx_color;

    gfx_color.red = 1.0 / 255.0 * ((color & 0xff000000) >> (3 * 8));
    gfx_color.green = 1.0 / 255.0 * ((color & 0x00ff0000) >> (2 * 8));
    gfx_color.blue = 1.0 / 255.0 * ((color & 0x0000ff00) >> (1 * 8));
    gfx_color.alpha = 1.0 / 255.0 * (color & 0x000000ff);
    return gfx_color;
}

/* gridfit_lines */

void gfx_line_fit(
    image_desc_t *im,
    double *x,
    double *y)
{
    cairo_t  *cr = im->cr;
    double    line_width;
    double    line_height;

    if (!im->gridfit)
        return;
    cairo_user_to_device(cr, x, y);
    line_width = cairo_get_line_width(cr);
    line_height = line_width;
    cairo_user_to_device_distance(cr, &line_width, &line_height);
    line_width = line_width / 2.0 - ceil(line_width / 2.0);
    line_height = line_height / 2.0 - ceil(line_height / 2.0);
    *x = floor(*x - 0.5) - line_width;
    *y = ceil(*y + 0.5) + line_height;
    cairo_device_to_user(cr, x, y);
}

/* gridfit_areas */

void gfx_area_fit(
    image_desc_t *im,
    double *x,
    double *y)
{
    cairo_t  *cr = im->cr;

    if (!im->gridfit)
        return;
    cairo_user_to_device(cr, x, y);
    *x = floor(*x);
    *y = ceil(*y);
    cairo_device_to_user(cr, x, y);
}
