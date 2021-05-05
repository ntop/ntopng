$(function () {

    const red_marker = L.icon({
        iconUrl: `${http_prefix}/leaflet/images/marker-icon-red.png`,
        shadowUrl: '${http_prefix}/leaflet/images/marker-shadow.png',
        iconSize: [25, 41],
        popupAnchor: [1, -34],
        tooltipAnchor: [16, -28]
    });

    const default_coords = [41.9, 12.4833333];
    const zoom_level = 4;

    // initialize alert api
    $('#geomap-alert').alert();

    const create_marker = (title, lat, lng, html, is_red = false) => {

        const settings = { title: title };
        if (is_red) settings.icon = red_marker;

        return L.marker(L.latLng(lat, lng), settings).bindPopup(`
            <div class='infowin'>
                <a href='${http_prefix}/lua/host_details.lua?host=${title}'>${title}</a>
                <hr>
                ${html}
            </div>
        `);
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

    const draw_markers = (hosts, map_markers, map) => {

        hosts.forEach(h => {

            map_markers.addLayer(
                create_marker(h.name, h.lat, h.lng, h.html, h.isRoot)
            );

            // make a transitions to the root host
            if (h.isRoot) {
                map.flyTo([h.lat, h.lng], zoom_level);
            }
        });

        map.addLayer(map_markers);
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

        const hosts_map = L.map('map-canvas').setView(user_coords || default_coords, zoom_level);
        const map_markers = L.markerClusterGroup({
            maxClusterRadius: 100,
            spiderLegPolylineOptions: {
                opacity: 0
            }
        });

        L.tileLayer(layer, {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(hosts_map);

        $.get(`${http_prefix}/lua/get_geo_hosts.lua?${zoomIP || ''}`)
        .then((data) => {
            draw_markers(data, map_markers, hosts_map);
        })
        .fail(({ status, statusText }) => {
            NtopUtils.check_status_code(status, statusText, $("#geomap-alert"));
        });

    }

    init_map();

});
