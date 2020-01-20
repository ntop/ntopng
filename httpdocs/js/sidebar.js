$(document).ready(function() {

    let is_collapsed = !$('#n-sidebar').hasClass('active');
    let has_open_collapsed = false;

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
        
        $("#n-container, #n-navbar").toggleClass("extended");
        $("#n-sidebar, #ntop-logo").toggleClass("active");

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

        // disable overflow when the sidebar is open in mobile device
        if (is_mobile_device()) {
            $('html,body').toggleClass('no-scroll');
        }
    
        // collapse submenu if there is one open
        if ($(`div[id$='-submenu'].show`).length > 0 && sidebar_collapsed) {
            $(`div[id$='-submenu'].show`).collapse('hide');
        }

        toggle_logo_animation();
        
    });
    
    $("#n-sidebar a[data-toggle='collapse']").click(function() {

        if (is_mobile_device())  return;

        if (is_collapsed && !has_open_collapsed) {
            $("#n-container, #n-navbar").toggleClass("extended");
            $("#n-sidebar, #ntop-logo").toggleClass("active");
            has_open_collapsed = true;
            return;
        }

        if (has_open_collapsed) {
            $("#n-container, #n-navbar").toggleClass("extended");
            $("#n-sidebar, #ntop-logo").toggleClass("active");
            has_open_collapsed = false;
        }
       
    });
    
});

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
