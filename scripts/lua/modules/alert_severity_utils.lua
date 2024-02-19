--
-- (C) 2014-24 - ntop.org
--
--

-- ##############################################

function map_score_to_severity(score)
   if score ~= nil then
       return ntop.mapScoreToSeverity(score)
   end

   return ntop.mapScoreToSeverity(0)
end