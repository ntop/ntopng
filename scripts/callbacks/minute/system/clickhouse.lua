--
-- (C) 2013-22 - ntop.org
--

if(ntop.isPro()) then
   -- Import ClickHouse dumps if any
   local silence_import_errors = false
   
   local num_imports = ntop.importClickHouseDumps(silence_import_errors)

   -- io.write("[ClickHouse] Imported "..num_imports.." dump files\n")
end
