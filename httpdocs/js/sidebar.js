$(document).ready(function () {
    
    let is_collapsed = !$('#n-sidebar').hasClass('active');
    let latest_submenu_open = $(`div[id$='-submenu'].show`);

    const toggle_logo_animation = () => {
    
        const ntop_logo = {
            'n': $('#ntop-logo-n'),
            't': $('#ntop-logo-t'),
            'o': $('#ntop-logo-o'),
            'p': $('#ntop-logo-p'),
        };
    
        const fade_delay = 100;
    
        if (!$('#n-sidebar').hasClass('active')) {
            ntop_logo.p.fadeOut(fade_delay, () => ntop_logo.o.fadeOut(fade_delay, () => ntop_logo.t.fadeOut(fade_delay)));
        }
        else {
            ntop_logo.t.fadeIn(fade_delay, () => ntop_logo.o.fadeIn(fade_delay, () => ntop_logo.p.fadeIn(fade_delay)));
        }
    }
    
    const is_mobile_device = () => {
        return window.matchMedia('(min-width: 320px) and (max-width: 480px) ').matches;
    }
    
    const highlighit_current_page = () => {
    
        // get current page name
        const current_subpage_open = location.pathname.match(/[a-zA-Z0-9\s_\\.\-\(\):]+\.lua/g);
        // check if there is an element with that file name
        const $link = $(`#n-sidebar li a[href*='${current_subpage_open}']`);
    
        // a link was found, I save it inside the local storage for future purposes
        localStorage.removeItem('root_subpage');
        localStorage.setItem('root_subpage', current_subpage_open);
        // active the link
        $link.addClass('active');
    
    }

    const is_sidebar_collapsed = () => !$('#n-sidebar').hasClass('active');

    const hide_collapse_text = (text_container) => {

        // hide span
        if (!is_sidebar_collapsed()) {
            text_container.find('span').fadeOut(250);
            return;
        }

        text_container.find('span').fadeIn(250);
    }

    const toggle_sidebar_and_container = () => {
        $("#n-container, #n-navbar").toggleClass("extended");
        $("#n-sidebar, #ntop-logo").toggleClass("active");
    }

    highlighit_current_page();

    // toggle button collapse visibility
    $('#collapse-sidebar').on('click', function () {
        const self = $(this);
        hide_collapse_text(self);
    });

    $("[data-toggle='sidebar']").click(function () {

        toggle_sidebar_and_container();

        // disable overflow when the sidebar is open in mobile device
        if (is_mobile_device()) {
            $('html,body').toggleClass('no-scroll');
            return;
        }

        const sidebar_collapsed = !$('#n-sidebar').hasClass('active');
        is_collapsed = sidebar_collapsed;

        if (!is_mobile_device()) {
            $.ajax({
                data: {
                    'sidebar_collapsed': sidebar_collapsed ? "1" : "0"
                },
                type: 'get',
                url: `${http_prefix}/lua/sidebar-handler.lua`
            });
        }

        if (latest_submenu_open.length > 0 && !sidebar_collapsed) {
            latest_submenu_open.collapse('show');
        }

        // collapse submenu if there is one open
        if ($(`div[id$='-submenu'].show`).length > 0 && sidebar_collapsed) {
            $(`div[id$='-submenu'].show`).collapse('hide');
        }

        toggle_logo_animation();

    });

    $("#n-sidebar a[data-toggle='collapse']").click(function (e) {

        if (is_mobile_device()) return;

        if (is_sidebar_collapsed()) {
            hide_collapse_text($('#collapse-sidebar'));
            toggle_sidebar_and_container();
            toggle_logo_animation();
        }

    });
});
