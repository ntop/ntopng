# Localization tools

`scripts/locales/en.lua` is the **reference**. Every other language file
(`de.lua`, `fr.lua`, ...) must contain the same keys, in the same structure.

The common task: **English strings were added or changed in `en.lua` — propagate
the new keys to every other language.**

---

## TL;DR

```bash
# from the ntopng root

# 0. one-time: install the translator
uv venv tools/localization/.venv
uv pip install --python tools/localization/.venv deep-translator

# 1. DRY RUN — see how many strings are missing / stale per language
tools/localization/.venv/bin/python tools/localization/sync_locale.py all --dry-run

# 2. TRANSLATE — regenerate every language file from en.lua.
#    --revalidate also re-does any OLD translation whose %{...} / %s tokens
#    drifted from the English reference (fixes historical bad MT).
tools/localization/.venv/bin/python tools/localization/sync_locale.py all --revalidate

# 3. review + build
git diff --stat scripts/locales/

# 4. commit
git add scripts/locales/*.lua
git commit -m "i18n: sync all languages with en.lua"
```

To do a single language, replace `all` with the file name (`de`, `fr`, `cn`, …).

---

## `sync_locale.py`

Regenerates a locale file **from `en.lua`** so that the result:

* has exactly the same keys, order and section structure as `en.lua`;
* has **no stale keys** — keys no longer present in `en.lua` are dropped;
* keeps every translation that already existed in the target file;
* auto-translates (Google Translate) **only** the keys that were missing;
* takes comments and blank lines from `en.lua`.

**Safety guards**

* `%{name}`, `%s`, `%d`, `%1$s` tokens are shielded during translation and the
  result is rejected (English kept) if any token was dropped, added or mangled —
  e.g. Google turning `%{host}` into `%{hôte}`.
* Strings that embed JavaScript or heavy HTML (`<script`, `onclick=`,
  `` ` ``, `=>`, `document.`, …) are **not** machine translated — the English
  value is kept verbatim so no page script breaks.
* The run summary prints `code_kept_en=` and `token_fail_kept_en=` counts;
  grep the output for `TOKEN-MISMATCH` / `NETWORK-FAIL` to review them.

```
tools/localization/sync_locale.py <lang|all> [--dry-run] [--en PATH]
```

| flag | meaning |
|---|---|
| `--dry-run` | print `kept / translated / stale_dropped` counts, write nothing |
| `--revalidate` | also re-translate existing strings whose `%{...}` / `%s` tokens don't match English |
| `--en PATH` | use a different reference file (default `scripts/locales/en.lua`) |

Language file name → Google Translate code (handled automatically):

| file | code | | file | code | | file | code |
|---|---|---|---|---|---|---|---|
| `cn` | `zh-CN` | | `de` | `de` | | `it` | `it` |
| `cz` | `cs`    | | `es` | `es` | | `jp` | `ja` |
| `fr` | `fr`    | | `ko` | `ko` | | `pt` | `pt` |

**Speed:** one network call per missing string (~1–2 strings/s). A language that
is thousands of strings behind can take 20–40 min. `sync_locale.py all` is safe
to leave running. Re-running is cheap: already-translated strings are kept, only
new gaps are filled.

**Quality:** machine translation is a starting point. Human review before
release is recommended, especially for `cn` / `jp` / `ko`. A string that fails
translation permanently keeps the English text — grep the run output for
`FAILED`.

---

## `localize.sh` — checks and manual workflow

`localize.sh` still works for status checks and the human-translator workflow.

| Command | Purpose |
|---|---|
| `localize.sh sort <lang>` | re-serialise + sort a file (strips comments) |
| `localize.sh status <lang>` | show the localization gap |
| `localize.sh missing <lang>` | print the not-yet-translated strings |
| `localize.sh all <lang>` | print every translated string |
| `localize.sh extend <lang> file.txt` | merge a translated report back in |

> **Note:** `localize.sh missing` refuses to run while the target file still has
> stale keys, and its diff engine under-reports on large files. For an accurate
> count use `sync_locale.py --dry-run`.

### Third-party (human) translation

```bash
tools/localization/sync_locale.py de --dry-run          # how many strings?
tools/localization/localize.sh missing de > to_localize_de.txt
```

Format:

```
lang.manage_users.manage = "Manage"
lang.manage_users.manage_user_x = "Manage User %{user}"
```

The translator edits **only** the text to the right of `=`, keeps the
punctuation, does **not** translate `%{...}` placeholders, and does not change
the file structure. Then:

```bash
tools/localization/localize.sh extend de to_localize_de.txt
tools/localization/localize.sh sort de
```

---

## Files

| file | role |
|---|---|
| `sync_locale.py` | **main tool** — sync a language with `en.lua` (auto-translate) |
| `fix_js_i18n.py` | scan/fix `i18n()` output printed into unescaped JS string literals |
| `localize.sh` | status checks + human-translator merge workflow |
| `missing_localization.py` | diff helper used by `localize.sh` |
| `sort_localization_file.lua` | re-serialise / sort a locale file |
| `persistence.lua` | Lua table serializer used by the sort tool |
| `translation.py` | **obsolete** — superseded by `sync_locale.py` |

---

## `fix_js_i18n.py` — JS string-literal safety

Localized strings contain apostrophes (`l'hote`), quotes and line breaks. When a
`.lua` page prints `i18n()` output **inside a JavaScript string literal** in an
inline `<script>`, such a character ends the JS string early and throws
`SyntaxError: Unexpected identifier` / `missing )`, which aborts the whole
`<script>` block - later functions never get defined
(`reset_pwd_dialog is not defined`).

Fix: wrap with **`js_str()`** (in `scripts/lua/modules/lua_utils_generic.lua`),
which escapes `\ ' " CR LF`.

```bash
tools/localization/fix_js_i18n.py           # report unescaped sites
tools/localization/fix_js_i18n.py --fix     # wrap the provably-safe ones
```

`sync_locale.py` runs this scanner in **report mode** automatically after every
non-dry-run (disable with `--no-js-check`). It never auto-edits `.lua` source
during a translation run - run `fix_js_i18n.py --fix` yourself and review the
diff. Concat-style embeds are reported as `CHECK`, never auto-fixed.
