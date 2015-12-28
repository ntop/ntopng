/*
 *
 * (C) 2013-15 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* **************************************************** */

SimulatorInterface::SimulatorInterface(const char *sim_conf)
: ParserInterface(sim_conf) {
    char *tmp;

    if (strncmp(sim_conf, "simulator:", 10))
        ntop->getTrace()->traceEvent(TRACE_ERROR,
            "Simulator interface called without configuration string: %s", sim_conf);
    if ((tmp = strdup(sim_conf)) == NULL)
        throw ("Out of memory");

    num_flows_per_second = atoi(&tmp[10]);
    avg_flow_interarrival_usecs = (u_long)(1. / num_flows_per_second * 1e6);

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Simulating %i flows per second", num_flows_per_second);

    /* Reset data */
    memset(&flow_template, 0, sizeof (flow_template));
    flow_template.pkt_sampling_rate = 1; /* 1:1 (no sampling) */
    flow_template.vlan_id = 0;

    srand(0);  // 0, always the same seed
    if (tmp) free(tmp);
}

u_int8_t SimulatorInterface::template_randomize_src_dst_mac() {
    sscanf("DE:AD:BE:EF:DE:AD", "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx",
            &flow_template.src_mac[0], &flow_template.src_mac[1],
            &flow_template.src_mac[2], &flow_template.src_mac[3],
            &flow_template.src_mac[4], &flow_template.src_mac[5]);
    memcpy(&flow_template.dst_ip, &flow_template.src_mac, sizeof (flow_template.src_mac));
    return 0;
}

u_int8_t SimulatorInterface::template_randomize_src_dst_ip() {
    char src_ip[16], dst_ip[16];
    snprintf(src_ip, 16, "192.168.1.%hu", (u_short)(rand() % 256));
    snprintf(dst_ip, 16, "192.168.1.%hu", (u_short)(rand() % 256)); 

    //    snprintf(src_ip, 16, "192.168.1.1");
    //    snprintf(dst_ip, 16, "192.168.1.2"); 
    flow_template.src_ip.set_from_string(src_ip);
    flow_template.dst_ip.set_from_string(dst_ip);
    return 0;
}

u_int8_t SimulatorInterface::template_randomize_first_last_switched(){
    flow_template.first_switched = time(NULL) - (rand() % 3600);
    flow_template.last_switched = time(NULL);
    return 0;
}

u_int8_t SimulatorInterface::template_randomize(){
    template_randomize_src_dst_mac();
    template_randomize_first_last_switched();
    template_randomize_src_dst_ip();    
    flow_template.src_port = rand() % 65536;
    flow_template.dst_port = rand() % 65536;
    flow_template.in_bytes = rand() % (1024 * 1024);
    flow_template.in_pkts = rand() % 1024;
    flow_template.out_bytes = rand() % (1024 * 1024);
    flow_template.out_pkts = rand() % 1024;
    flow_template.l4_proto = rand() % 256;
    return 0;
}

static void* packetPollLoop(void* ptr) {
    SimulatorInterface *iface = (SimulatorInterface*) ptr;

    /* Wait until the initialization completes */
    while (!iface->isRunning()) sleep(1);

    iface->simulate_flows();
    return (NULL);
}

void SimulatorInterface::simulate_flows() {

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Simulating flows on %s", ifname);

    while (isRunning()) {
        while (idle()) {
            purgeIdle(time(NULL));
            sleep(1);
            if (ntop->getGlobals()->isShutdown()) return;
        }
        for (u_int i = 0; i < num_flows_per_second; i++){
            process_simulated_flow();
            _usleep(avg_flow_interarrival_usecs);
        }
    }

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flow collection is over.");
}

/* **************************************************** */

u_int8_t SimulatorInterface::process_simulated_flow() {
    template_randomize();
    flow_processing(&flow_template);
    return 0;
}

/* **************************************************** */

void SimulatorInterface::startPacketPolling() {
    pthread_create(&pollLoop, NULL, packetPollLoop, (void*) this);
    pollLoopCreated = true;
    NetworkInterface::startPacketPolling();
}

/* **************************************************** */

void SimulatorInterface::shutdown() {
    void *res;

    if (running) {
        NetworkInterface::shutdown();
        pthread_join(pollLoop, &res);
    }
}
