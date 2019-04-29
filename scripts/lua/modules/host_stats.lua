--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local matrix = interface.getArpStatsMatrixInfo()


--[[   
    per le serie temporali? che dati tengo? e come?
    potrei anche "temporizzare" tutte le info sopra descritte cambiando l'ID (es <ip + timestamp> ),
    ma occuperebbero MOLTO spazio

    --però così una marea di info sono "duplicate" :( non posso mettere puntatori qua in lua; farla in C++?
______________________________________________
    Struttura elemento tabella:
    
    > hostID (ip? mac?)
        > MAC/IP
        > tot talkers
        > tot pkts sent
        > tot pkts rvc
        > freq tot
            > tot req 
                > snt
                > snt freq
                > rcv
                > rvc freq
            > tot rep 
                > snt
                > snt freq
                > rcv
                > rvc freq
        > Talkers (list)
            > hostID
            > MAC
            > country
            > OS
            > device type
            > manufacturers
            > pkts
                > req 
                    > snt
                    > snt freq
                    > rcv
                    > rvc freq
                > rep 
                    > snt
                    > snt freq
                    > rcv
                    > rvc freq

____________________________________________


]]


-- le voci della tabella commentate sono legate alla dim temporale
-- si può facilmente modificare per creare stats solo per uno (o predeterminati) host
local function createStats(matrix)

    if not matrix then return nil end

    local t_res = {}
    local t_tmp = {}
    local macInfo = {}
    local hostInfo = {}
    

    for _, m_elem in pairs(matrix) do
        for i,stats in pairs(m_elem)do
            tmp = split(i,"-")
            src_ip = tmp[1]
            dst_ip = tmp[2]

            
            
            if  not t_res[src_ip] then      --l'elemento NON è in t_res? 

                --ho omesso allcune stats (OS, devType, manufacturer, country)
                --accessibili in tabella nella cella relativa al dst_ip

                t_tmp = {}
                table.insert(t_tmp, { 
                    ip = dst_ip,
                    mac = stats["dst_mac"],
                    pkts_snt = stats["src2dst.requests"] + stats["src2dst.replies"],
                    pkts_rcvd = stats["dst2src.requests"] + stats["dst2src.replies"]
                    
                --freq = ....

                })


                macInfo = interface.getMacInfo(src_mac)
                hostInfo = interface.getHotsInfo(src_ip)
                tprint(macInfo)
                tprint({aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = "_______________________________________-"})

                table.insert( t_res, {          --sì: nuovo elemento

                        ip = src_ip,
                        mac = stats["src_mac"],
                        value = v,
                        pkts_snt = stats["src2dst.requests"] + stats["src2dst.replies"],
                        pkts_rcvd = stats["dst2src.requests"] + stats["dst2src.replies"],
                        country = macInfo[""] ,
                        device_type = macInfo[""] ,
                        OS = macInfo[""] ,
                        manufacturers = macInfo[""] ,
                    --    freq_pkts_snt = 0,
                    --    freq_pkts_rcvd = 0,

                        talkers = t_tmp,
                    })

            else                        --no: aggiorno a basta


            end
            



            --come sopra ma per dst2src



        end
    end


    --now i can elaborate the ratio stats

    return t_res
end

