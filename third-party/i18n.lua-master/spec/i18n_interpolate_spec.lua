require 'spec.fixPackagePath'

local interpolate = require 'i18n.interpolate'

describe('i18n.interpolate', function()
  it("exists", function()
    assert.equal('function', type(interpolate))
  end)

  it("performs standard interpolation via string.format", function()
    assert.equal("My name is John, I am 13", interpolate("My name is %s, I am %d", {"John", 13}))
  end)

  describe("When interpolating with hash values", function()

    it("converts non-existing items in nil values without error", function()
      assert.equal("Nil = nil", interpolate("Nil = %{null}"))
    end)

    it("converts variables in stringifield values", function()
      assert.equal("My name is John, I am 13", interpolate("My name is %{name}, I am %{age}", {name = "John", age = 13}))
    end)

    it("ignores spaces inside the brackets", function()
      assert.equal("My name is John, I am 13", interpolate("My name is %{ name }, I am %{ age }", {name = "John", age = 13}))
    end)

    it("is escaped via double %%", function()
      assert.equal("I am a %{blue} robot.", interpolate("I am a %%{blue} robot."))
    end)

  end)

  describe("When interpolating with hash values and formats", function()
    it("converts non-existing items in nil values without error", function()
      assert.equal("Nil = nil", interpolate("Nil = %<null>.s"))
    end)

    it("converts variables in stringifield values", function()
      assert.equal("My name is John, I am 13", interpolate("My name is %<name>.s, I am %<age>.d", {name = "John", age = 13}))
    end)

    it("ignores spaces inside the brackets", function()
      assert.equal("My name is John, I am 13", interpolate("My name is %< name >.s, I am %< age >.d", {name = "John", age = 13}))
    end)

    it("is escaped via double %%", function()
      assert.equal("I am a %<blue>.s robot.", interpolate("I am a %%<blue>.s robot."))
    end)
  end)

  it("Interpolates everything at the same time", function()
    assert.equal('A nil ref and %<escape>.d and spaced and "quoted" and something',
      interpolate("A %{null} ref and %%<escape>.d and %{ spaced } and %<quoted>.q and %s", {
        "something",
        spaced = "spaced",
        quoted = "quoted"
      })
    )
  end)
end)
