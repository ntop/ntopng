# Knowledge Base Protocol

This section is identical in ntop-lua-to-vue-porter and ntop-rest-endpoint-scaffolder.
Both skills follow the same read-first / write-last pattern against `.claude/ntop-knowledge.md`.

---

## KB Step A — Read before exploring (run this FIRST, before any other step)

Before touching any project file, grep the knowledge base for relevant existing findings:

```
Read: .claude/ntop-knowledge.md
Grep for: the Lua filename, module names referenced in the file, and the data domain
          (e.g. "asn", "country", "alert", "license")
```

For each section, apply findings as follows:

| Section | How to use |
|---|---|
| **Module Functions** | If a module function you need is already documented, use the recorded signature directly — do not re-read the module file unless you need a function not yet listed |
| **Ported Page Patterns** | If a similar page has been ported before, use its `context` prop structure and REST shape as a starting template — adapt rather than design from scratch |
| **REST Endpoint Conventions** | Apply any recorded conventions immediately — do not rediscover path decisions or param naming patterns already documented |

If the knowledge base has no relevant entries for the current task, proceed with full
exploration as normal and document findings at the end (KB Step B).

---

## KB Step B — Write after completing (run this LAST, after all other steps)

After the task is fully complete and the build is clean, append new findings to
`.claude/ntop-knowledge.md`. Follow these rules strictly:

### Deduplication
Before appending any entry, grep the relevant section for the entry's key
(module+function name, Lua filename, or endpoint path). If it already exists,
update the existing entry in place rather than adding a duplicate.

### What to record

**Module Functions** — record every module function you called or read during this run
that is not yet in the knowledge base:
```
- `<module>.<function>(<params>) → <return_type>` — <one-line description>
  Source: <path to module file>
  Notes: <any non-obvious behaviour, nil conditions, Pro-only flag if applicable>
```

**Ported Page Patterns** — record one entry per completed port:
```
### <OriginalLuaFilename> → <VueComponentName>
- Context props passed: `{ <prop>: <type>, ... }`
- REST endpoints used: `<path>` (✅ clean / ♻️ refactored / 🆕 created)
- TableWithConfig: yes/no — columns: `[<field_names>]`
- Notable patterns: <anything reusable — e.g. "isPro passed as boolean prop",
  "breakdown sub-object shape", "navbar had 3 tabs mapped to page= param">
```

**REST Endpoint Conventions** — record any non-obvious decision made during endpoint
work that would save time on the next run:
```
- <Convention title>: <one or two sentence description>
  Example: `<concrete code snippet or path>`
```

### Update the timestamp
After appending, update the `Last updated:` line at the top of the file with
the current date.

---

## KB Step C — Self-improvement signal

If during a run you find that an existing knowledge base entry was **wrong or
incomplete** (e.g. a function signature changed, a convention was an exception
not a rule), correct the entry in place and add a `> ⚠️ Updated: <reason>` note
below it. Do not silently overwrite — leave the correction visible so the user
can review it.