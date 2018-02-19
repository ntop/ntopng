#!/usr/bin/env python3

#
# missing_localization.py                                     Emanuele Faranda
# A tool to find missing localization strings
#
# Sample invocation:
#   tools/localitzation/missing_localization.py scripts/locales/en.lua pro/scripts/locales/de.lua | grep -v ".nedge." | awk '{ $2 = ""; print $0; }'

import sys
import difflib

def extract_table_key(x):
  if x.startswith('["') and x.endswith('"]'):
    return x[2:-2]
  return x

class LocalizationFile(object):
  def __init__(self, name):
    self.f = open(name, "r", encoding='UTF-8')
    self.next_skip = False
    self.cur_section = []
    self.line_no = 0

  def __iter__(self):
    return self

  # Iterates on localization ids
  def __next__(self):
    while True:
      line = next(self.f).strip()
      self.line_no += 1
      is_section_start = line.endswith("{") and line.find(" = ") != None
      is_section_end = line.startswith("}")

      if is_section_start:
        self.cur_section.append(extract_table_key(line.split(" = ", 1)[0].split()[-1]))
      elif is_section_end:
        self.cur_section.pop()
      elif not line.startswith("--") and self.cur_section:
        if not self.next_skip:
          value = line.split("=", 1)

          if len(value) == 2:
            localized_id, localized_str = value
            localized_id = extract_table_key(localized_id.strip())
            localized_str = localized_str.strip().strip(",").strip('"')

            if localized_str.endswith(".."):
              # String continues on next line
              self.next_skip = True

            return ".".join(self.cur_section) + "." + localized_id, self.line_no, localized_str
        else:
          self.next_skip = line.endswith("..")

# Wrapper to provide len and indexing on the LocalizationFile
class LocalizationReaderWrapper(object):
  def __init__(self, localization_file_obj):
    self.localiz_obj = localization_file_obj
    self.lines = []
    self.line_id_to_line = {}
    self.populateLines()

  def __len__(self):
    return len(self.lines)

  def __getitem__(self, idx):
      return self.lines[idx]

  def __iter__(self):
    return self.lines.__iter__()

  def populateLines(self):
    for line in self.localiz_obj:
      self.lines.append(line[0])
      self.line_id_to_line[line[0]] = line

  def getLineInfo(self, line_id):
    return self.line_id_to_line[line_id]

if __name__ == "__main__":
  def usage():
    print("Usage: " + sys.argv[0] + " base_file cmp_file")
    exit(1)

  if len(sys.argv) != 3:
    usage()

  base_file = LocalizationReaderWrapper(LocalizationFile(sys.argv[1]))
  cmp_file = LocalizationReaderWrapper(LocalizationFile(sys.argv[2]))
  difftool = difflib.Differ()
  diff = difftool.compare(base_file, cmp_file)

  for line in diff:
    if not line.startswith(" "):
      if line.startswith("-"):
        wrapper = base_file
      elif line.startswith("+"):
        wrapper = cmp_file
      else:
        print(line)
        continue

      line_info = wrapper.getLineInfo(line.split()[-1])

      print("%d) %s = \"%s\"" % (
        line_info[1],
        line,
        line_info[2],
      ))
