#!/bin/bash

function usage {
  echo -e "Usage: `basename $0` action parameters"
  echo
  echo -e "Actions:"
  echo -e " sort [lang]: sorts the specified localization file after modification"
  echo -e " status [lang]: verifies the localization status of lang"
  echo -e " missing [lang]: get a report of missing strings to localize for the lang"
  echo -e " extend [lang] [extension_txt]: extends the localization with a localized report"
  echo
  echo -e "A report is in the format:"
  echo -e " lang.manage_users.manage = \"Verwalten\""
  echo -e " lang.manage_users.manage_user_x = \"Verwalte User %{user}\""
  echo -e " ..."
  exit 1
}

base_path="tools/localization"
root_path="."
if [[ ! -d tools ]]; then
  base_path="."
  root_path="../.."
fi

if [[ $# -lt 1 ]]; then
  usage
fi

case $1 in
sort)
  lang=$2
  if [[ -z $lang ]]; then usage; fi

  lua "$base_path/sort_localization_file.lua" "$lang"
  ;;
status)
  lang=$2
  if [[ -z $lang ]]; then usage; fi

  "$base_path/missing_localization.py" "$root_path/scripts/locales/en.lua" "$root_path/pro/scripts/locales/${lang}.lua" | grep -v ".nedge."
  ;;
missing)
  lang=$2
  if [[ -z $lang ]]; then usage; fi

  "$base_path/missing_localization.py" "$root_path/scripts/locales/en.lua" "$root_path/pro/scripts/locales/${lang}.lua" | grep -v ".nedge." | awk '{ $1=""; $2 = ""; print $0; }'
  ;;
extend)
  lang=$2
  extension_file=$3
  if [[ -z $lang ]]; then usage; fi
  if [[ -z $extension_file ]]; then usage; fi

  lua "$base_path/sort_localization_file.lua" "$lang" "$extension_file"
  ;;
*)  usage
esac
