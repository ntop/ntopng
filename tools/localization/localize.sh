#!/bin/bash

LUA_INTERPR="`which lua5.3`"

function usage {
  echo -e "Usage: `basename $0` action parameters"
  echo
  echo -e "Actions:"
  echo -e " sort [lang]: sorts the specified localization file after modification"
  echo -e " status [lang]: verifies the localization status of lang"
  echo -e " missing [lang]: get a report of missing strings to localize for the lang"
  echo -e " all [lang]: get a report of all the localized strings for lang"
  echo -e " extend [lang] [extension_txt]: extends the localization with a localized report"
  echo
  echo -e "A report is in the format:"
  echo -e " lang.manage_users.manage = \"Verwalten\""
  echo -e " lang.manage_users.manage_user_x = \"Verwalte User %{user}\""
  echo -e " ..."
  exit 1
}

# pro root
base_path="../tools/localization"
root_path=".."
LUA="lua5.3"

if [[ -d src ]]; then
  # ntopng root
  base_path="tools/localization"
  root_path="."
elif [[ ! -d tools ]]; then
  # inside localization folder
  base_path="."
  root_path="../../.."
fi

if [[ $# -lt 1 ]]; then
  usage
fi

lang_path=
function get_lang_path {
  if [[ -f "$root_path/pro/scripts/locales/${1}.lua" ]]; then
    lang_path="$root_path/pro/scripts/locales/${1}.lua"
  else
    lang_path="$root_path/scripts/locales/${1}.lua"
  fi
}

case $1 in
sort)
  lang=$2
  if [[ -z $lang ]]; then usage; fi

  ${LUA_INTERPR} "$base_path/sort_localization_file.lua" "$lang"
  ;;
status)
  lang=$2
  if [[ -z $lang ]]; then usage; fi
  get_lang_path "$lang"

  "$base_path/missing_localization.py" cmp "$root_path/scripts/locales/en.lua" "$lang_path" | grep -v ".nedge."
  ;;
missing)
  lang=$2
  if [[ -z $lang ]]; then usage; fi
  get_lang_path "$lang"

  ${LUA_INTERPR} "$base_path/sort_localization_file.lua" "en"
  ${LUA_INTERPR} "$base_path/sort_localization_file.lua" "$lang"
  missing_lines=`"$base_path/missing_localization.py" missing "$root_path/scripts/locales/en.lua" "$lang_path"`
  if [[ ! -z $missing_lines ]]; then
    echo "*** REMOVE THE FOLLOWING LINES FROM ${lang}.lua BEFORE PROCEEDING ****" >&2
    echo -e "$missing_lines" >&2
  else
    "$base_path/missing_localization.py" cmp "$root_path/scripts/locales/en.lua" "$lang_path" | grep -v ".nedge." | awk '{ $1=""; $2 = ""; print $0; }'
  fi
  ;;
all)
  lang=$2
  if [[ -z $lang ]]; then usage; fi
  get_lang_path "$lang"

  "$base_path/missing_localization.py" cmp /dev/null "$lang_path" | grep -v ".nedge." | awk '{ $1=""; $2 = ""; print $0; }'
  ;;
extend)
  lang=$2
  extension_file=$3
  if [[ -z $lang ]]; then usage; fi
  if [[ -z $extension_file ]]; then usage; fi

  ${LUA_INTERPR} "$base_path/sort_localization_file.lua" "$lang" "$extension_file"
  ;;
*)  usage
esac
