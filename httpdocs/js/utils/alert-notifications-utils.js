class AlertNotificationUtils {

    static initAlerts() {

        $(`.toast.alert-notification`).each(function() {

            const noScope = $(this).data("notificationNoScope");
            const pages = (noScope == "") ? [] : noScope.split(";");

            // if the current page match the no-scoping attribute
            // then doesn't show the notification
            if (pages.length > 0 && pages.some((page) => location.href.contains(page))) {
                $(this).remove();
            }

            $(this).toast('show');
        });
        // show the alert notifications inside the page
        // binding the closing handler to toasts
        AlertNotificationUtils.bindClosingEvent();
    }

    static bindClosingEvent() {

        // send the notification id to the handler
        $('.toast.alert-notification').on('hidden.bs.toast', function () {
            $.post(`${http_prefix}/lua/handler_alert_notification.lua`,
            { notification_id: $(this).data("notificationId"), action: `disposed` });
        });
    }

}