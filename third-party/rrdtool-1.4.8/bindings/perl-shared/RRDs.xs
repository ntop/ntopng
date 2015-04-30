#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef __cplusplus
}
#endif

/*
 * rrd_tool.h includes config.h, but at least on Ubuntu Breezy Badger
 * 5.10 with gcc 4.0.2, the C preprocessor picks up Perl's config.h
 * which is included from the Perl includes and never reads rrdtool's
 * config.h.  Without including rrdtool's config.h, this module does
 * not compile, so include it here with an explicit path.
 *
 * Because rrdtool's config.h redefines VERSION which is originally
 * set via Perl's Makefile.PL and passed down to the C compiler's
 * command line, save the original value and reset it after the
 * includes.
 */
#define VERSION_SAVED VERSION
#undef VERSION
#ifndef WIN32
#include "../../rrd_config.h"
#endif
#include "../../src/rrd_tool.h"
#undef VERSION
#define VERSION VERSION_SAVED
#undef VERSION_SAVED

#define rrdcode(name) \
		argv = (char **) malloc((items+1)*sizeof(char *));\
		argv[0] = "dummy";\
		for (i = 0; i < items; i++) { \
		    STRLEN len; \
		    char *handle= SvPV(ST(i),len);\
		    /* actually copy the data to make sure possible modifications \
		       on the argv data does not backfire into perl */ \
		    argv[i+1] = (char *) malloc((strlen(handle)+1)*sizeof(char)); \
		    strcpy(argv[i+1],handle); \
 	        } \
		rrd_clear_error();\
		RETVAL=name(items+1,argv); \
		for (i=0; i < items; i++) {\
		    free(argv[i+1]);\
		} \
		free(argv);\
		\
		if (rrd_test_error()) XSRETURN_UNDEF;

#define hvs(VAL) hv_store_ent(hash, sv_2mortal(newSVpv(data->key,0)),VAL,0)		    

#define rrdinfocode(name) \
		/* prepare argument list */ \
		argv = (char **) malloc((items+1)*sizeof(char *)); \
		argv[0] = "dummy"; \
		for (i = 0; i < items; i++) { \
		    STRLEN len; \
		    char *handle= SvPV(ST(i),len); \
		    /* actually copy the data to make sure possible modifications \
		       on the argv data does not backfire into perl */ \
		    argv[i+1] = (char *) malloc((strlen(handle)+1)*sizeof(char)); \
		    strcpy(argv[i+1],handle); \
 	        } \
                rrd_clear_error(); \
                data=name(items+1, argv); \
                for (i=0; i < items; i++) { \
		    free(argv[i+1]); \
		} \
		free(argv); \
                if (rrd_test_error()) XSRETURN_UNDEF; \
                hash = newHV(); \
   	        save=data; \
                while (data) { \
		/* the newSV will get copied by hv so we create it as a mortal \
           to make sure it does not keep hanging round after the fact */ \
		    switch (data->type) { \
		    case RD_I_VAL: \
			if (isnan(data->value.u_val)) \
			    hvs(newSV(0)); \
			else \
			    hvs(newSVnv(data->value.u_val)); \
			break; \
			case RD_I_INT: \
			hvs(newSViv(data->value.u_int)); \
			break; \
		    case RD_I_CNT: \
			hvs(newSViv(data->value.u_cnt)); \
			break; \
		    case RD_I_STR: \
			hvs(newSVpv(data->value.u_str,0)); \
			break; \
		    case RD_I_BLO: \
			hvs(newSVpv(data->value.u_blo.ptr,data->value.u_blo.size)); \
			break; \
		    } \
		    data = data->next; \
	        } \
            rrd_info_free(save); \
            RETVAL = newRV_noinc((SV*)hash);

/*
 * should not be needed if libc is linked (see ntmake.pl)
#ifdef WIN32
 #define free free
 #define malloc malloc
 #define realloc realloc
#endif
*/


MODULE = RRDs	PACKAGE = RRDs	PREFIX = rrd_

BOOT:
#ifdef MUST_DISABLE_SIGFPE
	signal(SIGFPE,SIG_IGN);
#endif
#ifdef MUST_DISABLE_FPMASK
	fpsetmask(0);
#endif 

SV*
rrd_error()
	CODE:
		if (! rrd_test_error()) XSRETURN_UNDEF;
                RETVAL = newSVpv(rrd_get_error(),0);
	OUTPUT:
		RETVAL

int
rrd_last(...)
      PROTOTYPE: @
      PREINIT:
      int i;
      char **argv;
      CODE:
              rrdcode(rrd_last);
      OUTPUT:
            RETVAL

int
rrd_first(...)
      PROTOTYPE: @
      PREINIT:
      int i;
      char **argv;
      CODE:
              rrdcode(rrd_first);
      OUTPUT:
            RETVAL

int
rrd_create(...)
	PROTOTYPE: @	
	PREINIT:
        int i;
	char **argv;
	CODE:
		rrdcode(rrd_create);
	        RETVAL = 1;
        OUTPUT:
		RETVAL

int
rrd_update(...)
	PROTOTYPE: @	
	PREINIT:
        int i;
	char **argv;
	CODE:
		rrdcode(rrd_update);
       	        RETVAL = 1;
	OUTPUT:
		RETVAL

int
rrd_tune(...)
	PROTOTYPE: @	
	PREINIT:
        int i;
	char **argv;
	CODE:
		rrdcode(rrd_tune);
       	        RETVAL = 1;
	OUTPUT:
		RETVAL

SV *
rrd_graph(...)
	PROTOTYPE: @	
	PREINIT:
	char **calcpr=NULL;
	int i,xsize,ysize;
	double ymin,ymax;
	char **argv;
	AV *retar;
	PPCODE:
		argv = (char **) malloc((items+1)*sizeof(char *));
		argv[0] = "dummy";
		for (i = 0; i < items; i++) { 
		    STRLEN len;
		    char *handle = SvPV(ST(i),len);
		    /* actually copy the data to make sure possible modifications
		       on the argv data does not backfire into perl */ 
		    argv[i+1] = (char *) malloc((strlen(handle)+1)*sizeof(char));
		    strcpy(argv[i+1],handle);
 	        }
		rrd_clear_error();
		rrd_graph(items+1,argv,&calcpr,&xsize,&ysize,NULL,&ymin,&ymax); 
		for (i=0; i < items; i++) {
		    free(argv[i+1]);
		}
		free(argv);

		if (rrd_test_error()) {
			if(calcpr)
			   for(i=0;calcpr[i];i++)
				rrd_freemem(calcpr[i]);
			XSRETURN_UNDEF;
		}
		retar=newAV();
		if(calcpr){
			for(i=0;calcpr[i];i++){
				 av_push(retar,newSVpv(calcpr[i],0));
				 rrd_freemem(calcpr[i]);
			}
			rrd_freemem(calcpr);
		}
		EXTEND(sp,4);
		PUSHs(sv_2mortal(newRV_noinc((SV*)retar)));
		PUSHs(sv_2mortal(newSViv(xsize)));
		PUSHs(sv_2mortal(newSViv(ysize)));

SV *
rrd_fetch(...)
	PROTOTYPE: @	
	PREINIT:
		time_t        start,end;		
		unsigned long step, ds_cnt,i,ii;
		rrd_value_t   *data,*datai;
		char **argv;
		char **ds_namv;
		AV *retar,*line,*names;
	PPCODE:
		argv = (char **) malloc((items+1)*sizeof(char *));
		argv[0] = "dummy";
		for (i = 0; i < items; i++) { 
		    STRLEN len;
		    char *handle= SvPV(ST(i),len);
		    /* actually copy the data to make sure possible modifications
		       on the argv data does not backfire into perl */ 
		    argv[i+1] = (char *) malloc((strlen(handle)+1)*sizeof(char));
		    strcpy(argv[i+1],handle);
 	        }
		rrd_clear_error();
		rrd_fetch(items+1,argv,&start,&end,&step,&ds_cnt,&ds_namv,&data); 
		for (i=0; i < items; i++) {
		    free(argv[i+1]);
		}
		free(argv);
		if (rrd_test_error()) XSRETURN_UNDEF;
                /* convert the ds_namv into perl format */
		names=newAV();
		for (ii = 0; ii < ds_cnt; ii++){
		    av_push(names,newSVpv(ds_namv[ii],0));
		    rrd_freemem(ds_namv[ii]);
		}
		rrd_freemem(ds_namv);			
		/* convert the data array into perl format */
		datai=data;
		retar=newAV();
		for (i = start+step; i <= end; i += step){
			line = newAV();
			for (ii = 0; ii < ds_cnt; ii++){
 			  av_push(line,(isnan(*datai) ? newSV(0) : newSVnv(*datai)));
			  datai++;
			}
			av_push(retar,newRV_noinc((SV*)line));
		}
		rrd_freemem(data);
		EXTEND(sp,5);
		PUSHs(sv_2mortal(newSViv(start+step)));
		PUSHs(sv_2mortal(newSViv(step)));
		PUSHs(sv_2mortal(newRV_noinc((SV*)names)));
		PUSHs(sv_2mortal(newRV_noinc((SV*)retar)));

SV *
rrd_times(start, end)
	  char *start
	  char *end
	PREINIT:
		rrd_time_value_t start_tv, end_tv;
		char    *parsetime_error = NULL;
		time_t	start_tmp, end_tmp;
	PPCODE:
		rrd_clear_error();
		if ((parsetime_error = rrd_parsetime(start, &start_tv))) {
			rrd_set_error("start time: %s", parsetime_error);
			XSRETURN_UNDEF;
		}
		if ((parsetime_error = rrd_parsetime(end, &end_tv))) {
			rrd_set_error("end time: %s", parsetime_error);
			XSRETURN_UNDEF;
		}
		if (rrd_proc_start_end(&start_tv, &end_tv, &start_tmp, &end_tmp) == -1) {
			XSRETURN_UNDEF;
		}
		EXTEND(sp,2);
		PUSHs(sv_2mortal(newSVuv(start_tmp)));
		PUSHs(sv_2mortal(newSVuv(end_tmp)));

int
rrd_xport(...)
	PROTOTYPE: @	
	PREINIT:
                time_t start,end;		
                int xsize;
		unsigned long step, col_cnt,row_cnt,i,ii;
		rrd_value_t *data,*ptr;
                char **argv,**legend_v;
		AV *retar,*line,*names;
	PPCODE:
		argv = (char **) malloc((items+1)*sizeof(char *));
		argv[0] = "dummy";
		for (i = 0; i < items; i++) { 
		    STRLEN len;
		    char *handle = SvPV(ST(i),len);
		    /* actually copy the data to make sure possible modifications
		       on the argv data does not backfire into perl */ 
		    argv[i+1] = (char *) malloc((strlen(handle)+1)*sizeof(char));
		    strcpy(argv[i+1],handle);
 	        }
		rrd_clear_error();
		rrd_xport(items+1,argv,&xsize,&start,&end,&step,&col_cnt,&legend_v,&data); 
		for (i=0; i < items; i++) {
		    free(argv[i+1]);
		}
		free(argv);
		if (rrd_test_error()) XSRETURN_UNDEF;

                /* convert the legend_v into perl format */
		names=newAV();
		for (ii = 0; ii < col_cnt; ii++){
		    av_push(names,newSVpv(legend_v[ii],0));
		    rrd_freemem(legend_v[ii]);
		}
		rrd_freemem(legend_v);			

		/* convert the data array into perl format */
		ptr=data;
		retar=newAV();
		for (i = start+step; i <= end; i += step){
			line = newAV();
			for (ii = 0; ii < col_cnt; ii++){
 			  av_push(line,(isnan(*ptr) ? newSV(0) : newSVnv(*ptr)));
			  ptr++;
			}
			av_push(retar,newRV_noinc((SV*)line));
		}
		rrd_freemem(data);

		EXTEND(sp,7);
		PUSHs(sv_2mortal(newSViv(start+step)));
		PUSHs(sv_2mortal(newSViv(end)));
		PUSHs(sv_2mortal(newSViv(step)));
		PUSHs(sv_2mortal(newSViv(col_cnt)));
		PUSHs(sv_2mortal(newRV_noinc((SV*)names)));
		PUSHs(sv_2mortal(newRV_noinc((SV*)retar)));

SV*
rrd_info(...)
	PROTOTYPE: @	
	PREINIT:
		rrd_info_t *data,*save;
                int i;
                char **argv;
		HV *hash;
	CODE:
		rrdinfocode(rrd_info);	
    OUTPUT:
	   RETVAL

SV*
rrd_updatev(...)
	PROTOTYPE: @	
	PREINIT:
		rrd_info_t *data,*save;
                int i;
                char **argv;
		HV *hash;
	CODE:
		rrdinfocode(rrd_update_v);	
    OUTPUT:
	   RETVAL

SV*
rrd_graphv(...)
	PROTOTYPE: @	
	PREINIT:
		rrd_info_t *data,*save;
                int i;
                char **argv;
		HV *hash;
	CODE:
		rrdinfocode(rrd_graph_v);	
    OUTPUT:
	   RETVAL

int
rrd_dump(...)
       PROTOTYPE: @
       PREINIT:
        int i;
       char **argv;
       CODE:
               rrdcode(rrd_dump);
                       RETVAL = 1;
       OUTPUT:
               RETVAL

int
rrd_restore(...)
       PROTOTYPE: @
       PREINIT:
        int i;
       char **argv;
       CODE:
               rrdcode(rrd_restore);
                       RETVAL = 1;
       OUTPUT:
               RETVAL

#ifndef WIN32
int
rrd_flushcached(...)
	PROTOTYPE: @
	PREINIT:
	int i;
	char **argv;
	CODE:
		rrdcode(rrd_flushcached);
	OUTPUT:
		RETVAL

#endif
