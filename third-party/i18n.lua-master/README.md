i18n.lua
========

[![Build Status](https://travis-ci.org/kikito/i18n.lua.png?branch=master)](https://travis-ci.org/kikito/i18n.lua)

A very complete i18n lib for Lua

Description
===========

``` lua
i18n = require 'i18n'

-- loading stuff
i18n.set('en.welcome', 'welcome to this program')
i18n.load({
  en = {
    good_bye = "good-bye!",
    age_msg = "your age is %{age}.",
    phone_msg = {
      one = "you have one new message.",
      other = "you have %{count} new messages."
    }
  }
})
i18n.loadFile('path/to/your/project/i18n/de.lua') -- load German language file
i18n.loadFile('path/to/your/project/i18n/fr.lua') -- load French language file
…         -- section 'using language files' below describes structure of files

-- setting the translation context
i18n.setLocale('en') -- English is the default locale anyway

-- getting translations
i18n.translate('welcome') -- Welcome to this program
i18n('welcome') -- Welcome to this program
i18n('age_msg', {age = 18}) -- Your age is 18.
i18n('phone_msg', {count = 1}) -- You have one new message.
i18n('phone_msg', {count = 2}) -- You have 2 new messages.
i18n('good_bye') -- Good-bye!

```

Interpolation
=============

You can interpolate variables in 3 different ways:

``` lua
-- the most usual one
i18n.set('variables', 'Interpolating variables: %{name} %{age}')
i18n('variables', {name='john', 'age'=10}) -- Interpolating variables: john 10

i18n.set('lua', 'Traditional Lua way: %d %s')
i18n('lua', {1, 'message'}) -- Traditional Lua way: 1 message

i18n.set('combined', 'Combined: %<name>.q %<age>.d %<age>.o')
i18n('combined', {name='john', 'age'=10}) -- Combined: john 10 12k
```



Pluralization
=============

This lib implements the [unicode.org plural rules](http://cldr.unicode.org/index/cldr-spec/plural-rules). Just set the locale you want to use and it will deduce the appropiate pluralization rules:

``` lua
i18n = require 'i18n'

i18n.load({
  en = {
    msg = {
      one   = "one message",
      other = "%{count} messages"
    }
  },
  ru = {
    msg = {
      one   = "1 сообщение",
      few   = "%{count} сообщения",
      many  = "%{count} сообщений",
      other = "%{count} сообщения"
    }
  }
})

i18n('msg', {count = 1}) -- one message
i18n.setLocale('ru')
i18n('msg', {count = 5}) -- 5 сообщений
```

The appropiate rule is chosen by finding the 'root' of the locale used: for example if the current locale is 'fr-CA', the 'fr' rules will be applied.

If the provided functions are not enough (i.e. invented languages) it's possible to specify a custom pluralization function in the second parameter of setLocale. This function must return 'one', 'few', 'other', etc given a number.

Fallbacks
=========

When a value is not found, the lib has several fallback mechanisms:

* First, it will look in the current locale's parents. For example, if the locale was set to 'en-US' and the key 'msg' was not found there, it will be looked over in 'en'.
* Second, if the value is not found in the locale ancestry, a 'fallback locale' (by default: 'en') can be used. If the fallback locale has any parents, they will be looked over too.
* Third, if all the locales have failed, but there is a param called 'default' on the provided data, it will be used.
* Otherwise the translation will return nil.

The parents of a locale are found by splitting the locale by its hyphens. Other separation characters (spaces, underscores, etc) are not supported.

Using language files
====================

It might be a good idea to store each translation in a different file. This is supported via the 'i18n.loadFile' directive:

``` lua
…
i18n.loadFile('path/to/your/project/i18n/de.lua') -- German translation
i18n.loadFile('path/to/your/project/i18n/en.lua') -- English translation
i18n.loadFile('path/to/your/project/i18n/fr.lua') -- French translation
…
```

The German language file 'de.lua' should read:

``` lua
return {
  de = {
    good_bye = "Auf Wiedersehen!",
    age_msg = "Ihr Alter beträgt %{age}.",
    phone_msg = {
      one = "Sie haben eine neue Nachricht.",
      other = "Sie haben %{count} neue Nachrichten."
    }
  }
}
```

If desired, you can also store all translations in one single file (eg. 'translations.lua'):

``` lua
return {
  de = {
    good_bye = "Auf Wiedersehen!",
    age_msg = "Ihr Alter beträgt %{age}.",
    phone_msg = {
      one = "Sie haben eine neue Nachricht.",
      other = "Sie haben %{count} neue Nachrichten."
    }
  },
  fr = {
    good_bye = "Au revoir !",
    age_msg = "Vous avez %{age} ans.",
    phone_msg = {
      one = "Vous avez une noveau message.",
      other = "Vous avez %{count} noveaux messages."
    }
  },
  …
}
```

Specs
=====
This project uses [busted](https://github.com/Olivine-Labs/busted) for its specs. If you want to run the specs, you will have to install it first. Then just execute the following from the root inspect folder:

    busted
