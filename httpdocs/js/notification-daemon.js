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

class BlogFeed {

    static getLocalStorageKey() {

        const VERSION = 'v2';
        return `blogFeed${VERSION}`;
    }

    static settingsExists(storage, currentUserName) {

        if (storage == undefined) return false;
        if (storage.users == undefined) return false;
        if (!(currentUserName in storage.users)) return false;

        return true;
    }

    static removeLegacyVersion() {
        localStorage.removeItem('blog_feed');
    }

    /**
     * Initialize the local storage options. If there aren't any options
     * then create new ones with default paramaters.
     * The function return the localStorage[BlogFeed.getLocalStorageKey()].
     *
     * @return {object}
     */
    static initializeLocalStorage(currentUserName) {

        // check if the settings exists inside the local storage
        const jsonBlog = localStorage.getItem(BlogFeed.getLocalStorageKey());
        const blogFeedSettings = JSON.parse(jsonBlog);

        // force the user to remove the old version of the local storage
        BlogFeed.removeLegacyVersion();

        if (!BlogFeed.settingsExists(blogFeedSettings, currentUserName)) {

            // create empty settings for blog feed

            if (blogFeedSettings != undefined) {
                blogFeedSettings.users[currentUserName] = {
                    lastCheck: Date.now(),
                    downloadedPosts: []
                };

                return blogFeedSettings;
            }

            let emptyBlogSettings = {
                users: {
                    [currentUserName]: {
                        lastCheck: Date.now(),
                        downloadedPosts: []
                    }
                }
            };

            return emptyBlogSettings;
        }

        return blogFeedSettings;
    }

    static getUserLocalStorage(currentLocalStorage, currentUserName) {
        return currentLocalStorage.users[currentUserName];
    }

    static async checkNewPosts(currentLocalStorage) {

        // initialize the local storage to store information
        // about new posts
        let aDayIsPassed;

        if (currentLocalStorage.downloadedPosts == undefined) {
            aDayIsPassed = true;
        }
        else {
            aDayIsPassed = (currentLocalStorage.downloadedPosts.length == 0)
                ? true : Math.floor((Date.now() - currentLocalStorage.lastCheck) / 86400000) >= 1;
        }

        // if a day is passed since the last check then check if there is a new post
        // inside the blog
        if (aDayIsPassed) {

            try {

                const request = await fetch('/lua/get_new_blog_posts.lua');
                const response = await request.json();
                const {posts} = response;
                const notificationToShow = [];
                if (!posts) return {fetchedPosts: [], aDayIsPassed: aDayIsPassed};

                posts.forEach((post) => {

                    const postId = post.id;
                    if (currentLocalStorage.downloadedPosts.find(shownId => shownId == postId)) return;
                    post.isNew = true;
                    notificationToShow.push(post);

                });

                return {fetchedPosts: notificationToShow, aDayIsPassed: aDayIsPassed};
            }
            catch (err) {
                if (NOTIFICATION_DEBUG) console.error("BlogFeed :: Ops, an error appeared!", err);
            }
        }

        return {fetchedPosts: [], aDayIsPassed: aDayIsPassed};
    }

    static showNotifications(newPosts, newPostsLength, currentUserName, currentLocalStorage) {

        if (newPosts.length == 0) return;

        const $notificationBell = $("#notification-list");
        const $badgeNotificationCount = $(`<span class="badge notification-bell badge-pill badge-danger">${newPostsLength}</span>`);

        if (newPostsLength > 0) $notificationBell.prepend($badgeNotificationCount);

        const $blogSection = $(".blog-section");
        const $list = $blogSection.find("ul");
        $list.empty();

        newPosts.forEach((post, index) => {

        if (!post) return;

            const $media = $("<li></li>");
            if (index < newPosts.length - 1) $media.addClass("border-bottom");

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

            if (newPostsLength > 0) {

                $link.click(function(e) {

                    // remove the badge
                    $link.find(`span.badge`).remove();
                    // remove click listener
                    $link.off('click');

                    // decrease the counter
                    let currentCounter = parseInt($badgeNotificationCount.text());
                    $badgeNotificationCount.html(--currentCounter);
                    if (currentCounter == 0) $badgeNotificationCount.empty();

                    // mark the post as old
                    const downloadedPosts = BlogFeed.getUserLocalStorage(currentLocalStorage, currentUserName).downloadedPosts;

                    const oldPosts = downloadedPosts.map((p) => {
                        if (p.id == post.id) p.isNew = false;
                        return p;
                    });

                    BlogFeed.saveDownloadedPosts(currentLocalStorage, oldPosts, currentUserName);
                });
            }

            $container.append($link);
            $media.append($container);
            $list.append($media);

        });

    }

    static saveDownloadedPosts(currentLocalStorage, downloadedPosts, currentUserName) {

        // remove the current local storage
        localStorage.removeItem(BlogFeed.getLocalStorageKey());

        // update the new local storage per user
        let currentEpoch = Date.now();

        currentLocalStorage.users[currentUserName] = {
            lastCheck: currentEpoch,
            downloadedPosts: downloadedPosts
        };

        localStorage.setItem(BlogFeed.getLocalStorageKey(), JSON.stringify(currentLocalStorage));
    }

    static filterNewPosts(currentLocalStorage, newPosts) {

        const downloadedPosts = currentLocalStorage.downloadedPosts;

        switch (newPosts.length) {
            case 1:
                return [newPosts[0], downloadedPosts[0], downloadedPosts[1]];
            case 2:
                return [newPosts[0], newPosts[1], downloadedPosts[0]];
            case 3:
                return newPosts;
            default:
                return downloadedPosts;
        }
    }

    static queryBlog(currentUserName) {

        const currentLocalStorage = BlogFeed.initializeLocalStorage(currentUserName);
        const currentUserLocalStorage = BlogFeed.getUserLocalStorage(currentLocalStorage, currentUserName);

        (async() => {

            const {fetchedPosts, aDayIsPassed} = await BlogFeed.checkNewPosts(currentUserLocalStorage);
            if (!aDayIsPassed) {

                const toShow = currentUserLocalStorage.downloadedPosts;
                let counter = 0;
                // count how many post have not been read
                toShow.forEach((p) => {
                    if (!p) return;
                    if (p.isNew) counter++;
                });

                BlogFeed.showNotifications(toShow, counter, currentUserName, currentLocalStorage);
                return;
            }

            const newPosts = fetchedPosts.filter(post => {
                return !(currentUserLocalStorage.downloadedPosts.find(post2 => post.id == post2.id));
            });

            // remove the older posts from the local storage
            for (let i = 0; i < newPosts; i++) currentUserLocalStorage.downloadedPosts.pop();

            // filter post notification
            const toShow = BlogFeed.filterNewPosts(currentUserLocalStorage, newPosts);
            // show new post notifications
            BlogFeed.showNotifications(toShow, newPosts.length, currentUserName, currentLocalStorage);

            // merge the arrays and save it into local storage
            const newUserLocalStorage = [...newPosts, ...currentUserLocalStorage.downloadedPosts];
            BlogFeed.saveDownloadedPosts(currentLocalStorage, newUserLocalStorage, currentUserName);

        })();
    }

}
