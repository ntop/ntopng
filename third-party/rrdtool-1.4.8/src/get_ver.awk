# ****************************************************************************
# RRDtool 1.2.19  Copyright by Tobi Oetiker, 1997-2007
# ****************************************************************************
# get_ver.awk   AWK Script for non-configure builds
# ****************************************************************************
# $Id: get_ver.awk 1000 2007-14-02 05:51:34Z oetiker $
# ****************************************************************************
BEGIN {
  # fetch rrdtool version number from input file and write them to STDOUT
  while ((getline < ARGV[1]) > 0) {
    if (match ($0, /^AC_INIT/)) {
      split($1, t, ",");
      my_ver_str = substr(t[2],2,length(t[2])-3);
      split(my_ver_str, v, ".");
      gsub("[^0-9].*$", "", v[3]);
      my_ver = v[1] "," v[2] "," v[3];
    }
    if (match ($0, /^NUMVERS=/)) {
      split($1, t, "=");
      my_ver_num = t[2];
    }
  }
  # read from from input file, replace placeholders, and write to STDOUT
  if (ARGV[2]) {
    while ((getline < ARGV[2]) > 0) {
      if (match ($0, /@@NUMVERS@@/)) {
        gsub("@@NUMVERS@@", my_ver_num, $0);
      }
      if (match ($0, /@@PACKAGE_VERSION@@/)) {
        gsub("@@PACKAGE_VERSION@@", "" my_ver_str "", $0);
      }
      print;
    }
  } else {
    print "RRD_VERSION = " my_ver "";
    print "RRD_VERSION_STR = " my_ver_str "";
    print "RRD_NUMVERS = " my_ver_num "";
  }
}

