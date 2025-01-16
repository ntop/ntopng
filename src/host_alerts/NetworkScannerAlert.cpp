#include "host_alerts_includes.h"

NetworkScannerAlert::NetworkScannerAlert(HostCheck* c, Host* h, risk_percentage cli_pctg,
                             u_int16_t _num_flows_tokens, u_int64_t _threshold,
                             bool _is_attacker)
    : FlowHitsAlert(c, h, cli_pctg,_num_flows_tokens, _threshold, _is_attacker) {
  num_flows_tokens = _num_flows_tokens;
  threshold = _threshold;
};

ndpi_serializer* NetworkScannerAlert::getAlertJSON(ndpi_serializer* serializer) {
    if (serializer == NULL) return NULL;
    ndpi_serialize_string_uint32(serializer, "num_flows_tokens", (u_int32_t)num_flows_tokens);
    ndpi_serialize_string_uint64(serializer, "threshold", threshold);
    return serializer;
}