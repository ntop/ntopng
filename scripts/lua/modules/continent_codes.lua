--
-- (C) 2021 - ntop.org
--
-- This file contains the list of continent codes and name

local dirs = ntop.getDirs()

-- ################################################################################

-- https://www.php.net/manual/en/function.geoip-continent-code-by-name.php
-- https://doc.bccnsoft.com/docs/php-docs-7-en/function.geoip-continent-code-by-name.html

local continent_codes = {
  ['AF'] = "Africa",
  ['AN'] = "Antarctica",
  ['AS'] = "Asia",
  ['EU'] = "Europe",
  ['NA'] = "North America",
  ['OC'] = "Oceania",
  ['SA'] = "South America"
}

-- ################################################################################

return continent_codes
