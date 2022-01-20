const red_marker = L.icon({
    iconUrl: `${http_prefix}/leaflet/images/marker-icon-red.png`,
    shadowUrl: '${http_prefix}/leaflet/images/marker-shadow.png',
    iconSize: [25, 41],
    popupAnchor: [1, -34],
    tooltipAnchor: [16, -28]
});

const info_key_names = {
    "score": i18n.score,
    "asname": i18n.as,
    "html": i18n.nation,
    "active_alerted_flows": i18n.alerted_flows,
    "num_blacklisted_flows": i18n.blacklisted_flows,
    "bytes.sent": i18n.traffic_sent,
    "bytes.rcvd": i18n.traffic_rcvd,
    "total_flows": i18n.flows,
};

const formatters = {
    "bytes.sent": NtopUtils.bytesToSize,
    "bytes.rcvd": NtopUtils.bytesToSize,
}

const default_coords = [41.9, 12.4833333];
const zoom_level = 4;
let addRefToHost = true;
let endpoint = http_prefix + "/lua/rest/v2/get/geo_map/hosts.lua?";
let baseEndpoint = "";

// initialize alert api
//$('#geomap-alert').alert();

const create_marker = (h) => {    
    h = JSON.parse(JSON.stringify(h));
    const settings = { title: h.name };
    if (h.isRoot) settings.icon = red_marker;

    const ip = h.ip
    const lat = h.lat;
    const lng = h.lng;
    const name = h.name;
    let name_ip = ip;
    let extra_info = '';
    
    h.ip = null;
    h.lat = null;
    h.lng = null;
    h.name = null;
    h.isRoot = null;

    // Formatting the extra info to print into the Geo Map
    for (const key in h) {
        if(formatters[key])
            h[key] = formatters[key](h[key])

        if(h[key] && info_key_names[key])
            extra_info = extra_info + info_key_names[key] + ": <b>" + h[key] + "</b></br>";
    }

    if(h["flow_status"]) {
        let flow_status = i18n.flow_status + ":</br>";
        for (const prop in h["flow_status"]) {
            flow_status = flow_status + "<b>" + h["flow_status"][prop]["num_flows"] + " Flows, " + h["flow_status"][prop]["label"] + "</b></br>";
        }
        extra_info = extra_info + flow_status;
    }

    if(name)
        name_ip = name + "</br>" + name_ip;

    const marker = `<div class='infowin'>
                        <a href='${http_prefix}/lua/host_details.lua?host=${ip}'>${name_ip}</a>
                        <hr>
                        ${extra_info}
                    </div>`

    return L.marker(L.latLng(lat, lng), settings).bindPopup(marker);
}

// return true if the status code is different from 200
const check_status_code = (status_code, status_text, $error_label) => {

    const is_different = (status_code != 200);

    if (is_different && $error_label != null) {
        $error_label.find('p').text(`${i18n.request_failed_message}: ${status_code} - ${status_text}`).show();
    }
    else if (is_different && $error_label == null) {
        alert(`${i18n.request_failed_message}: ${status_code} - ${status_text}`);
    }

    return is_different;
}

const display_errors = (errors) => {
    const error_messages = {
        1: 'Permission denied',
        2: 'Position unavailable',
        3: 'Request timeout'
    };
    const error_code = error_messages[errors.code];

    show_positions({ coords: { latitude: 0, longitude: 0 }});

    if (errors.code != 1) {
        display_localized_error(error_code);
    }
}

const init_map = (newEndpoint = null, _baseEndpoint = null) => {
    endpoint = newEndpoint || endpoint;
    baseEndpoint = _baseEndpoint;

    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(show_positions, display_errors,
						 {
						     enableHighAccuracy: true,
						     timeout: 10000,
						     maximumAge: 0
						 }
						);
    }
}

const draw_markers = (hosts, map_markers, map) => {
    hosts.forEach(h => {
        map_markers.addLayer(
            create_marker(h)
        );

        // make a transitions to the root host
        if (h.isRoot) {
            map.flyTo([h.lat, h.lng], zoom_level);
        }
    });
    map.addLayer(map_markers);
}

let hosts = null;
let map = null;
let markers = null;

const redraw_hosts = (show_only_alert_hosts, redo_query = false, extra_endpoint_params = null) => {
    if (markers == null || map == null || hosts == null) {
	console.error("map isn't initialized!");
	return;
    }
    markers.clearLayers();

    if(redo_query == true) {
        $.get(`${baseEndpoint}?${extra_endpoint_params}&ifid=${interfaceID}&${zoomIP || ''}`)
            .then((data) => {
                        hosts = data.rsp;
                draw_markers(data.rsp, markers, map);
            })
            .fail(({ status, statusText }) => {
                NtopUtils.check_status_code(status, statusText, $("#geomap-alert"));
            });
    } else {
        //map.removeLayer(markers);
        let temp_hosts = hosts.filter((h) => h.isAlert == true || !show_only_alert_hosts);
        draw_markers(temp_hosts, markers, map);
    }
}

const show_positions = (current_user_position) => {
    // these are two map providers provided by: https://leaflet-extras.github.io/leaflet-providers/preview/
    const layers = {
        light: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        // dark: "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png"
    };
    // select the right layer
    const layer = layers.light;
    const user_coords = [current_user_position.coords.latitude, current_user_position.coords.longitude];

    if (user_coords[0] == 0 && user_coords[1] == 0) {
        /* Do not even report the info/error to the user, this is
         * not relevant as the map functionality is not impacted */
        //display_localized_no_geolocation_msg();
        console.log("Geolocation unavailable, using default location");

        user_coords[0] = default_coords[0], user_coords[1] = default_coords[1];
    }
    //document.getElementById('map-canvas').innerHTML = "<div id='map' style='width: 100%; height: 100%;'></div>";
    const hosts_map = L.map('map-canvas').setView(user_coords || default_coords, zoom_level);
    map = hosts_map;
    const map_markers = L.markerClusterGroup({
        maxClusterRadius: 100,
        spiderLegPolylineOptions: {
            opacity: 0
        }
    });
    markers = map_markers;
    map = hosts_map;

    L.tileLayer(layer, {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(hosts_map);

    if (hosts != null) {
        draw_markers(hosts, map_markers, hosts_map);
	return;
    }

    $.get(`${endpoint}&ifid=${interfaceID}&${zoomIP || ''}`)
        .then((data) => {
	    hosts = data.rsp;
            draw_markers(data.rsp, map_markers, hosts_map);
        })
        .fail(({ status, statusText }) => {
            NtopUtils.check_status_code(status, statusText, $("#geomap-alert"));
        });

}

//init_map();
