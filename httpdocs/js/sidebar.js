const fix_submenu_height = ($submenu, $hover_button) => {

    const document_height = $(document).height();
    const submenu_height = $submenu.height();
    const delta_y = $hover_button.offset().top;
    const submenu_parent_height = $submenu.parent().outerHeight();

    const min_height = 128;

    if (delta_y + submenu_height > document_height) {

        let max_height = document_height - delta_y - 32;
        $submenu.css('overflow-y', 'auto');

        if (max_height <= min_height) {
            $submenu.css({'top': `-${submenu_height - submenu_parent_height}px`});
            return;
        }
      
        $submenu.css({'max-height': `${max_height}px`});
    }

};

$(document).ready(function () {
    

    const is_mobile_device = () => {
        return window.matchMedia('(min-width: 320px) and (max-width: 480px) ').matches;
    }
    
    if (is_mobile_device()) {
        $(`div[id$='submenu']`).removeClass('side-collapse');
    }

    $(`#n-sidebar a.submenu`).mouseenter(function() {

        const $submenu = $(this).parent().find(`div[id$='submenu']`);
        $submenu.collapse('show');
        fix_submenu_height($submenu, $(this));
        $(this).attr('aria-expanded', true);

    });
    $(`div[id$='submenu']`).mouseenter(function() {
        $(this).addClass('show');
    });
    $(`div[id$='submenu']`).mouseleave(function() {
        $(this).removeClass('show').css('max-height', 'initial').css('top', '0');
    });
   
    $(`#n-sidebar a.submenu`).mouseleave(function() {
        const $submenu = $(this).parent().find(`div[id$='submenu']`);
        $submenu.removeClass('show').css('max-height', 'initial').css('top', '0');
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
