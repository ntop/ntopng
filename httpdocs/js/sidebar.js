$(document).ready(function() {

    let is_collapsed = !$('#n-sidebar').hasClass('active');
    let latest_submenu_open = $(`div[id$='-submenu'].show`);

    highlighit_current_page();

    // toggle button collapse visibility
    $('#collapse-sidebar').on('click', function() {
        // hide span
        $(this).fadeOut(250, function(e) {
            
            $(this).toggleClass('active');
            
            if (!$('#n-sidebar').hasClass('active')) {
                $(this).find('span').text('').hide();
            }
            else {
                $(this).find('span').text('Collapse').show();
            }
            
            $(this).fadeIn(250);
        });
    });
 
    $("[data-toggle='sidebar']").click(function(){
        
        toggle_sidebar_and_container();

        // disable overflow when the sidebar is open in mobile device
        if (is_mobile_device()) {
            $('html,body').toggleClass('no-scroll');
            return;
        }

        const sidebar_collapsed = !$('#n-sidebar').hasClass('active');
        is_collapsed = sidebar_collapsed;
     
        //$.post(`${http_prefix}/lua/sidebar-handler.lua`, sidebar_collapsed);

        $.ajax({
            data: {
                'sidebar_collapsed': sidebar_collapsed ? "1" : "0"
            },
            type: 'get',
            url: `${http_prefix}/lua/sidebar-handler.lua`
        });

        if (latest_submenu_open.length > 0 && !sidebar_collapsed) {
            latest_submenu_open.collapse('show');
        }

        // collapse submenu if there is one open
        if ($(`div[id$='-submenu'].show`).length > 0 && sidebar_collapsed) {
            $(`div[id$='-submenu'].show`).collapse('hide');
        }

        toggle_logo_animation();
        
    });
    
    $("#n-sidebar a[data-toggle='collapse']").click(function() {

        if (is_mobile_device())  return;

        if (is_collapsed && !$('#n-sidebar').hasClass('active')) {
            toggle_sidebar_and_container();
            toggle_logo_animation();
        }
    });
    
});

const toggle_sidebar_and_container = () => {
    $("#n-container, #n-navbar").toggleClass("extended");
    $("#n-sidebar, #ntop-logo").toggleClass("active");
}

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
    // get 'root' page from localStorage
    const root_link = localStorage.getItem('root_subpage') || 'index.lua';

    if ($link.length <= 0) {
        // highlight the last link
        $(`#n-sidebar li a[href*='${root_link}']`).addClass('active');
        return;
    }

    // a link was found, I save it inmside the local storage for future purposes
    localStorage.removeItem('root_subpage');
    localStorage.setItem('root_subpage', current_subpage_open);
    // active the link
    $link.addClass('active');
    
}

