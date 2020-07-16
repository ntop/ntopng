/* Handle Blog Notifications */
$(document).ready(function () {

    function blogNotifcationClick(e) {

      if (e.type == "mousedown" && (e.metaKey || e.ctrlKey || e.which !== 2)) return;

      const id = $(this).data('id');

      $.post(`${http_prefix}/lua/update_blog_posts.lua`, {
        blog_notification_id: id,
        csrf: blogNotificationCsrf
      },
        (data) => {

          if (data.success) {
            $(this)
              .off('click').off('mousedown')
              .attr('data-read', 'true').data('read', 'true')
              .find('.badge').remove();
            const count = $(`.blog-notification[data-read='false']`).length;

            if (count == 0) {
              $('.notification-bell').remove();
              return;
            }
            $('.notification-bell').html(count);
          }
        });
    }

    $(`.blog-notification[data-read='false']`)
      .click(blogNotifcationClick).mousedown(blogNotifcationClick);
  });