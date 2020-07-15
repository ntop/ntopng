const alertNotifications = {};
let alertNotificationUtilsId = 0;

class AlertNotification {

    constructor({ title, body, link, delay = 0, id, style } = {}) {
        this.title = title;
        this.body = body;
        this.link = link;
        this.delay = delay;
        this.id = id;
        this.style = style;
    }

    render() {
        const self = this;
        // create a non-closable toast
        const $toast = $(`<div class="toast alert-notification" role="alert"></div>`);
        // set toast expiracy
        if (this.delay !== 0) {
            $toast.data('autohide', true);
            $toast.data('delay', this.delay);
        }
        else {
            $toast.data('autohide', false);
        }
        // assign an id to the notification
        $toast.data('notification-id', this.id);

        const $toastHeader = $(`<div class="toast-header bg-${this.style.bg} border-${this.style.bg} ${this.style.text}">
                                    <strong class='mr-auto'><i class='fas ${this.style.icon}'></i> ${this.title}</strong>
                                </div>`);
        const $toastBody = $(`<div class="toast-body bg-${this.style.bg} border-${this.style.bg} ${this.style.text}"><span>${this.body}</span></div>`);

        if (this.link != undefined && this.link != "") {
            const $anchor = $(`<a href='${this.link}'>Click!</a>`);
            $toastBody.append($anchor);
        }

        $toast.append($toastHeader, $toastBody);
        $toast.toast('show');

        $toast.on('hidden.bs.toast', function () {
            AlertNotificationUtils.hideAlert(self.id);
        });

        this.$element = $toast;

        return $toast;
    }

    updateBody(body) {

        if (this.$element == undefined) throw '[AlertNotification] :: The notification has not been rendered yet!';
        this.$element.find('.toast-body span').text(body);
    }

    destroy() {
        this.$element.toast('dispose');
        this.$element.empty();
    }

}

class AlertNotificationUtils {

    static initAlerts() {

        $(`.toast.alert-notification`).each(function () {

            const noScope = $(this).data("notificationNoScope");
            const pages = (noScope == "" || noScope == undefined) ? [] : noScope.split(";");

            // if the current page match the no-scoping attribute
            // then doesn't show the notification
            if (pages.length > 0 && pages.some((page) => location.href.contains(page))) {
                $(this).remove();
            }

            $(this).toast('show');
        });
    }

    static hideAlert(notificationId) {

        if (!notificationId) {
            console.warn("[AlertNotificationUtils] :: The notification cannot be null!");
            return;
        }

        if (!(notificationId in alertNotifications)) {
            return;
        }

        alertNotifications[notificationId].destroy();
        delete alertNotifications[notificationId];

    }

    static updateNotification(notificationId, body) {

        if (!(notificationId in alertNotifications)) {
            throw '[AlertNotificationUtils] :: The notification was not found!';
        }

        alertNotifications[notificationId].updateBody(body);
    }

    static showAlert(option) {

        const styles = {
            warning: {
                bg: 'warning',
                text: 'text-dark',
                icon: 'fa-exclamation-circle'
            },
            info: {
                bg: 'info',
                text: 'text-white',
                icon: 'fa-info-circle'
            },
            success: {
                bg: 'success',
                text: 'text-white',
                icon: 'fa-check-circle'
            }
        }

        const style = styles[option.level] || styles.warning;

        if (option.id === undefined) throw '[AlertNotificationUtils] :: An AlertNotification must have an in id!';
        if (option.id in alertNotifications) return;
        if (option.title === undefined) throw '[AlertNotificationUtils]:: An AlertNotification must have a title!';
        if (option.body === undefined) throw '[AlertNotificationUtils]:: An AlertNotification must have a body!';

        option.style = style;

        const notification = new AlertNotification(option);
        // render the notification inside the main container
        $(`#main-container`).prepend(notification.render());

        // push the notification inside the global container
        alertNotifications[option.id] = notification;

        return notification;
    }

    static bindClosingEvent() {

        // send the notification id to the handler
        $('.toast.alert-notification[data-notification-id]').on('hidden.bs.toast', function () {
            $.post(`${http_prefix}/lua/handler_alert_notification.lua`,
                { notification_id: $(this).data("notificationId"), action: `disposed` });
        });
    }

}