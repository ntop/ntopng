const fix_submenu_height = ($submenu, $hover_button) => {

    const document_height = $(document).height();
    const submenu_height = $submenu.height();
    const delta_y = $hover_button.offset().top;
    
    if (delta_y + submenu_height > document_height) {
        $submenu.css('overflow-y', 'auto');
        $submenu.css({'max-height': `${document_height - delta_y}px`});
    }

};

$(document).ready(function () {
    

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

    if (is_mobile_device()) {
        $(`div[id$='submenu']`).removeClass('side-collapse');
    }

    highlighit_current_page();

    // toggle button collapse visibility
    $('#collapse-sidebar').on('click', function () {
        //const self = $(this);
        //hide_collapse_text(self);
    });

    $("[data-toggle='sidebar']").click(function () {

        // toggle_sidebar_and_container();

        // // disable overflow when the sidebar is open in mobile device
        // if (is_mobile_device()) {
        //     $('html,body').toggleClass('no-scroll');
        //     return;
        // }

        // const sidebar_collapsed = !$('#n-sidebar').hasClass('active');
        // is_collapsed = sidebar_collapsed;

        // if (!is_mobile_device()) {
        //     $.ajax({
        //         data: {
        //             'sidebar_collapsed': sidebar_collapsed ? "1" : "0"
        //         },
        //         type: 'get',
        //         url: `${http_prefix}/lua/sidebar-handler.lua`
        //     });
        // }

        // if (latest_submenu_open.length > 0 && !sidebar_collapsed) {
        //     latest_submenu_open.collapse('show');
        // }

        // // collapse submenu if there is one open
        // if ($(`div[id$='-submenu'].show`).length > 0 && sidebar_collapsed) {
        //     $(`div[id$='-submenu'].show`).collapse('hide');
        // }

        // toggle_logo_animation();

    });

    $(`#n-sidebar a.submenu`).mouseenter(function() {

        const $submenu = $(this).parent().find(`div[id$='submenu']`);
        $submenu.collapse('show').css('max-height', 'auto');
        fix_submenu_height($submenu, $(this));

        $(this).attr('aria-expanded', true);

    });
    $(`div[id$='submenu']`).mouseenter(function() {
        $(this).addClass('show');
    });
    $(`div[id$='submenu']`).mouseleave(function() {
        $(this).removeClass('show');
    });
    $(`#n-sidebar a.submenu`).mouseleave(function() {
        const $submenu = $(this).parent().find(`div[id$='submenu']`);
        $submenu.removeClass('show').css('max-height', 'auto');
        $(this).attr('aria-expanded', false);
    });

});

$(window).resize(function() {

    // re-calc submenu height
    const $current_submenu = $('#n-sidebar').find(`div.show[id$='submenu']`);

    if ($current_submenu.length > 0) {

        const $hover_button = $current_submenu.parent().find(`a[data-toggle='collapse']`);
        fix_submenu_height($current_submenu, $hover_button);
    }

});
