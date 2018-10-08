--
-- (C) 2018 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('Application/json')


--------------------------------------------------------------------------
---------------------------------------------------------------------------
local ga_module = {}

local request = {}
local response = {}

--"suggestions_strings" must be a string array, and "card" must be created with create_card()
local function fill_response(speech_text, display_text, expect_response, suggestions_strings, card)  

  if display_text == nil or display_text == "" then display_text = speech_text end
  if expect_response == nil then expect_response = true end

  local mysuggestions = {}--MAX 10 (imposed by google)

  if suggestions_strings then 
    for i = 1, #suggestions_strings do
      table.insert( mysuggestions, {title = suggestions_strings[i]} )
    end
  end

  local myitems = {}

  if card then
    --tprint(card)
    myitems =  {
      { 
        simpleResponse = {
          textToSpeech = speech_text,
          displayText = display_text 
        } 
      },
      {basicCard = card}
    }  
  else
    myitems[1] =  {
      simpleResponse = {
        textToSpeech = speech_text,
        displayText = display_text,
      }
    } 
  end
  
  local r = {}
  --if a context was created, consume it
  local mycontext = ga_module.getContext()
  if mycontext then 

    r = {
      fulfillmentText = display_text,
      payload = {
        google = {
          expectUserResponse = expect_response,
          richResponse = {
            items = myitems,
            suggestions = mysuggestions
          }
        } 
      },
      outputContexts = mycontext
    }

    ga_module.deleteContext()
  else
    r = {
      fulfillmentText = display_text,
      payload = {
        google = {
          expectUserResponse = expect_response,
          richResponse = {
            items = myitems,
            suggestions = mysuggestions
          }
        } 
      }
    }

  end

  return json.encode(r)
end


--TODO: cards allow many things (like buttons), more info ---> [ https://dialogflow.com/docs/rich-messages#card ]
function ga_module.create_card(card_title, card_url_image, accessibility_image_text, button_title, button_open_url_action  )

  local myButton = {}
  myButton = { 
    {
      title = button_title,
      openUrlAction = { url = button_open_url_action}
     } 
  }

  local myCard = {}
  myCard = {
    title = card_title,
    image = { url = card_url_image, accessibilityText = accessibility_image_text },
    buttons = myButton
  }

  return myCard
end

--To set an arbitrary context (and overwrite the old one) call setContext()
--To cancel an existing/outgoing context ---> set the lifespan to 0
--For complex structures use as many prefs as there are fields to save
function ga_module.setContext(name, lifespan, parameter) --TODO: support for more parameters

  if name then 
    ntop.setCache("context_name", name, 60 * 20) --(max context lifespan: 20 min)
  end
  if lifespan then 
    ntop.setCache("context_lifespan", tostring(lifespan), 60 * 20)
  end
  if parameter then 
    ntop.setCache("context_param", parameter, 60*20)
  end
end


function ga_module.deleteContext()
  ntop.delCache("context_name")
  ntop.delCache("context_lifespan")
  ntop.delCache("context_param")
end


function ga_module.getContext()

  local name = ntop.getCache("context_name")
  if name == "" then return nil end
  
  local lifespan = ntop.getCache("context_lifespan")

  if lifespan == "" then lifespan = 2 end

  local mycontext = {
    {
      name = name,
      lifespanCount = lifespan,
      parameters = {param = ntop.getCache("context_param") }
    }
  }

  return mycontext
end

function ga_module.send(speech_text, display_text, expect_response, suggestions_strings, card )

  res = fill_response(speech_text, display_text,expect_response, suggestions_strings, card)
  print(res.."\n")

  io.write("\n")
  io.write("NTOPNG RESPONSE\n")
  tprint(res)
  io.write("\n---------------------------------------------------------\n")

end


function ga_module.receive()

  local info, pos, err = json.decode(_POST["payload"], 1, nil)--I assume only ONE outputContext
  
  response["responseId"] = info.responseId
  response["queryText"] = info.queryResult.queryText
  if info.queryResult.parameters ~= nil then response["parameters"] = info.queryResult.parameters end
  if info.queryResult.outputContexts and info.queryResult.outputContexts[1].name then response["context"] = info.queryResult.outputContexts[1].name end
  ---response["outputContext_name"] = info.queryResult.outputContexts[1].name  
  --response["outputContext_parameters"] = info.queryResult.outputContexts[1].parameters.number
  response["intent_name"] = info.queryResult.intent.displayName
  response["session"] = info.session

  ntop.setCache("session_id", info.session )

  io.write("\n")
  io.write("DIALOGFLOW REQUEST")
  tprint(response)
  io.write("\n")

  return response
end

return ga_module
