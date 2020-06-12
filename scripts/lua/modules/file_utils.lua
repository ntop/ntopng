--
-- (C) 2019-20 - ntop.org
--

local file_utils = {}
local os_utils = require("os_utils")

-- ##############################################

function file_utils.copy_file(fname, src_path, dst_path)
   local src
   local dst

   if(fname == nil) then
      src = os_utils.fixPath(src_path)
      dst = os_utils.fixPath(dst_path)
   else
      src = os_utils.fixPath(src_path .. "/" .. fname)
      dst = os_utils.fixPath(dst_path .. "/" .. fname)
   end

   local infile, err = io.open(src, "rb")

   -- NOTE: Do not forget the 'b' flag [https://www.lua.org/pil/21.2.2.html]
   --       as this is compulsory on windows

   traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Copying file %s -> %s", src, dst))

   if(do_trace) then
      io.write(string.format("\tLoad [%s]\n", fname))
   end

   if(ntop.exists(dst)) then
      -- NOTE: overwriting is not allowed as it means that a file was already provided by
      -- another plugin
      -- io.write(debug.traceback())
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Trying to overwrite existing file %s", dst))
      return(false)
   end

   if(infile == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not open file %s for read: %s", src, err or ""))
      return(false)
   end

   local instr = infile:read("*all")
   infile:close()

   local outfile, err = io.open(dst, "wb")
   if(outfile == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not open file %s for write", dst, err or ""))
      return(false)
   end

   outfile:write(instr)
   outfile:close()

   ntop.setDefaultFilePermissions(dst)

   return(true)
end

-- #########################################################

function file_utils.recursive_copy(src_path, dst_path, path_map, required_extension)
   for fname in pairs(ntop.readdir(src_path)) do
      local do_copy = true

      if((required_extension ~= nil) and not(ends(fname, ".lua"))) then
	 -- Don't copy
	 do_copy = false
	 traceError(TRACE_INFO, TRACE_CONSOLE, "SKIP file_utils.recursive_copy("..fname.." ["..src_path.." -> "..dst_path.."])\n")
      end

      if(do_copy) then
	 traceError(TRACE_INFO, TRACE_CONSOLE, "COPY file_utils.recursive_copy("..fname.." ["..src_path.." -> "..dst_path.."])\n")

	 if not file_utils.copy_file(fname, src_path, dst_path) then
	    return(false)
	 end

	 if path_map then
	    path_map[os_utils.fixPath(dst_path .. "/" .. fname)] = os_utils.fixPath(src_path .. "/" .. fname)
	 end
      end
   end

   return(true)
end

-- #########################################################

return(file_utils)
