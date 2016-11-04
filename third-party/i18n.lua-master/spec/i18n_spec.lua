require 'spec.fixPackagePath'

local i18n = require 'i18n'

describe('i18n', function()

  before_each(function() i18n.reset() end)

  describe('translate/set', function()
    it('sets a value in the internal store', function()
      i18n.set('en.foo','var')
      assert.equal('var', i18n('foo'))
    end)

    it('splits keys via their dots', function()
      i18n.set('en.message.cool', 'hello!')
      assert.equal('hello!', i18n('message.cool'))
    end)

    it('interpolates variables', function()
      i18n.set('en.message', 'Hello %{name}, your score is %{score}')
      assert.equal('Hello Vegeta, your score is 9001', i18n('message', {name = 'Vegeta', score = 9001}))
    end)

    it('checks that the first two parameters are non-empty strings', function()
      assert.error(function() i18n.set("","") end)
      assert.error(function() i18n.set("",1) end)
      assert.error(function() i18n.set(1,1) end)
      assert.error(function() i18n.set() end)
    end)

    describe('when an entry is missing', function()

      describe('and a locale parameter is given', function()
        it('uses the given locale', function()
          i18n.set('es.msg', 'hola')
          assert.equal('hola', i18n('msg', {locale = 'es'}))
        end)
      end)

      it('looks it up in locale ancestry', function()
        i18n.set('es.msg', 'hola')
        i18n.setLocale('es-MX')
        assert.equal('hola', i18n('msg'))
      end)

      it('uses the fallback locale', function()
        i18n.set('es.msg', 'hola')
        i18n.setLocale('fr')
        assert.is_nil(i18n('msg'))
        i18n.setFallbackLocale('es')
        assert.equal('hola', i18n('msg'))
      end)

      it('uses the fallback locale ancestry', function()
        i18n.set('es.msg', 'hola')
        i18n.setLocale('fr')
        assert.is_nil(i18n('msg'))
        i18n.setFallbackLocale('es-MX')
        assert.equal('hola', i18n('msg'))
      end)

      it('uses the default parameter, if given', function()
        assert.equal('bonjour', i18n('msg', {default='bonjour'}))
      end)

    end)

    describe('when there is a count-type translation', function()
      describe('and the locale is the default one (english)', function()
        before_each(function()
          i18n.setLocale('en')
          i18n.set('en.message', {
            one   = "Only one message.",
            other = "%{count} messages."
          })
        end)

        it('pluralizes correctly', function()
          assert.equal("Only one message.", i18n('message', {count = 1}))
          assert.equal("2 messages.", i18n('message', {count = 2}))
          assert.equal("0 messages.", i18n('message', {count = 0}))
        end)

        it('defaults to 1', function()
          assert.equal("Only one message.", i18n('message'))
        end)
      end)

      describe('and the locale is french', function()
        before_each(function()
          i18n.setLocale('fr')
          i18n.set('fr.message', {
            one   = "Une chose.",
            other = "%{count} choses."
          })
        end)

        it('Ça marche', function()
          assert.equal("Une chose.", i18n('message', {count = 1}))
          assert.equal("Une chose.", i18n('message', {count = 1.5}))
          assert.equal("2 choses.", i18n('message', {count = 2}))
          assert.equal("Une chose.", i18n('message', {count = 0}))
        end)

        it('defaults to 1', function()
          assert.equal("Une chose.", i18n('message'))
        end)
      end)

    end)
  end)

  describe('load', function()
    it("loads a bunch of stuff", function()
      i18n.load({
        en = {
          hello  = 'Hello!',
          inter  = 'Your weight: %{weight}',
          plural = {
            one = "One thing",
            other = "%{count} things"
          }
        },
        es = {
          hello  = '¡Hola!',
          inter  = 'Su peso: %{weight}',
          plural = {
            one = "Una cosa",
            other = "%{count} cosas"
          }
        }
      })

      assert.equal('Hello!', i18n('hello'))
      assert.equal('Your weight: 5', i18n('inter', {weight = 5}))
      assert.equal('One thing', i18n('plural', {count = 1}))
      assert.equal('2 things', i18n('plural', {count = 2}))
      i18n.setLocale('es')
      assert.equal('¡Hola!', i18n('hello'))
      assert.equal('Su peso: 5', i18n('inter', {weight = 5}))
      assert.equal('Una cosa', i18n('plural', {count = 1}))
      assert.equal('2 cosas', i18n('plural', {count = 2}))
    end)
  end)

  describe('loadFile', function()
    it("Loads a bunch of stuff", function()
      i18n.loadFile('spec/en.lua')
      assert.equal('Hello!', i18n('hello'))
      local balance = i18n('balance', {value = 0})
      assert.equal('Your account balance is 0.', balance)
    end)
  end)

  describe('set/getFallbackLocale', function()
    it("defaults to en", function()
      assert.equal('en', i18n.getFallbackLocale())
    end)
    it("throws error on empty or erroneous locales", function()
      assert.error(i18n.setFallbackLocale)
      assert.error(function() i18n.setFallbackLocale(1) end)
      assert.error(function() i18n.setFallbackLocale("") end)
    end)
  end)

  describe('set/getLocale', function()
    it("defaults to en", function()
      assert.equal('en', i18n.getLocale())
    end)

    it("modifies translate", function()
      i18n.set('fr.foo','bar')
      i18n.setLocale('fr')
      assert.equal('bar', i18n('foo'))
    end)

    it("does NOT modify set", function()
      i18n.setLocale('fr')
      i18n.set('fr.foo','bar')
      assert.equal('bar', i18n('foo'))
    end)

    it("does NOT modify load", function()
      i18n.setLocale('fr')
      i18n.load({fr = {foo = 'Foo'}})
      assert.equal('Foo', i18n('foo'))
    end)

    it("does NOT modify loadFile", function()
      i18n.loadFile('spec/en.lua')
      assert.equal('Hello!', i18n('hello'))
    end)

    describe("when a second parameter is passed", function()
      it("throws an error if the second param is not a function", function()
        assert.error(function() i18n.setLocale('wookie', 1) end)
        assert.error(function() i18n.setLocale('wookie', 'foo') end)
        assert.error(function() i18n.setLocale('wookie', {}) end)
      end)
      it("uses the provided function to calculate plurals", function()
        local count = function(n)
          return (n < 10 and "hahahaha") or "other"
        end
        i18n.setLocale('dracula', count)
        i18n.load({dracula = { msg = { hahahaha = "Let's count to %{count}. hahahaha", other = "wha?" }}})

        assert.equal("Let's count to 5. hahahaha", i18n('msg', {count = 5}))
        assert.equal("Let's count to 3. hahahaha", i18n('msg', {count = 3}))
        assert.equal("wha?", i18n('msg', {count = 11}))
      end)
    end)
  end)

end)
