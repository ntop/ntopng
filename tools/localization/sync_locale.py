#!/usr/bin/env python3
#
# (C) 2019-26 - ntop.org
#
# sync_locale.py
#
# PURPOSE
#   Bring one localization file in sync with scripts/locales/en.lua, the
#   reference. The output <lang>.lua is regenerated FROM en.lua so that it:
#     * has exactly the same keys, order and section structure as en.lua
#     * has NO stale keys (keys that no longer exist in en.lua are dropped)
#     * keeps every translation that already existed in <lang>.lua
#     * auto-translates (Google Translate) only the keys that were missing
#
#   Comments and blank lines are taken from en.lua.
#
# PREREQUISITES
#   uv pip install --python .venv deep-translator      (only needed without --dry-run)
#
# USAGE
#   # from the ntopng root:
#   ./tools/localization/sync_locale.py de --dry-run          # report only
#   ./tools/localization/sync_locale.py de                    # translate + write de.lua
#   ./tools/localization/sync_locale.py all                   # every language
#
#   Optional:  --en PATH   override reference file (default scripts/locales/en.lua)
#
# NOTES
#   * %{placeholder} tokens are protected across translation.
#   * Multi-line ("..".. continuation) values are rare; if the English side uses
#     one it is copied verbatim (never machine-translated).
#   * Machine translation is a starting point - human review is recommended,
#     especially for cn / jp / ko.
#
import argparse
import os
import re
import sys
import time

# ntopng file name -> Google Translate language code
LANGS = {
    "cn": "zh-CN",
    "cz": "cs",
    "de": "de",
    "es": "es",
    "fr": "fr",
    "it": "it",
    "jp": "ja",
    "ko": "ko",
    "pt": "pt",
}

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOCALES_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, "../../scripts/locales"))

# ["key"] = { ...        (section open)
RE_SECTION_OPEN = re.compile(r'^(\s*)\["([^"]+)"\]\s*=\s*\{\s*$')
# },  or  }               (section close)
RE_SECTION_CLOSE = re.compile(r'^\s*\},?\s*$')
# ["key"] = "value",      (leaf, single line)
RE_LEAF = re.compile(r'^(\s*)\["([^"]+)"\]\s*=\s*"((?:\\.|[^"\\])*)"\s*,\s*$')
# ["key"] = "value" ..    (leaf, multi-line start) -- copied verbatim
RE_LEAF_MULTILINE = re.compile(r'^\s*\["[^"]+"\]\s*=\s*".*\.\.\s*$')

# Things that must survive translation byte-for-byte:
#   %{name}   ntopng interpolation      %s %d %1$s   printf / Lua
#   %{name}%% trailing percent literals are handled by the token itself
TOKEN_RE = re.compile(r'%\{[^}]+\}|%\d+\$[sd]|%[sd]')

# Private Use Area sentinels: Google Translate passes them through untouched and
# never reorders or "translates" them (unlike digit-based markers such as @@0@@).
SENT_BASE = 0xE000


def _sentinel(i):
    return chr(SENT_BASE + i)


def protect(text):
    """Replace each interpolation token with a PUA sentinel.

    Returns (protected_text, tokens) where tokens[i] = (original, had_left_space,
    had_right_space) so restore() can rebuild the exact adjacency the English
    string had, ignoring any spaces Google Translate adds or drops.
    """
    tokens = []

    def repl(m):
        s, e = m.span()
        left = s > 0 and text[s - 1].isspace()
        right = e < len(text) and text[e].isspace()
        tokens.append((m.group(0), left, right))
        return f" {_sentinel(len(tokens) - 1)} "

    return TOKEN_RE.sub(repl, text), tokens


def restore(text, tokens):
    text = re.sub(r"[^\S\n]+", " ", text)
    for i, (tok, left, right) in enumerate(tokens):
        sent = _sentinel(i)
        repl = (" " if left else "") + tok + (" " if right else "")
        text = re.sub(r"\s*" + re.escape(sent) + r"\s*", lambda _m, r=repl: r, text)
    return re.sub(r"[^\S\n]+", " ", text).strip()



def _lua_escape(s):
    """Make `s` safe to sit between the double quotes of a Lua string literal.
    The input may already contain \\" from the source file; normalise first so
    we never emit \\\\" or an odd number of backslashes.
    """
    s = s.replace('\\"', '"')          # normalise any pre-existing escaping
    s = s.replace("\\", "\\\\")         # escape lone backslashes
    s = s.replace('"', '\\"')           # escape double quotes
    s = s.replace("\r", " ").replace("\n", " ")   # never break the line
    return s


def token_multiset(text):
    """Sorted list of interpolation tokens, for equality checks."""
    return sorted(TOKEN_RE.findall(text))


# Strings that are (or embed) JavaScript / heavy HTML must not be machine
# translated: GT corrupts identifiers, quotes and template literals.
_CODE_MARKERS = ("<script", "javascript:", "onclick=", "onchange=", "document.",
                 ".style.", "textArea", "=>", "function(", "addEventListener",
                 "`")


def looks_like_code(text):
    return any(m in text for m in _CODE_MARKERS)


def parse_translations(path):
    """Flat { 'a.b.c' : raw_value_string } from an existing locale file.

    raw_value_string is the exact text between the surrounding double quotes
    (still escaped, ready to drop back into `["k"] = "<value>",`).
    """
    out = {}
    if not os.path.isfile(path):
        return out

    stack = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            s = line.rstrip("\n")

            m = RE_SECTION_OPEN.match(s)
            if m:
                stack.append(m.group(2))
                continue

            if RE_SECTION_CLOSE.match(s):
                if stack:
                    stack.pop()
                continue

            m = RE_LEAF.match(s)
            if m:
                key = ".".join(stack + [m.group(2)])
                out[key] = m.group(3)
                continue
            # ignore: `local lang = {`, `return lang`, comments, multi-line, blanks

    return out


class Translator:
    def __init__(self, dst_code, dry_run):
        self.dry_run = dry_run
        self.n_translated = 0
        self.n_skipped_code = 0
        self.n_token_fail = 0
        self._t = None
        if not dry_run:
            try:
                from deep_translator import GoogleTranslator
            except ImportError:
                sys.exit("deep-translator not installed. "
                         "Run: uv pip install --python .venv deep-translator")
            self._t = GoogleTranslator(source="en", target=dst_code)

    def _gt(self, text):
        for attempt in range(4):
            try:
                return self._t.translate(text) or text
            except Exception as e:  # noqa: BLE001 network flakiness
                if attempt == 3:
                    sys.stderr.write(f"    NETWORK-FAIL: {e}\n")
                    return text
                time.sleep(2 ** attempt)

    def translate(self, value):
        """value: escaped string as stored between the quotes in the .lua file.
        Returns an escaped string. Falls back to the English value whenever the
        machine translation would corrupt an interpolation token or is code.
        """
        self.n_translated += 1
        if self.dry_run or value.strip() == "":
            return value

        raw = value.replace('\\"', '"')

        # never machine-translate embedded JS / heavy HTML
        if looks_like_code(raw):
            self.n_skipped_code += 1
            return value

        want = token_multiset(raw)
        protected, tokens = protect(raw)

        out = self._gt(protected)
        result = restore(out, tokens)

        # verify no interpolation token was dropped, added or mangled
        if token_multiset(result) != want:
            out = self._gt(protected)                 # one retry
            result = restore(out, tokens)
            if token_multiset(result) != want:
                self.n_token_fail += 1
                sys.stderr.write(
                    f"    TOKEN-MISMATCH, keeping English: {raw[:70]!r}\n")
                return value

        return _lua_escape(result)


def sync_one(lang_name, en_path, dry_run, revalidate):
    dst_code = LANGS[lang_name]
    lang_path = os.path.join(LOCALES_DIR, f"{lang_name}.lua")

    existing = parse_translations(lang_path)
    en_vals = parse_translations(en_path)
    tr = Translator(dst_code, dry_run)

    with open(en_path, encoding="utf-8") as f:
        en_lines = f.readlines()

    def is_usable(path, en_val):
        """True if the existing translation for `path` can be reused as-is."""
        if path not in existing:
            return False
        if not revalidate:
            return True
        cur = existing[path].replace('\\"', '"')
        eng = en_val.replace('\\"', '"')
        # reject a stored translation whose interpolation tokens don't match EN
        return token_multiset(cur) == token_multiset(eng)

    # pass 1: count how many strings will need translating
    stack = []
    n_missing = 0
    for s in en_lines:
        line = s.rstrip("\n")
        m = RE_SECTION_OPEN.match(line)
        if m:
            stack.append(m.group(2))
            continue
        if RE_SECTION_CLOSE.match(line):
            if stack:
                stack.pop()
            continue
        m = RE_LEAF.match(line)
        if m:
            p = ".".join(stack + [m.group(2)])
            if not is_usable(p, m.group(3)):
                n_missing += 1

    progress = None
    if not dry_run and n_missing:
        try:
            from tqdm import tqdm
            progress = tqdm(total=n_missing, unit="str", desc=f"  {lang_name}",
                            ncols=80, leave=True)
        except ImportError:
            pass

    # pass 2: build the output
    stack = []
    out_lines = []
    kept = missing = 0

    for s in en_lines:
        line = s.rstrip("\n")

        m = RE_SECTION_OPEN.match(line)
        if m:
            stack.append(m.group(2))
            out_lines.append(line)
            continue

        if RE_SECTION_CLOSE.match(line):
            if stack:
                stack.pop()
            out_lines.append(line)
            continue

        m = RE_LEAF.match(line)
        if m:
            indent, key, en_val = m.group(1), m.group(2), m.group(3)
            path = ".".join(stack + [key])
            if is_usable(path, en_val):
                val = existing[path]
                kept += 1
            else:
                val = tr.translate(en_val)
                missing += 1
                if progress is not None:
                    progress.update(1)
            out_lines.append(f'{indent}["{key}"] = "{val}",')
            continue

        if RE_LEAF_MULTILINE.match(line):
            # copy the English multi-line value verbatim (rare); keep as-is
            out_lines.append(line)
            continue

        # `local lang = {`, `return lang`, comments, blank lines, closing `}`
        out_lines.append(line)

    if progress is not None:
        progress.close()

    stale = len(set(existing) - _leaf_keys(en_lines))

    extra = ""
    if tr.n_skipped_code or tr.n_token_fail:
        extra = f"  code_kept_en={tr.n_skipped_code}  token_fail_kept_en={tr.n_token_fail}"

    print(f"  {lang_name:3s}: kept={kept:5d}  translated={missing:5d}  "
          f"stale_dropped={stale:4d}{extra}"
          + ("   [dry-run]" if dry_run else ""))

    if not dry_run:
        content = "\n".join(out_lines) + "\n"

        # never overwrite a good file with a syntactically broken one
        err = _lua_syntax_error(content)
        if err:
            broken = lang_path + ".broken"
            with open(broken, "w", encoding="utf-8") as f:
                f.write(content)
            sys.exit(f"\nREFUSING TO WRITE {lang_name}.lua: generated file has a "
                     f"Lua syntax error:\n  {err}\n  bad output saved to {broken}\n"
                     f"  {lang_name}.lua left untouched.")

        with open(lang_path, "w", encoding="utf-8") as f:
            f.write(content)

    return missing


def _lua_syntax_error(content):
    """Return a one-line error string if `content` is not valid Lua, else None.
    Tries luac5.4 / luac5.3 / luac; if none is available, returns None (skip)."""
    import shutil
    import subprocess
    import tempfile

    luac = next((b for b in ("luac5.4", "luac5.3", "luac") if shutil.which(b)), None)
    if not luac:
        return None
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False,
                                     encoding="utf-8") as tf:
        tf.write(content)
        path = tf.name
    try:
        r = subprocess.run([luac, "-p", path], capture_output=True, text=True)
        if r.returncode != 0:
            return (r.stderr or r.stdout).strip().splitlines()[-1]
        return None
    finally:
        os.unlink(path)


def _leaf_keys(en_lines):
    keys = set()
    stack = []
    for s in en_lines:
        line = s.rstrip("\n")
        m = RE_SECTION_OPEN.match(line)
        if m:
            stack.append(m.group(2))
            continue
        if RE_SECTION_CLOSE.match(line):
            if stack:
                stack.pop()
            continue
        m = RE_LEAF.match(line)
        if m:
            keys.add(".".join(stack + [m.group(2)]))
    return keys


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("lang", help="language file name (de, fr, ...) or 'all'")
    p.add_argument("--dry-run", action="store_true",
                   help="report kept/missing/stale counts, write nothing")
    p.add_argument("--en", default=os.path.join(LOCALES_DIR, "en.lua"),
                   help="reference file (default: scripts/locales/en.lua)")
    p.add_argument("--revalidate", action="store_true",
                   help="also re-translate any EXISTING string whose %%{...} / %%s "
                        "tokens do not match the English reference (fixes old "
                        "corrupt machine translations)")
    p.add_argument("--no-js-check", action="store_true",
                   help="skip the post-run scan for i18n() output printed into "
                        "unescaped JavaScript string literals")
    args = p.parse_args()

    if not os.path.isfile(args.en):
        sys.exit(f"reference file not found: {args.en}")

    targets = list(LANGS) if args.lang == "all" else [args.lang]
    for t in targets:
        if t not in LANGS:
            sys.exit(f"unknown language '{t}'. Known: {', '.join(LANGS)}")

    mode = "DRY RUN - nothing will be written" if args.dry_run else "translating + writing"
    print(f"Reference: {args.en}\nMode: {mode}\n")

    for t in targets:
        print(f"[{t}]")
        sync_one(t, args.en, args.dry_run, args.revalidate)

    if not args.dry_run and not args.no_js_check:
        _run_js_check()

    if not args.dry_run:
        print("\nDone. Review the diff, then rebuild:  make -j$(nproc)")


def _run_js_check():
    """After writing locale files, warn if the codebase still prints i18n()
    output into an UNescaped JavaScript string literal - the class of bug that
    breaks a page's <script> when a translation contains ' or "."""
    import subprocess
    checker = os.path.join(SCRIPT_DIR, "fix_js_i18n.py")
    if not os.path.isfile(checker):
        return
    print("\nScanning for unescaped i18n() in JavaScript string literals ...")
    r = subprocess.run([sys.executable, checker], capture_output=True, text=True)
    out = (r.stdout or "").strip()
    last = out.splitlines()[-1] if out else ""
    if "auto-fixable" in last and not last.startswith("0 auto-fixable, 0"):
        print(out)
        print("\n  ^ run:  tools/localization/fix_js_i18n.py --fix   to wrap "
              "these with js_str()")
    else:
        print("  none found.")


if __name__ == "__main__":
    main()
