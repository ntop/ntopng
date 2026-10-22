--
-- (C) 2013-26 - ntop.org
--

-- getFlowKey() and getFlowLabelFromId(), split from flow_utils (which loads
-- alert_consts, snmp modules, ...) to be used by light scripts as well.
-- NOTE: flow_utils requires this module, the functions are still global

require "template" -- rtemplate
local flow_consts = require "flow_consts"

-- The same base id of the ntop_flow.h file
local ntop_base_id = 57472

-- Keep in sync with the defines in ntop_flow.h,
-- otherwise it could happen that some fields are not mapped
local flow_label_id = {
    [tostring(ntop_base_id + 524)] = 'COMMUNITY_ID'
}

-- #######################

function getFlowLabelFromId(id)
    local label = flow_label_id[tostring(id)]

    if label == nil then
        label = id
    end

    return label
end

-- #######################

function getFlowKey(name)
    if tonumber(name) then
        name = getFlowLabelFromId(name)
    end

    local s = flow_consts.flow_fields_description[name]

    if (s == nil) then
        -- Try to decode the name as <PEN>.<FIELD>
        -- then try to look up the name or directly the field
        -- in the rtemplate (pen is ignored).
        -- TODO: currently rtemplate is flat and PENs are ignored, we should add PEN there

        local pen, field = name:match("^(%d+)%.(%d+)$")

        local v = (rtemplate[tonumber(name)] or rtemplate[tonumber(field)])
        if (v == nil) then
            return (name)
        end

        s = flow_consts.flow_fields_description[v]
    end

    if (s ~= nil) then
        s = string.gsub(s, "<", "&lt;")
        s = string.gsub(s, ">", "&gt;")
        return (s)
    else
        return (name)
    end
end
