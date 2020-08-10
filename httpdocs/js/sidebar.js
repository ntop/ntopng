const fixSubMenuPosition = ($submenu, $hoverButton) => {

    const MIN_SPACE = 32;
    const MIN_HEIGHT = 128;

    const distFromAbove = $hoverButton.offset().top;
    const submenuHeight = $submenu.height();
    const documentHeight = $(document).height();

    // set the submenu height
    $submenu.css('top', `${distFromAbove}px`);

    // if the submenu is too high to be shown then set
    // the overflow on y axis
    if (submenuHeight + distFromAbove >= documentHeight) {

        let maxSubmenuHeight = documentHeight - distFromAbove - MIN_SPACE;
        // clamp the maxSubmenuHeight if it's too small
        maxSubmenuHeight = (maxSubmenuHeight < MIN_HEIGHT) ? MIN_HEIGHT : maxSubmenuHeight;

        $submenu.css('overflow-y', 'auto');
        $submenu.css('max-height', `${maxSubmenuHeight}px`);
    }

};

$(document).ready(function () {

    const toggleSidebar = () => {
        // if the layer doesn't exists then create it
        if ($(`.sidebar-close-layer`).length == 0) {

            const $layer = $(`<div class='sidebar-close-layer' style='display:none'></div>`);
            // when the user clicks on the layer
            $layer.click(function(){
                // remove active class from sidebar
                $(`#n-sidebar`).removeClass('active');
                // hide the layer and remove it from the DOM
                $layer.fadeOut(function() {
                    $(this).remove();
                });
            });

            // append the layer to the wrapper
            $(`#wrapper`).append($layer);
            // show the layer inside the page
            $layer.fadeIn();
        }
        else {
            // hide the existing layer and destroy it
            $(`.sidebar-close-layer`).fadeOut(function() {
                $(this).remove();
            });
        }

        // show/hide the sidebar
        $(`#n-sidebar`).toggleClass('active');
    }

    $(`#n-sidebar a.submenu`).mouseenter(function() {

        const $submenu = $(this).parent().find(`div[id$='submenu']`);
        $submenu.collapse('show').css('top', '0').css('max-height', 'initial');
        fixSubMenuPosition($submenu, $(this));

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
        $submenu.removeClass('show');
        $(this).attr('aria-expanded', false);
    });

    /* toggle sidebar display */
    $(`button[data-toggle='sidebar']`).click(function() {
        toggleSidebar();
    });

    $(`#iface-select`).change(function() {

        const action = $(this).val();
        const $form = $(this).parents('form');

        $form.attr('action', action);

        if (!systemInterfaceEnabled) {
            toggleSystemInterface(true);
        }
        else {
            toggleSystemInterface(false, $form);
        }

    });

});

$(window).resize(function() {

    // re-calc submenu height
    const $currentSubmenu = $('#n-sidebar').find(`div.show[id$='submenu']`);

    if ($currentSubmenu.length > 0) {

        const $hoverButton = $currentSubmenu.parent().find(`a[data-toggle='collapse']`);
        fixSubMenuPosition($currentSubmenu, $hoverButton);
    }

});
