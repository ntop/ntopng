#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# A script to map nProbe fields to the ParserInterface.cpp and to the flow_utils.lua
#

import sys
import os
import re

def usage():
  print("""Usage: %s nprobe_help_filtered_file [indentation_level] [--c-output]

  Example invocations:
    - For ParserInterface.cpp:
      nprobe -h | python3 ./nprobe_mapping.py - 4

    - flow_utils.lua:
      nprobe -h | python3 ./nprobe_mapping.py - 2 --c-output""" % (os.path.basename(sys.argv[0])))
  exit(1)

if len(sys.argv) < 2:
  usage()

if len(sys.argv) >= 3:
  indentation = " " * int(sys.argv[2])
else:
  indentation = "    "

if len(sys.argv) >= 4 and sys.argv[3] == "--c-output":
  c_output = True
else:
  c_output = False

# ------------------------------------------------------------------------------

if sys.argv[1] == "-":
  fin = sys.stdin
else:
  fin = open(sys.argv[1])

start_ok = False

localized = []

for line in fin:
  lstripped = line.strip()

  if lstripped == "-------------------------------------------------------------------------------":
    # Start parsing output
    start_ok = True
  elif start_ok:
    if lstripped.startswith("Major protocol (%L7_PROTO) symbolic mapping"):
      break

    pattern = re.search('^([^:]+):$', lstripped)
    if pattern:
      # This is a section delimiter
      label = pattern.groups()[0]
      label = label.lstrip("Plugin ").rstrip("templates").strip()
      if not c_output:
        print("")
        print(indentation + "-- " + label)
    else:
      # This is a line into a section
      pattern = re.search('^\[([^\]]+)\](\[([^\]]+)\]){0,1}\s+%(\w+)\s+(%(\w+)\s+){0,1}(.*)$', lstripped)
      if pattern:
        (netflow_id, _, ipfix_id, netflow_label, _, ipfix_label, description) = pattern.groups()
        parts = netflow_id.split(" ")
        idx = parts[len(parts) - 1]

        if not c_output:
          loc_key = netflow_label.lower()
          localized.append((loc_key, description))
          print('%s["%s"] = i18n("flow_fields_description.%s"),' % (indentation, netflow_label, loc_key))
        else:
          print('%saddMapping("%s", %s);' % (indentation, netflow_label, idx))

fin.close()

if not c_output:
  # Print localized mappings
  indentation = "   "
  indentation_double = indentation * 2

  print("\n------------------------ CUT HERE ------------------------\n")

  print(indentation + "flow_fields_description = {")

  for (idx, description) in localized:
    print('%s%s = "%s",' % (indentation_double, idx, description.replace("%", "%%")))

  print(indentation + "},")
