/****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 ****************************************************************************
 * rrd_xport.h  contains XML related constants
 ****************************************************************************/
#ifdef  __cplusplus
extern    "C" {
#endif

#ifndef _RRD_XPORT_H
#define _RRD_XPORT_H

#define XML_ENCODING     "ISO-8859-1"
#define ROOT_TAG         "xport"
#define META_TAG         "meta"
#define META_START_TAG   "start"
#define META_STEP_TAG    "step"
#define META_END_TAG     "end"
#define META_ROWS_TAG    "rows"
#define META_COLS_TAG    "columns"
#define LEGEND_TAG       "legend"
#define LEGEND_ENTRY_TAG "entry"
#define DATA_TAG         "data"
#define DATA_ROW_TAG     "row"
#define COL_TIME_TAG     "t"
#define COL_DATA_TAG     "v"


#endif


#ifdef  __cplusplus
}
#endif
