#!/bin/bash
#
# A script to scan lua files for global variables.
# Global variables should be avoided as they are a potentially source of issues
# and reduce the overall performance.
#
# You can provide an argument to this script to only validate the specified lua
# script. NOTE: The argument is a path relative to this script.
#

STOP_ON_FIRST_FILE_WITH_ERRORS=1

# Go into the scripts dir
if [[ -d "tools" ]]; then
  cd tools
fi

if [[ ! -f globals.lua ]]; then
  echo "Cannot find globals.lua script" >&2
  exit 1
fi

luac_cmd=
luac_ver=

function check_ver {
  luac_cmd="`which $1`"

  if [[ $? -eq 0 ]]; then
    luac_ver="`$luac_cmd -v 2>&1 | cut -f2 -d' '`"

    if [[ "${luac_ver#5.2}" == "$luac_ver" ]]; then
      # Bad version
      luac_ver=
    fi
  else
    luac_ver=
  fi
}

# Locate the lua executable
check_ver "luac"
if [[ "$luac_ver" == "" ]]; then check_ver "luac5.2"; fi
if [[ "$luac_ver" == "" ]]; then check_ver "luac5"; fi

if [[ "$luac_ver" == "" ]]; then
  echo "Required luac version 5.2 not found" >&2
  exit 1
fi

lua_cmd="`which lua`"

if [[ $? -ne 0 ]]; then
  echo "Cannot find LUA interpreter" >&2
  exit 1
fi

if [[ ! -z "$1" ]]; then
  files="$1"
else
  files=`find -L ../scripts -name "*.lua"`
fi

# Locate lua sources, following symbolic links
for f in $files; do
  has_errors=0

  while read line; do
    # a little formatting here
    lineno=`echo $line | cut -f1 -d" "`
    field=`echo $line | cut -f2 -d" "`
    sym="${line##* }"

    if [[ $field == "GETTABUP" ]]; then
      echo -e "\tline${lineno} GETGLOBAL ${sym}"
    elif [[ $field == "SETTABUP" ]]; then
      echo -e "\tline${lineno} SETGLOBAL ${sym}"
    else
      # exclude first line
      if [[ $has_errors -ne 0 ]]; then echo; fi
      echo $line
    fi

    has_errors=1
  done < <($luac_cmd -l -p "$f" | $lua_cmd globals.lua "$f")

  # todo exit on error, the below does not work
  # if [[ $? -ne 0 ]]; then exit 1; fi

  if [[ ( $has_errors -ne 0 ) && ( $STOP_ON_FIRST_FILE_WITH_ERRORS -eq 1 ) ]]; then
    exit 1
  fi
done

echo "No errors detected"
