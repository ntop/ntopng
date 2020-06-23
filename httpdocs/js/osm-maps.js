$(document).ready(function () {

    const red_marker = L.icon({
        iconUrl: `${http_prefix}/leaflet/images/marker-icon-red.png`,
        shadowUrl: '${http_prefix}/leaflet/images/marker-shadow.png',
    });

    const default_coords = [41.9, 12.4833333];
    const zoom_level = 4;

    // initialize alert api
    $('#geomap-alert').alert();

    const create_marker = (title, lat, lng, html, is_red = false) => {

        const settings = { title: title };
        if (is_red) settings.icon = red_marker;

        return L.marker([lat, lng], settings).bindPopup(`
            <div class='infowin'>
                <a href='/lua/host_details.lua?host=${title}'>${title}</a>
                <hr>
                ${html}
            </div>
        `);
    }

    // return true if the status code is different from 200
    const check_status_code = (status_code, status_text, $error_label) => {

        const is_different = status_code != 200;

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

        if (errors.code == 2) {
            /* Do not even report the info/error to the user, this is
             * not relevant as the map functionality is not impacted */
        } else if (errors.code != 1)
            display_localized_error(error_code);
    }

    const init_map = () => {

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

    const draw_markers = (json, map_markers, map) => {

        const { hosts, flows } = json;

        // if there are no hosts then draw flows
        if (hosts.length == 0) {
            draw_flows(flows, map_markers, map);
            return;
        }

        hosts.forEach(h => {
            map_markers.addLayer(create_marker(h.name, h.lat, h.lng, h.html));
        });

        map.addLayer(map_markers);
    }

    const draw_flows = (flows, map_markers, map) => {

        // if there aren't any flows then don't draw them
        if (flows.length == 0) return;

        const client = flows[0].client;
        const servers_flow = flows.map((flow) => flow.server);
        const servers = [... new Set(servers_flow)];

        // draw only drawable server markers
        servers.filter(s => s.isDrawable).forEach(s => {

            // if the current server is the root then center the map to him
            if (s.isRoot) {
                map.flyTo([s.lat, s.lng], zoom_level);
            }

            map_markers.addLayer(create_marker(s.name, s.lat, s.lng, s.html, s.isRoot));
        });

        // draw client marker
        if (client.isDrawable) {
            map_markers.addLayer(create_marker(client.name, client.lat, client.lng, client.html));
        }

        map.addLayer(map_markers);
    }

    const show_positions = (current_user_position) => {

        // these are two map providers provided by: https://leaflet-extras.github.io/leaflet-providers/preview/
        const layers = {
            light: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            dark: "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png"
        };
        // select the right layer
        const layer = ($("body").hasClass("dark")) ? layers.dark : layers.light;
        const user_coords = [current_user_position.coords.latitude, current_user_position.coords.longitude];

        if (user_coords[0] == 0 && user_coords[1] == 0) {
            /* Do not even report the info/error to the user, this is
             * not relevant as the map functionality is not impacted */
            //display_localized_no_geolocation_msg();
            console.log("Geolocation unavailable, using default location");

            user_coords[0] = default_coords[0], user_coords[1] = default_coords[1];
        }

        const hosts_map = L.map('map-canvas').setView(user_coords || default_coords, zoom_level);
        const map_markers = L.markerClusterGroup();

        display_localized_position(user_coords || default_coords);

        L.tileLayer(layer, {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(hosts_map);

        $.get(`${http_prefix}/lua/get_geo_hosts.lua?${zoomIP || ''}`).then((data) => {
            draw_markers(data, map_markers, hosts_map);
        })
        .fail(({ status, statusText }) => {
            check_status_code(status, statusText, $("#geomap-alert"));
        });

    }

    init_map();

});
