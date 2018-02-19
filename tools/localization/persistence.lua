-- Adapted from http://lua-users.org/wiki/TablePersistence to preserve order and
-- put single values at the end of the stream

local write, writeIndent, writers, refCount;

function pairsByKeyVals(t, f)
  local a = {}

  -- io.write(debug.traceback().."\n")
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, function(x, y) return f(x, y, t[x], t[y]) end)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end
function asc_table_after(a,b,t_a,t_b)
  local a_is_table = (type(t_a) == "table")
  local b_is_table = (type(t_b) == "table")

  if a_is_table and not b_is_table then
    return false
  elseif not a_is_table and b_is_table then
    return true
  else
    return (a < b)
  end
end

persistence =
{
  store = function (path, ...)
    local file, e = io.open(path, "w");
    if not file then
      return error(e);
    end
    local n = select("#", ...);
    -- Count references
    local objRefCount = {}; -- Stores reference that will be exported
    for i = 1, n do
      refCount(objRefCount, (select(i,...)));
    end;
    -- Export Objects with more than one ref and assign name
    -- First, create empty tables for each
    local objRefNames = {};
    local objRefIdx = 0;

    local has_objRefCount = false
    for obj, count in pairs(objRefCount) do
      if count > 1 then
        has_objRefCount = true
        break
      end
    end

    if has_objRefCount then
      file:write("-- Persistent Data\n");
      file:write("local multiRefObjects = {\n");
      for obj, count in pairs(objRefCount) do
        if count > 1 then
          objRefIdx = objRefIdx + 1;
          objRefNames[obj] = objRefIdx;
          file:write("{};"); -- table objRefIdx
        end;
      end;
      file:write("\n} -- multiRefObjects\n");

      -- Then fill them (this requires all empty multiRefObjects to exist)
      for obj, idx in pairs(objRefNames) do
        for k, v in pairs(obj) do
          file:write("multiRefObjects["..idx.."][");
          write(file, k, 0, objRefNames);
          file:write("] = ");
          write(file, v, 0, objRefNames);
          file:write("\n");
        end;
      end;
    end
    -- Create the remaining objects
    for i = 1, n do
      local suffix = ""
      if i > 1 then
        suffix = (i-1) .. ""
      end
      file:write("local ".."lang"..suffix.." = ");
      write(file, (select(i,...)), 0, objRefNames);
      file:write("\n");
    end
    -- Return them
    if n > 0 then
      file:write("\nreturn lang");
      for i = 2, n do
        file:write(" ,lang"..(i-1));
      end;
      file:write("\n");
    else
      file:write("return\n");
    end;
    if type(path) == "string" then
      file:close();
    end;
  end;

  load = function (path)
    local f, e;
    if type(path) == "string" then
      f, e = loadfile(path);
    else
      f, e = path:read('*a')
    end
    if f then
      return f();
    else
      return nil, e;
    end;
  end;
}

-- Private methods

-- write thing (dispatcher)
write = function (file, item, level, objRefNames)
  writers[type(item)](file, item, level, objRefNames);
end;

-- write indent
writeIndent = function (file, level)
  for i = 1, level do
    file:write("  ");
  end;
end;

-- recursively count references
refCount = function (objRefCount, item)
  -- only count reference types (tables)
  if type(item) == "table" then
    -- Increase ref count
    if objRefCount[item] then
      objRefCount[item] = objRefCount[item] + 1;
    else
      objRefCount[item] = 1;
      -- If first encounter, traverse
      for k, v in pairs(item) do
        refCount(objRefCount, k);
        refCount(objRefCount, v);
      end;
    end;
  end;
end;

-- Format items for the purpose of restoring
writers = {
  ["nil"] = function (file, item)
      file:write("nil");
    end;
  ["number"] = function (file, item)
      file:write(tostring(item));
    end;
  ["string"] = function (file, item)
      file:write(string.format("%q", item));
    end;
  ["boolean"] = function (file, item)
      if item then
        file:write("true");
      else
        file:write("false");
      end
    end;
  ["table"] = function (file, item, level, objRefNames)
      local refIdx = objRefNames[item];
      if refIdx then
        -- Table with multiple references
        file:write("multiRefObjects["..refIdx.."]");
      else
        -- Single use table
        file:write("{\n");
        for k, v in pairsByKeyVals(item, asc_table_after) do
          writeIndent(file, level+1);
          file:write("[");
          write(file, k, level+1, objRefNames);
          file:write("] = ");
          write(file, v, level+1, objRefNames);
          file:write(",\n");
        end
        writeIndent(file, level);
        file:write("}");
      end;
    end;
  ["function"] = function (file, item)
      -- Does only work for "normal" functions, not those
      -- with upvalues or c functions
      local dInfo = debug.getinfo(item, "uS");
      if dInfo.nups > 0 then
        file:write("nil --[[functions with upvalue not supported]]");
      elseif dInfo.what ~= "Lua" then
        file:write("nil --[[non-lua function not supported]]");
      else
        local r, s = pcall(string.dump,item);
        if r then
          file:write(string.format("loadstring(%q)", s));
        else
          file:write("nil --[[function could not be dumped]]");
        end
      end
    end;
  ["thread"] = function (file, item)
      file:write("nil --[[thread]]\n");
    end;
  ["userdata"] = function (file, item)
      file:write("nil --[[userdata]]\n");
    end;
}

return persistence
