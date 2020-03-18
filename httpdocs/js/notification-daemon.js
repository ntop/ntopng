//
// (C) 2020 - ntop.org
//

const NOTIFICATION_DEBUG = true;

class PushNotificationBuilder {

    constructor(title = 'Hello World') {
        this.title = title;
        this.options = {};
        this.options.actions = [];
        this.options.icon = '/img/icons/icon-128x128.png';
        this.options.badge = '/img/icons/icon-72x72.png';
    }

    setTitle(title) {
        this.title = title;
        return this;
    }

    setBody(body) {
        this.options.body = body;
        return this;
    }

    setIcon(icon) {
        this.options.icon = icon;
        return this;
    }

    setLang(lang) {
        this.options.lang = lang;
        return this;
    }

    setRequireInteraction(interaction) {
        this.options.requireInteraction = interaction;
        return this;
    }

    setTimestamp(timestamp) {
        this.options.timestamp = timestamp;
        return this;
    }

    setOnClick(callback) {
        this.callback = callback;
        return this;
    }

    build() {

        const n = new Notification(this.title, this.options);
        if (this.callback) {
            n.onclick = this.callback;
        }
        return n;
    }

}

class NotificationManager {

    static enableNotification() {

        // ask to user the permission to send notification
        try {
            Notification.requestPermission((status) => {
                if (NOTIFICATION_DEBUG) console.info(status);
            });
        }
        catch (err) {
            console.error('Something went wrong! ☹️', err);
        }
    }

    static push(pushNotification = { title: 'Hello World', options: {} }) {

        if (!pushNotification) throw 'The notification object cannot be null!';

        if (NotificationManager.canReceiveNotification) {
            (async () => {
                try {
                    const registration = await navigator.serviceWorker.getRegistration();
                    registration.showNotification(pushNotification.title, pushNotification.options);
                }
                catch (err) {
                    console.error(err);
                }
            })();
        }
    }

    static get canReceiveNotification() {
        return NotificationManager.permissionNotification == 'granted'
    }

    static get permissionNotification() {
        return Notification.permission;
    }

}