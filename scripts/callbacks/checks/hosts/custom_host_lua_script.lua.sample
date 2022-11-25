--
-- (C) 2013-22 - ntop.org
--

--
-- This script is a demo of what ntopng can do when enabling
-- the 'Custom Script Check' behavioural check under the 'Hosts' page
--
-- NOTE: this script is called periodically (i.e. every minute) for every host
--       that ntopng has in memory
--



-- the function below shows an example of how a host alert is triggered
function trigger_dummy_alert()

   local score   = 100
   local message = "dummy host alert message"

   host.triggerAlert(score, message)
end

-- IMPORTANT: do not forget this return at the end of the script
return(0)
