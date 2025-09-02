--
-- (C) 2013-25 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
local flow_data = require "flow_data"
local format_utils = require "format_utils"
local flow_data_preset = require "flow_data_preset"
local flow_pie = {}
local values_table = {}

-- ##########################################

local function update_section(sections, section_ref, value)
    local index = values_table[section_ref].index
    local previous_value = values_table[section_ref].value
    local new_value = previous_value + value
    sections[index].label = section_ref .. " (" ..  new_value .. ")"
    sections[index].value = new_value
end

-- ##########################################

local function create_section(sections, section_ref, value)
    local index = #sections + 1
    sections[index] = {
        label = section_ref .. " (" ..  value .. ")",
        value = value,
        url = '#'
    }
    values_table[section_ref] = {
        index = index,
        value = value
    }
end


-- ##########################################

local function format_table(sections, query, table, max_sections)
    local remote_asn = {}
    local others = {
        label = i18n("others"),
        value = 0 
    }
    if query.only_costumers == true then
        local as_utils = require "as_utils"
        remote_asn = as_utils.getRemoteASNs()
    end
    for _, value in pairs(table or {}) do
        local section_ref = value[query.section_ref]
        local value_ref = tonumber(value[query.value_ref])
        if query.only_costumers == nil or query.only_costumers == false or
            (query.only_costumers == true and remote_asn[section_ref] ~= nil) then
            if values_table[section_ref] ~= nil then
                update_section(sections, section_ref, value_ref)
            elseif #sections <= max_sections then
                create_section(sections, section_ref, value_ref)
            else
                others.value = others.value + value_ref
            end
        end
    end
    if others.value > 0 then
        if values_table["others"] ~= nil then
            update_section(sections, "others", others.value)
        else
            create_section(sections, "others", others.value)
        end
    end
end

-- ##########################################

-- @brief Given a list of queries to be run, it will generate a pie
-- @param queries Queries to run
-- @return
function flow_pie.generatePie(queries, max_sections)

    local sections = {}

    for _, query in pairs(queries) do
        local table_stats = flow_data.getStats({query})
        format_table(sections, query, table_stats, max_sections)
    end
    return sections
end

-- ##########################################

return flow_pie
