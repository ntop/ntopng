#!/usr/bin/env python3
#
# (C) 2019-26 - ntop.org
#
# fix_js_i18n.py
#
# PURPOSE
#   Localized strings routinely contain apostrophes ("l'hote"), double quotes or
#   line breaks. When ntopng prints i18n() output *inside a JavaScript string
#   literal* in an inline <script>, such a character terminates the JS string
#   early and throws  SyntaxError: Unexpected identifier / missing ) ...  which
#   aborts the whole <script> block (later functions never get defined).
#
#   The fix is to wrap the value with  js_str()  (defined in
#   scripts/lua/modules/lua_utils_generic.lua), which escapes  \ ' " CR LF .
#
#   This script scans scripts/lua/** for i18n() output that lands inside a JS
#   string literal and is NOT already wrapped, reports each occurrence, and with
#   --fix rewrites the high-confidence ones in place.
#
# USAGE
#   tools/localization/fix_js_i18n.py            # report only
#   tools/localization/fix_js_i18n.py --fix      # rewrite in place
#   tools/localization/fix_js_i18n.py --fix path/to/one.lua
#
# It is deliberately CONSERVATIVE: it only rewrites patterns where the i18n()
# call is provably between two JS string quotes on the same line. Anything it is
# unsure about is reported for a human, never auto-changed.
#
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     "../.."))
SCAN_DIR = os.path.join(ROOT, "scripts", "lua")

# An i18n(...) call: name, optional {table} arg, optional  or "fallback"
I18N = r'i18n\(\s*"(?:[^"\\]|\\.)*"\s*(?:,\s*\{[^{}]*\})?\s*\)(?:\s+or\s+"(?:[^"\\]|\\.)*")?'

# --- high confidence: auto-fixable ------------------------------------------
#
# The ONE provably-safe pattern:  the Lua template breaks out of a JS string
# literal, prints an i18n value, and resumes the SAME quote:
#
#     someJsCall('  ]] print(i18n("k")) print[[  ');
#     placeholder: "]] print(i18n("k")) print[[",
#
# Here the surrounding ' or " is unambiguously a JS string delimiter, so
# js_str() is exactly right. Only applied in files that contain "<script".
AUTOFIX_PRINT = re.compile(
    r"(?P<q>['\"])\]\]\s*print\(\s*(?P<expr>" + I18N + r")\s*\)\s*print\[\[(?P=q)")

# --- lower confidence: report only, never auto-change ----------------------
# String CONCAT into a JS call, e.g.  alert.warning('...' .. i18n("k") .. '...')
# We can't safely auto-fix: the same syntax is used to build HTML / alert text
# where js_str() would wrongly escape apostrophes. Flag for a human.
REPORT_HINTS = (
    re.compile(r"\.(?:warning|error|success|info)\(\s*['\"][^\"']*['\"]\s*\.\.\s*i18n\("),
    re.compile(r"i18n\([^)]*\)\s*\.\.\s*['\"][^\"']*['\"]\s*\)\s*;"),
    re.compile(r"(?:placeholder|title|text|message)\s*:\s*['\"][^\"']*['\"]\s*\.\.\s*i18n\("),
    re.compile(r"\.(?:val|text|html)\(\s*['\"]?[^)]*i18n\([^)]*\)[^)]*['\"]?\s*\)\s*;"),
)


def already_wrapped(expr_ctx):
    return "js_str(" in expr_ctx


def process(path, do_fix):
    src = open(path, encoding="utf-8").read()
    rel = os.path.relpath(path, ROOT)
    has_script = "<script" in src
    lines = src.split("\n")
    fixes = 0
    reports = []

    new_lines = []
    for lineno, line in enumerate(lines, 1):
        orig = line

        if "i18n(" in line and "js_str(" not in line:
            def wrap_print(m):
                return f"{m.group('q')}]] print(js_str({m.group('expr')})) print[[{m.group('q')}"

            line2 = AUTOFIX_PRINT.sub(wrap_print, line) if has_script else line

            if line2 != orig:
                fixes += line2.count("js_str(") - orig.count("js_str(")
                if do_fix:
                    line = line2
                reports.append((lineno, "FIX ", orig.strip()[:110]))
            else:
                for h in REPORT_HINTS:
                    if h.search(line):
                        reports.append((lineno, "CHECK", orig.strip()[:110]))
                        break

        new_lines.append(line)

    if do_fix and fixes:
        open(path, "w", encoding="utf-8").write("\n".join(new_lines))

    if reports:
        print(f"\n{rel}")
        for lineno, tag, text in reports:
            print(f"  {lineno:5d} {tag}  {text}")

    return fixes, sum(1 for r in reports if r[1] == "CHECK")


def iter_lua(targets):
    if targets:
        for t in targets:
            yield os.path.abspath(t)
        return
    for dirpath, _dirs, files in os.walk(SCAN_DIR):
        for f in files:
            if f.endswith(".lua"):
                yield os.path.join(dirpath, f)


def luac_ok(path):
    import shutil
    import subprocess
    luac = next((b for b in ("luac5.4", "luac5.3", "luac") if shutil.which(b)), None)
    if not luac:
        return True
    return subprocess.run([luac, "-p", path], capture_output=True).returncode == 0


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    do_fix = "--fix" in sys.argv

    total_fix = total_check = 0
    touched = []
    for path in iter_lua(args):
        before = open(path, "rb").read() if do_fix else None
        f, c = process(path, do_fix)
        total_fix += f
        total_check += c
        if do_fix and f and open(path, "rb").read() != before:
            if not luac_ok(path):
                open(path, "wb").write(before)
                sys.exit(f"\nABORT: fix broke Lua syntax in {path}, reverted.")
            touched.append(path)

    print("\n" + "=" * 60)
    if do_fix:
        print(f"applied {total_fix} js_str() wrap(s) in {len(touched)} file(s)")
        for p in touched:
            print(f"  {os.path.relpath(p, ROOT)}")
    else:
        print(f"{total_fix} auto-fixable, {total_check} need manual review "
              f"(run with --fix to apply the auto-fixable ones)")


if __name__ == "__main__":
    main()
