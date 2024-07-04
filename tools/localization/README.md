# Localization tools

The tool `localize.sh` can be used to perform many localization checks and
operations to complement the actual file localization tasks.

Here are some examples of what to do in order to fulfil the localization
requirements.

## After a manual modification of a localization file the file must be sorted
```
tools/localization/localize.sh sort en
```

## Verify the current localization status of a language
```
tools/localization/localize.sh status de
```

## Send the new strings to localize to a third party
```
tools/localization/localize.sh missing de > to_localize_de.txt
```

This will generate the `to_localize_de.txt` which can be sent to the third party
translator. It has the following format:

```
lang.manage_users.manage = "Manage"
lang.manage_users.manage_user_x = "Manage User %{user}"
...
```

*Important*: the third party translator should only modify the strings located at the
*right* of the `=` sign while trying to maintain the same punctation and format used.
Strings enclosed in curly braces `%{user}` *should not* be localized.

Moreover, the translator should not modify *the structure* of the txt file. After
translating the file, the translator should send back the modified text file.

Here is an example of the localized version of `to_localize_de.txt`:

```
lang.manage_users.manage = "Verwalten"
lang.manage_users.manage_user_x = "Verwalte User %{user}"
...
```

By keeping the file format consistent, the localized strings can be easily
integrated as explained below.

## Integrate the third party localized strings
```
tools/localization/localize.sh extend de path_to_localized_strings.txt
```

## Translate Automatically Languages

See the tool ``translation.py``
