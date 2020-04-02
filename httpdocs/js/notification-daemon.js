//
// (C) 2020 - ntop.org
//

const NOTIFICATION_DEBUG = false;

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

let csrfBlogNotification = null

class BlogFeed {

    static countNewPosts(posts) {
        let newPostsCounter = 0;
        posts.forEach(p => {
            if (p.isNew) newPostsCounter++;
        });
        return newPostsCounter;
    }

    static showNotifications(posts) {

        const $notificationBell = $("#notification-list");
        let newPostsCounter = BlogFeed.countNewPosts(posts);

        const $badgeNotificationCount = $(`
            <span class="badge notification-bell badge-pill badge-danger">${newPostsCounter}</span>
        `);

        if (newPostsCounter > 0) $notificationBell.prepend($badgeNotificationCount);

        const $blogSection = $(".blog-section");
        const $list = $blogSection.find("ul"); $list.empty();

        posts.forEach((post, index) => {

            if (!post) return;

            const $media = $("<li></li>");
            if (index < posts.length - 1) $media.addClass("border-bottom");

            const $container = $("<div class='media-body pt-2 pr-2 pl-2 pb-1'></div>");
            const $link = $("<a class='text-dark'></a>");
            $link.attr("target", "_about");
            $link.attr("href", post.link);

            $link.append(
                $(`
                    <h6 class='mt-0 mb-1'>
                        ${post.isNew ? "<span class='badge badge-primary'>New</span>" : ""}
                        ${post.title.length >= 40 ? post.title.substr(0, 40) + '...' : post.title}
                        <i class='fas fa-external-link-alt float-right'></i>
                    </h6>
                `),
                $("<p class='mb-0'></p>").html(post.shortDesc),
                $("<small class='mb-0'></small>").html(`posted on ${new Date(post.date).toLocaleDateString()}`)
            );

            if (post.isNew) {

                const onLinkClick = function(e) {

                    $badgeNotificationCount.html(--newPostsCounter);
                    $link.find(`span.badge`).remove();
                    if (newPostsCounter == 0) $badgeNotificationCount.remove();

                    BlogFeed.updateNotifcationState(post.id);
                    $(this).off('click').off('mousedown');
                };

                $link.click(onLinkClick).mousedown((e) => {
                    if (e.which == 2) onLinkClick(e);
                });
            }

            $container.append($link);
            $media.append($container);
            $list.append($media);

        });

    }

    static updateNotifcationState(id) {

        if (id == undefined) throw 'The notification id is not defined!';

        $.post(`/lua/update_blog_posts.lua`, { blog_notification_id: id, csrf: csrfBlogNotification }, (data) => {
            csrfBlogNotification = data.csrf;
        });
    }

    static queryBlog(csrf) {

        csrfBlogNotification = csrf;

        (async () => {

            const request = await fetch('/lua/get_new_blog_posts.lua');
            const response = await request.json();
            const {posts} = response;

            BlogFeed.showNotifications(posts);

        })();

    }

}