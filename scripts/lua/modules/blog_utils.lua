--
-- (C) 2020 - ntop.org
--

local json = require("dkjson")

local blog_utils = {}

function blog_utils.updateRedis(newPosts)
    -- save the posts inside redis
    ntop.setPref("ntopng.notifications.blog_feed", json.encode(newPosts))
end

function blog_utils.fetchLatestPosts()
    local JSON_FEED = "https://www.ntop.org/blog/feed/json"
    local response = ntop.httpGet(JSON_FEED)

    if((response == nil) or (response["CONTENT"] == nil)) then
        return(false)
    end

    local jsonFeed = json.decode(response["CONTENT"])

    if((jsonFeed == nil) or table.empty(jsonFeed["items"])) then
        return(false)
    end

    local posts = jsonFeed["items"]

    local latest3Posts = {posts[1], posts[2], posts[3]}
    local formattedPosts = {}

    for i, post in ipairs(latest3Posts) do

        if (post ~= nil) then

            local splittedLink = split(post.id, "?p=")
            local postId = tonumber(splittedLink[2])
            local postTitle = post.title
            local postDate = post.date_published
            local year, month, day = string.match(postDate, "(%d+)-(%d+)-(%d+)")
            local postEpoch = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
            local postURL = post.url
            local postShortDesc = string.sub(post.content_text, 1, 48) .. '...'

            local post =  {
                id = postId,
                title = postTitle,
                link = postURL,
                date = postDate,
                epoch = postEpoch,
                shortDesc = postShortDesc
            }

            table.insert(formattedPosts, post)
        end
    end

    -- updates redis
    blog_utils.updateRedis(formattedPosts)

    return(true)
end

function blog_utils.readPostsFromRedis()
    local postsJSON = ntop.getPref("ntopng.notifications.blog_feed")
    local posts = nil

    if not isEmptyString(postsJSON) then
        posts = json.decode(postsJSON)
    end

    if(posts == nil) then
        posts = {}
    end

    return posts
end

return blog_utils
