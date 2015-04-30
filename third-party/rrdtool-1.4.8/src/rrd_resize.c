/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *****************************************************************************
 * rrd_resize.c Alters size of an RRA
 *****************************************************************************
 * Initial version by Alex van den Bogaerdt
 *****************************************************************************/

#include <stdlib.h>

#include "rrd_tool.h"

int rrd_resize(
    int argc,
    char **argv)
{
    char     *infilename, outfilename[11] = "resize.rrd";
    rrd_t     rrdold, rrdnew;
    rrd_value_t buffer;
    int       version;
    unsigned long l, rra;
    long      modify;
    unsigned long target_rra;
    int       shrink = 0;
    char     *endptr;
    rrd_file_t *rrd_file, *rrd_out_file;

    infilename = argv[1];
    if (!strcmp(infilename, "resize.rrd")) {
        rrd_set_error("resize.rrd is a reserved name");
        return (-1);
    }
    if (argc != 5) {
        rrd_set_error("wrong number of parameters");
        return (-1);
    }

    target_rra = strtol(argv[2], &endptr, 0);

    if (!strcmp(argv[3], "GROW"))
        shrink = 0;
    else if (!strcmp(argv[3], "SHRINK"))
        shrink = 1;
    else {
        rrd_set_error("I can only GROW or SHRINK");
        return (-1);
    }

    modify = strtol(argv[4], &endptr, 0);

    if ((modify < 1)) {
        rrd_set_error("Please grow or shrink with at least 1 row");
        return (-1);
    }

    if (shrink)
        modify = -modify;


    rrd_init(&rrdold);
    rrd_file = rrd_open(infilename, &rrdold, RRD_READWRITE | RRD_COPY);
    if (rrd_file == NULL) {
        rrd_free(&rrdold);
        return (-1);
    }

    if (rrd_lock(rrd_file) != 0) {
        rrd_set_error("could not lock original RRD");
        rrd_free(&rrdold);
        rrd_close(rrd_file);
        return (-1);
    }


    if (target_rra >= rrdold.stat_head->rra_cnt) {
        rrd_set_error("no such RRA in this RRD");
        rrd_free(&rrdold);
        rrd_close(rrd_file);
        return (-1);
    }

    if (modify < 0)
        if ((long) rrdold.rra_def[target_rra].row_cnt <= -modify) {
            rrd_set_error("This RRA is not that big");
            rrd_free(&rrdold);
            rrd_close(rrd_file);
            return (-1);
        }

    rrd_init(&rrdnew);
    /* These need to be initialised before calling rrd_open() with 
       the RRD_CREATE flag */

    if ((rrdnew.stat_head = (stat_head_t*)calloc(1, sizeof(stat_head_t))) == NULL) {
        rrd_set_error("allocating stat_head for new RRD");
        rrd_free(&rrdold);
        rrd_close(rrd_file);
        return (-1);
    }
    memcpy(rrdnew.stat_head,rrdold.stat_head,sizeof(stat_head_t));

    if ((rrdnew.rra_def = (rra_def_t *)malloc(sizeof(rra_def_t) * rrdold.stat_head->rra_cnt)) == NULL) {
        rrd_set_error("allocating rra_def for new RRD");
        rrd_free(&rrdnew);
        rrd_free(&rrdold);
        rrd_close(rrd_file);
        return (-1);
    }
    memcpy(rrdnew.rra_def,rrdold.rra_def,sizeof(rra_def_t) * rrdold.stat_head->rra_cnt);

    /* Set this so that the file will be created with the correct size */
    rrdnew.rra_def[target_rra].row_cnt += modify;

    rrd_out_file = rrd_open(outfilename, &rrdnew, RRD_READWRITE | RRD_CREAT);
    if (rrd_out_file == NULL) {
        rrd_set_error("Can't create '%s': %s", outfilename,
                      rrd_strerror(errno));
        rrd_free(&rrdnew);
        rrd_free(&rrdold);
        rrd_close(rrd_file);
        return (-1);
    }
    if (rrd_lock(rrd_out_file) != 0) {
        rrd_set_error("could not lock new RRD");
        rrd_free(&rrdnew);
        rrd_free(&rrdold);
        rrd_close(rrd_file);
        rrd_close(rrd_out_file);
        return (-1);
    }
/*XXX: do one write for those parts of header that are unchanged */
    if ((rrdnew.rra_ptr = (rra_ptr_t *)malloc(sizeof(rra_ptr_t) * rrdold.stat_head->rra_cnt)) == NULL) {
        rrd_set_error("allocating rra_ptr for new RRD");
        rrd_free(&rrdnew);
        rrd_free(&rrdold);
        rrd_close(rrd_file);
        rrd_close(rrd_out_file);
        return (-1);
    }

    /* Put this back the way it was so that the rest of the algorithm
       below remains unchanged, it will be corrected later */
    rrdnew.rra_def[target_rra].row_cnt -= modify;

    rrdnew.ds_def = rrdold.ds_def;
    rrdnew.live_head = rrdold.live_head;
    rrdnew.pdp_prep = rrdold.pdp_prep;
    rrdnew.cdp_prep = rrdold.cdp_prep;
    memcpy(rrdnew.rra_ptr,rrdold.rra_ptr,sizeof(rra_ptr_t) * rrdold.stat_head->rra_cnt);


    version = atoi(rrdold.stat_head->version);
    switch (version) {
    case 4:
        break;        
    case 3:
        break;
    case 1:
        rrdnew.stat_head->version[3] = '3';
        break;
    default:
        rrd_set_error("Do not know how to handle RRD version %s",
                      rrdold.stat_head->version);

        rrdnew.ds_def = NULL;
        rrdnew.live_head = NULL;
        rrdnew.pdp_prep = NULL;
        rrdnew.cdp_prep = NULL;

        rrd_free(&rrdnew);
        rrd_free(&rrdold);
        rrd_close(rrd_file);
        rrd_close(rrd_out_file);
        return (-1);
        break;
    }

/* XXX: Error checking? */
    rrd_write(rrd_out_file, rrdnew.stat_head, sizeof(stat_head_t) * 1);
    rrd_write(rrd_out_file, rrdnew.ds_def,
              sizeof(ds_def_t) * rrdnew.stat_head->ds_cnt);
    rrd_write(rrd_out_file, rrdnew.rra_def,
              sizeof(rra_def_t) * rrdnew.stat_head->rra_cnt);
    rrd_write(rrd_out_file, rrdnew.live_head, sizeof(live_head_t) * 1);
    rrd_write(rrd_out_file, rrdnew.pdp_prep,
              sizeof(pdp_prep_t) * rrdnew.stat_head->ds_cnt);
    rrd_write(rrd_out_file, rrdnew.cdp_prep,
              sizeof(cdp_prep_t) * rrdnew.stat_head->ds_cnt *
              rrdnew.stat_head->rra_cnt);
    rrd_write(rrd_out_file, rrdnew.rra_ptr,
              sizeof(rra_ptr_t) * rrdnew.stat_head->rra_cnt);

    /* Move the CDPs from the old to the new database.
     ** This can be made (much) faster but isn't worth the effort. Clarity
     ** is much more important.
     */

    /* Move data in unmodified RRAs
     */
    l = 0;
    for (rra = 0; rra < target_rra; rra++) {
        l += rrdnew.stat_head->ds_cnt * rrdnew.rra_def[rra].row_cnt;
    }
    while (l > 0) {
        rrd_read(rrd_file, &buffer, sizeof(rrd_value_t) * 1);
        rrd_write(rrd_out_file, &buffer, sizeof(rrd_value_t) * 1);
        l--;
    }
    /* Move data in this RRA, either removing or adding some rows
     */
    if (modify > 0) {
        /* Adding extra rows; insert unknown values just after the
         ** current row number.
         */
        l = rrdnew.stat_head->ds_cnt *
            (rrdnew.rra_ptr[target_rra].cur_row + 1);
        while (l > 0) {
            rrd_read(rrd_file, &buffer, sizeof(rrd_value_t) * 1);
            rrd_write(rrd_out_file, &buffer, sizeof(rrd_value_t) * 1);
            l--;
        }
        buffer = DNAN;
        l = rrdnew.stat_head->ds_cnt * modify;
        while (l > 0) {
            rrd_write(rrd_out_file, &buffer, sizeof(rrd_value_t) * 1);
            l--;
        }
    } else {
        /* Removing rows. Normally this would be just after the cursor
         ** however this may also mean that we wrap to the beginning of
         ** the array.
         */
        signed long int remove_end = 0;

        remove_end =
            (rrdnew.rra_ptr[target_rra].cur_row -
             modify) % rrdnew.rra_def[target_rra].row_cnt;
        if (remove_end <=
            (signed long int) rrdnew.rra_ptr[target_rra].cur_row) {
            while (remove_end >= 0) {
                rrd_seek(rrd_file,
                         sizeof(rrd_value_t) * rrdnew.stat_head->ds_cnt,
                         SEEK_CUR);
                rrdnew.rra_ptr[target_rra].cur_row--;
                rrdnew.rra_def[target_rra].row_cnt--;
                remove_end--;
                modify++;
            }
            remove_end = rrdnew.rra_def[target_rra].row_cnt - 1;
        }
        for (l = 0; l <= rrdnew.rra_ptr[target_rra].cur_row; l++) {
            unsigned int tmp;

            for (tmp = 0; tmp < rrdnew.stat_head->ds_cnt; tmp++) {
                rrd_read(rrd_file, &buffer, sizeof(rrd_value_t) * 1);
                rrd_write(rrd_out_file, &buffer, sizeof(rrd_value_t) * 1);
            }
        }
        while (modify < 0) {
            rrd_seek(rrd_file,
                     sizeof(rrd_value_t) * rrdnew.stat_head->ds_cnt,
                     SEEK_CUR);
            rrdnew.rra_def[target_rra].row_cnt--;
            modify++;
        }
    }
    /* Move the rest of the CDPs
     */
    while (1) {
        ssize_t b_read;
        if ((b_read=rrd_read(rrd_file, &buffer, sizeof(rrd_value_t) * 1)) <= 0)
            break;
        if(rrd_out_file->pos+b_read > rrd_out_file->file_len) {
            fprintf(stderr,"WARNING: ignoring last %zu bytes\nWARNING: if you see this message multiple times for a single file you're in trouble\n", b_read);
            continue;
        }
        rrd_write(rrd_out_file, &buffer, b_read);
    }
    rrdnew.rra_def[target_rra].row_cnt += modify;
    rrd_seek(rrd_out_file,
             sizeof(stat_head_t) +
             sizeof(ds_def_t) * rrdnew.stat_head->ds_cnt, SEEK_SET);
    rrd_write(rrd_out_file, rrdnew.rra_def,
              sizeof(rra_def_t) * rrdnew.stat_head->rra_cnt);
    rrd_seek(rrd_out_file, sizeof(live_head_t), SEEK_CUR);
    rrd_seek(rrd_out_file, sizeof(pdp_prep_t) * rrdnew.stat_head->ds_cnt,
             SEEK_CUR);
    rrd_seek(rrd_out_file,
             sizeof(cdp_prep_t) * rrdnew.stat_head->ds_cnt *
             rrdnew.stat_head->rra_cnt, SEEK_CUR);
    rrd_write(rrd_out_file, rrdnew.rra_ptr,
              sizeof(rra_ptr_t) * rrdnew.stat_head->rra_cnt);
    rrd_close(rrd_file);    
    rrd_close(rrd_out_file);    
    rrd_free(&rrdold);

    rrdnew.ds_def = NULL;
    rrdnew.live_head = NULL;
    rrdnew.pdp_prep = NULL;
    rrdnew.cdp_prep = NULL;

    rrd_free(&rrdnew);
    return (0);
}
