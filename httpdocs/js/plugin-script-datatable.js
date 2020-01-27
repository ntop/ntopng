const INDEX_SEARCH_COLUMN = 3;

$.fn.dataTable.ext.buttons.filterScripts = {
    className: "filter-scripts-button",
    init: function (dt, node, config) {
        // get button script type
        const button_id = config.attr.id;
        // remove styles pre-rendered
        $(node).removeClass("btn").removeClass("btn-secondary");
        // change text by scripts count
        const button_text = $(node).html();

        let count = 0;

        // count scripts inside table
        if (button_id == "all-scripts") {
            // count all scripts
            count = dt.data().length;
        }
        else if (button_id == "enabled-scripts") {
            dt.data().each(d => {

                // count all enabled scripts
                const parsed = d.is_enabled;
                if (parsed) count += 1;

            });
        }
        else if (button_id == "disabled-scripts") {
            dt.data().each(d => {

                // count all disabled scripts
                const parsed = d.is_enabled;
                if (!parsed) count += 1;

            });
        }

        $(node).html(`${button_text} (${count})`);
    },
    action: function (e, dt, node, config) {

        // get button script type
        const button_id = config.attr.id;

        $("#all-scripts, #enabled-scripts, #disabled-scripts").removeClass('active');

        if (button_id == "all-scripts") {
            dt.columns(INDEX_SEARCH_COLUMN).search("").draw();
            window.history.replaceState(undefined, undefined, "#all");
        }
        else if (button_id == "enabled-scripts") {
            // draw all enabled scripts
            dt.columns(INDEX_SEARCH_COLUMN).search("true").draw();
            window.history.replaceState(undefined, undefined, "#enabled");
        }
        else if (button_id == "disabled-scripts") {
            // draw all disabled scripts
            dt.columns(INDEX_SEARCH_COLUMN).search("false").draw();
            window.history.replaceState(undefined, undefined, "#disabled");
        }

        // delagate tooltips
        $(`span[data-toggle='popover']`).popover({
            trigger: 'manual',
            html: true,
            animation: false,
        })
        .on('mouseenter', function () {
            let self = this;
            $(this).popover("show");
            $(".popover").on('mouseleave', function () {
                jQuery(self).popover('hide');
            });
        })
        .on('mouseleave', function () {
            let self = this;
            setTimeout(function () {
                if (!$('.popover:hover').length) {
                    $(self).popover('hide');
                }
            }, 600);
        });

        $(`#${button_id}`).addClass("active");
    }
};