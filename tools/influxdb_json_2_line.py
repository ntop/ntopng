#!/usr/bin/env python3
# Emanuele Faranda
#
# Example on how to convert a json retuned by an InfluxDB http query into the line protocol.
# The line protocol can then be used to load the json back into influxdb, e.g.
#   curl -XPOST --data-binary @converted_influx.line -i "http://localhost:8086/write?db=ntopng"
#
# This is an effective way to move data from an InfluxDB instance to another
#

import sys
import json
from dateutil import parser, tz
import datetime
import time

def json2Line(j, tags):
  # strip preliminary info
  if "results" in j:
    j = j["results"][0]
  if "series" in j:
    j = j["series"]

  for serie in j:
    name = serie["name"]
    cols = serie["columns"]
    vals = serie["values"]

    tag_idx = [idx for idx,col in enumerate(cols) if col in tags]
    tag_cols = [col for col in cols if col in tags]
    metrics_cols = [col for col in cols if not col in tags]

    for v in vals:
      tags_vals = [val for idx,val in enumerate(v) if idx in tag_idx]
      metric_vals = [val for idx,val in enumerate(v) if not idx in tag_idx]
      tags = dict(zip(tag_cols, tags_vals))
      metrics = dict(zip(metrics_cols, metric_vals))

      time_str = tags.pop("time")
      tz_offset = -time.timezone
      time_val = int(time.mktime(parser.parse(time_str).timetuple())) + tz_offset
      timestamp = "%d000000000" % time_val

      # "iface:traffic,ifid=0 bytes=0 1539358699000000000\n"
      print("%s %s %s" % (
        ",".join([name,] + ["%s=%s" % (k,v) for k,v in tags.items()]),
        ",".join(["%s=%s" % (k,v) for k,v in metrics.items()]),
        timestamp))

if __name__ == "__main__":
  if len(sys.argv) != 2:
    print("Usage: influxdb_json_2_line.py file.json > file.line")
    exit(1)

  # TODO as parameter
  tags = {"time", "device", "if_index", "ifid"}

  with open(sys.argv[1], "r") as f:
    json2Line(json.load(f), tags)
