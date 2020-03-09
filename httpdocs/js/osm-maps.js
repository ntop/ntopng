$(document).ready(function () {

    const default_coords = [41.9, 12.4833333];
    const zoom_level = 4;

    // initialize alert api
    $('#geomap-alert').alert();

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

        show_positions({
            coords: {
                latitude: 0,
                longitude: 0
            }
        });

        if (errors.code == 2) {
            /* Do not even report the info/error to the user, this is
             * not relevant as the map functionality is not impacted */
        } else if (errors.code != 1)
            display_localized_error(error_code);
    }

    const init_map = () => {

        const timeout_val = 10 * 1000 * 1000;

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(show_positions, display_errors, { enableHighAccuracy: true, timeout: timeout_val, maximumAge: 0 });
        }
    }

    const draw_markers = (json, map_markers, map) => {

        const { center, objects } = json;
        const hosts = objects.map((h) => {
            return {
                lat: h.host[0].lat,
                lng: h.host[0].lng,
                html: h.host[0].html,
                ip_address: h.host[0].name
            }
        });

        hosts.forEach(h => {
            const marker = L.marker([h.lat, h.lng], { title: h.ip_address }).bindPopup(`
            <div class='infowin'>
              <a href='/lua/host_details.lua?host=${h.ip_address}'>${h.ip_address}</a>
              <hr>
              ${h.html}
            </div>
          `);
            map_markers.addLayer(marker);
        });

        map.addLayer(map_markers);
    }

    const show_positions = (current_user_position) => {

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

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
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
