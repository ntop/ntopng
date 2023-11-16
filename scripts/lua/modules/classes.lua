--- classes.lua
--
-- The classes library enables simple OOP constructs using prototypes and meta-tables.
--
-- @author Paul Moore
--
-- Copyright (C) 2011 by Strange Ideas Software
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local classes = {}

-- Baseclass of all objects.
classes.Object = {}
classes.Object.class = classes.Object
--- Nullary constructor.
function classes.Object:init (...)
end
--- Base alloc method.
function classes.Object.alloc (mastertable)
   return setmetatable({}, {__index = classes.Object, __newindex = mastertable})
end
--- Base new method.
function classes.Object.new (...)
   return classes.Object.alloc({}):init(...)
end
--- Checks if this object is an instance of class.
-- @param class The class object to check.
-- @return Returns true if this object is an instance of class, false otherwise.
function classes.Object:instanceOf (class)
   -- Recurse up the supertypes until class is found, or until the supertype is not part of the inheritance tree.
   if self.class == class then
      return true
   end
   if self.super then
      return self.super:instanceOf(class)
   end
   return false
end

--- Creates a new class.
-- @param baseclass The Baseclass of this class, or nil.
-- @return A new class reference.
function classes.class (baseclass)
   -- Create the class definition and metatable.
   local classdef = {}
   -- Find the super class, either Object or user-defined.
   baseclass = baseclass or classes.Object
   -- If this class definition does not know of a function, it will 'look up' to the Baseclass via the __index of the metatable.
   setmetatable(classdef, {__index = baseclass})
   -- All class instances have a reference to the class object.
   classdef.class = classdef
   --- Recursivly allocates the inheritance tree of the instance.
   -- @param mastertable The 'root' of the inheritance tree.
   -- @return Returns the instance with the allocated inheritance tree.
   function classdef.alloc (mastertable)
      -- All class instances have a reference to a superclass object.
      local instance = {super = baseclass.alloc(mastertable)}
      -- Any functions this instance does not know of will 'look up' to the superclass definition.
      setmetatable(instance, {__index = classdef, __newindex = mastertable})
      return instance
   end
   --- Constructs a new instance from this class definition.
   -- @param arg Arguments to this class' constructor
   -- @return Returns a new instance of this class.
   function classdef.new (...)
      -- Create the empty object.
      local instance = {}
      -- Start the process of creating the inheritance tree.
      instance.super = baseclass.alloc(instance)
      setmetatable(instance, {__index = classdef})
      -- Finally, init the object, it is up to the programmer to choose to call the super init method.
      instance:init(...)
      return instance
   end
   -- Finally, return the class we created.
   return classdef
end

return classes
