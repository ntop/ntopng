require 'spec.fixPackagePath'

local plural = require 'i18n.plural'

describe('i18n.plural', function()
  before_each(plural.reset)

  it("exists", function()
    assert.equal('table', type(plural))
  end)

  describe('plural.get', function()

    local function test_get(title, locales, plural_forms)
      locales = type(locales) == 'table' and locales or {locales}

      describe(title, function()
        for _,locale in ipairs(locales) do
          for plural_form, numbers in pairs(plural_forms) do
            numbers = type(numbers) == 'table' and numbers or {numbers}
            it(('%s translates numbers into their correct plural form'):format(locale), function()
              for _,n in ipairs(numbers) do
                assert.equal(plural.get(locale, n), plural_form)
                assert.equal(plural.get(locale, -n), plural_form)
              end
            end)
          end
        end
      end)
    end

    local function words(str)
      local result, length = {}, 0
      str:gsub("%S+", function(word)
        length = length + 1
        result[length] = word
      end)
      return result
    end

    it('throws an error with the wrong parameters', function()
      assert.error(function() plural.get() end)
      assert.error(function() plural.get(1,1) end)
      assert.error(function() plural.get('en', 'en') end)
    end)


    test_get('f1', words([[ af en it nb rof teo ]]), {
      one   = 1,
      other = {0, 2, 999, 0.5, 1.2, 2.07}
    })

    test_get('f2', words("ak am bh fil guw hi ln mg nso ti tl wa"), {
      one   = {0, 1},
      other = {2, 999, 1.2, 2.07}
    })

    test_get('f3', 'ar', {
      zero  = 0,
      one   = 1,
      two   = 2,
      few   = {3, 10, 103, 110, 203, 210},
      many  = {11, 99, 111, 199},
      other = {100, 102, 200, 202, 0.2, 1.07, 3.81}
    })

    test_get('f4', words([[
      az bm bo dz fa hu id ig ii ja jv ka kde kea km kn
    ]]), {
      other = {0 , 1, 1000, 0.5}
    })

    test_get('f5', words("be bs hr ru sh sr uk"), {
      one   = {1, 21, 31, 41, 51},
      few   = {2,4, 22, 24, 32, 34},
      many  = {0, 5, 20, 25, 30, 35, 40},
      other = {1.2, 2.07}
    })

    test_get('f6', 'br', {
      one   = {1, 21, 31, 41, 51},
      two   = {2, 22, 32, 42, 52},
      few   = {3, 4, 9, 23, 24, 29},
      many  = {1000000, 100000000},
      other = {0, 5, 8, 10, 20, 25, 28, 1.2, 2.07}
    })

    test_get('f7', {'cz','sk'}, {
      one   = 1,
      few   = {2, 3, 4},
      other = {0, 5, 8, 10, 1.2, 2.07}
    })

    test_get('f8', 'cy', {
      zero  = 0,
      one   = 1,
      two   = 2,
      few   = 3,
      many  = 6,
      other = {4, 5, 7, 10, 101, 0.2, 1.07, 3.81}
    })

    test_get('f9', {'ff', 'fr', 'kab'}, {
      one   = {0, 0.1, 0.5, 1, 1.5, 1.8},
      other = {2, 3, 10, 20, 2.07}
    })

    test_get('f10', 'ga', {
      one   = 1,
      two   = 2,
      few   = {3, 4, 5, 6},
      many  = {7, 8, 9, 10},
      other = {0, 11, 12, 20, 25, 100, 1.2, 2.07 }
    })

    test_get('f11', 'gd', {
      one   = {1, 11},
      two   = {2, 12},
      few   = {3, 10, 13, 19},
      other = {0, 20, 100, 1.2, 2.07}
    })

    test_get('f12', 'gv', {
      one   = {0, 1, 2, 11, 12, 20, 21, 22},
      other = {3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 1.5}
    })

    test_get('f13', words('iu kw naq se sma smi smj smn sms'), {
      one   = 1,
      two   = 2,
      other = {0, 3, 10, 1.2, 2.07}
    })

    test_get('f14', 'ksh', {
      zero  = 0,
      one   = 1,
      other = {2, 3, 5, 10, 100, 2.3, 1.07}
    })

    test_get('f15', 'lag', {
      zero  = 0,
      one   = {0.5, 1, 1.5, 1.97},
      other = {2, 3, 10, 100, 2.10}
    })

    test_get('f16', 'lt', {
      one   = {1, 21, 31, 41, 51, 61},
      few   = {2, 3, 4, 5, 6, 7, 8, 9, 22, 23, 24},
      other = {0, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 30, 40, 50, 1.5, 2.07}
    })

    test_get('f17', 'lv', {
      zero  = 0,
      one   = {1, 21, 31, 41, 51, 61},
      other = {2, 5, 10, 15, 20, 22, 23, 30, 32, 33, 40, 0.2, 2.07}
    })

    test_get('f18', 'mk', {
      one   = {1, 21, 31, 41, 51, 61},
      other = {0, 2, 5, 10, 100, 0.2, 2.07}
    })

    test_get('f19', {'mo','ro'}, {
      one   = 1,
      few   = {0, 2, 10, 15, 19, 101, 119, 201, 219},
      other = {20, 100, 120, 200, 220, 300, 1.2, 2.07}
    })

    test_get('f20', 'mt', {
      one   = 1,
      few   = {0, 2, 5, 10, 102, 105, 110, 202, 205, 210},
      many  = {11, 15, 19, 111, 115, 119, 211, 215, 219},
      other = {20, 21, 50, 53, 101, 220, 221, 1.4, 11.61, 20.81}
    })

    test_get('f21', 'pl', {
      one   = 1,
      few   = {2, 3, 4, 22, 23, 24, 32, 33, 34},
      many  = {0, 5, 6, 7, 8, 9, 10, 15, 20, 21, 25, 26, 27, 28, 29, 30, 31, 35},
      other = {1.2, 2.7, 5.94}
    })

    test_get('f22', 'shi', {
      one   = {0, 1},
      other = {2, 5, 10, 100, 1.2, 2.7, 5.94}
    })

    test_get('f23', 'sl', {
      one   = {1, 101, 201, 301, 401},
      two   = {2, 102, 202, 302, 402},
      few   = {3, 4, 103, 104, 203, 204},
      other = {0, 5, 6, 7, 105, 106, 107, 1.2, 11.5, 3.4}
    })

    test_get('f24', 'tzm', {
      one   = {0, 1, 11, 12, 15, 20, 25, 50, 98, 99},
      other = {2, 3, 4, 5, 6, 7, 8, 9, 10, 100, 101, 102, 0.5, 1.7}
    })

    describe("When the locale is not found", function()
      describe("When a default function is set", function()
        before_each(function()
          plural.setDefaultFunction(function() return 'nothing' end)
        end)

        test_get('non-existing languages use it', {'klingon', 'elvish'}, {
          nothing = {0, 1, 1000, 0.5}
        })

        test_get('existing languages do not use it', {'fr'}, {
          one   = {0, 0.1, 0.5, 1, 1.5, 1.8},
          other = {2, 3, 10, 20, 2.07}
        })
      end)

      describe("When a default function is not set", function()
        test_get('non-existing languages use english', {'klingon', 'elvish'}, {
          one   = 1,
          other = {0, 2, 1000, 0.5}
        })
      end)
    end)
  end)
end)
