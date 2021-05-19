const globalToasts = {};

class Toast {

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
        const $toast = $(`<div class="toast notification" role="alert"></div>`);

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
        const $toastBody = $(`<div class="toast-body">${this.body}</div>`);

        if (this.action && this.action.link != undefined && this.action.link != "") {
            const $anchor = $(`<a href='${this.action.link}'>${this.action.label}</a>`);
            $toastBody.append($anchor);
        }

        if (this.dismissable) {
            $toastHeader.append(`
                <button type="button" class="ml-2 mb-1 close" data-bs-dismiss="toast" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            `);
        }

        if (this.isAboveAll) {
            $toast.css("z-index", "9999");
        }

        $toast.append($toastHeader, $toastBody);
        $toast.toast('show');

        $toast.on('hidden.bs.toast', function () {
            ToastUtils.hideToast(self.id);
        });

        this.$element = $toast;

        return $toast;
    }

    updateBody(body) {

        if (this.$element == undefined) throw 'The notification has not been rendered yet!';
        this.$element.find('.toast-body span').text(body);
    }

    destroy() {
        this.$element.toast('dispose');
        this.$element.empty();
    }

}

class ToastUtils {

    static initToasts() {

        $(`.toast.notification`).each(function () {
            $(this).toast('show');
        });
    }

    static hideToast(toastId) {

        if (!toastId) {
            console.warn("The toast id cannot be null!");
            return;
        }

        if (!(toastId in globalToasts)) {
            console.warn("The toast hasn't been found!");
            return;
        }

        globalToasts[toastId].destroy();
        delete globalToasts[toastId];
    }

    static updateToast(toastId, body) {

        if (!(toastId in globalToasts)) {
            throw 'The toast was not found!';
        }

        globalToasts[toastId].updateBody(body);
    }

    static showToast(option) {

        const styles = {
            warning: { bg: 'warning', text: 'text-dark', icon: 'fa-exclamation-circle' },
            info: { bg: 'info', text: 'text-white', icon: 'fa-info-circle' },
            success: { bg: 'success', text: 'text-white', icon: 'fa-check-circle' },
            error: { bg: 'danger', text: 'text-white', icon: 'fa-times-circle' }
        };

        option.style = styles[option.level] || styles.warning;

        if (option.id === undefined) throw 'A toast must have an in id!';
        if (option.id in globalToasts) return;
        if (option.title === undefined) throw 'A toast must have a title!'; 
        if (option.body === undefined) throw 'A toast must have a body!';

        const toast = new Toast(option);
        // render the toast inside the main container
        $(`#main-container`).prepend(toast.render());

        // push the toast inside the global container
        globalToasts[option.id] = toast;

        return toast;
    }

    static dismissToast(id, csrf, success, failure) {

		if (id == undefined) {
			console.warn("A Toast ID must be defined to dismiss a toast!");
			return;
		}

		const empty = () => {};
		const request = $.post(`${http_prefix}/lua/dismiss_toast.lua`, {toast_id: id, csrf: csrf});
		request.done(success || empty);
		request.fail(failure || empty);
	}


}
