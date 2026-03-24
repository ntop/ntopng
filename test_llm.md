# local llm
curl -u admin:admin1 -H "Content-Type: application/json"   -d '{"provider":"local","prompt":"What is ntopng?"}'   http://localhost:3000/lua/pro/post/llm/completion.lua

{"rc":0,"rc_str_hr":"Success","rc_str":"OK","rsp":{"reply":{"provider":"openai","prompt":"What is ntopng?"}}}