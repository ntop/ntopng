/* Handle Blog Notifications */
$(function () {

  function blogNotifcationClick(e) {

    if (e.type == "mousedown" && (e.metaKey || e.ctrlKey || e.which !== 2)) return;

    const id = $(this).data('id');

    $.post(`${http_prefix}/lua/update_blog_posts.lua`, {
      blog_notification_id: id,
      csrf: window.__BLOG_NOTIFICATION_CSRF__
    },
      (data) => {

        if (data.success) {

          $(this).off('click').off('mousedown').attr('data-read', 'true').data('read', 'true').find('.badge').remove();
          
          const count = $(`.blog-notification[data-read='false']`).length;

          if (count == 0) {
            $('.notification-bell').remove();
          }
          else {
            $('.notification-bell').html(count);
          }
        }
      });
  }

  // on the notifications not yet read delegate the click event
  $(`.blog-notification[data-read='false']`).on('click', blogNotifcationClick).on('mousedown', blogNotifcationClick);
});