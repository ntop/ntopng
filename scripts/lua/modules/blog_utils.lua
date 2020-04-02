--
-- (C) 2020 - ntop.org
--

local json = require("dkjson")

local blog_utils = {}

function intersect_posts(s1, s2)

    local newSet = {}
    local post1 = s1[1]

    -- if there aren't any old post then return the new ones
    if (s1[1] == nil) then
        for _, p in ipairs(s2) do
            p.users = {}
            for username, _ in pairs(ntop.getUsers()) do
                p["users"][username] = {}
                p["users"][username]["isNew"] = true
            end
        end
        return s2
    end
    -- if there aren't any new post then return the old ones
    if (s2[1] == nil) then
        return s1
    end

    for i = 1, 3 do

        local post2 = s2[i]

        if (post1.epoch < post2.epoch) then
            newSet[i] = post2
            newSet[i + 1] = s1[i]
            newSet[i]["users"] = {}
            for username, _ in pairs(ntop.getUsers()) do
                newSet[i]["users"][username] = {}
                newSet[i]["users"][username]["isNew"] = true
            end
        elseif (post1.epoch == post2.epoch) then
            newSet[i + 1] = s1[i]
        end
    end

    return newSet
end

function blog_utils.updatePostState(blogNotificationId, username)

    local postsJSON = ntop.getPref("ntopng.prefs.blog_feed")
    local posts = json.decode(postsJSON)
    local success = false

    for _, p in ipairs(posts) do
        if p.id == blogNotificationId then
            p.users[username].isNew = false
            success = true
        end
    end

    ntop.setPref("ntopng.prefs.blog_feed", json.encode(posts))

    return (success)
end

function blog_utils.updateRedis(newPosts)

    -- decode older posts from updateRedis
    local oldPostsJSON = ntop.getPref("ntopng.prefs.blog_feed")
    local oldPosts = {}
    if (not isEmptyString(oldPostsJSON)) then
        oldPosts = json.decode(oldPostsJSON)
    end

    -- intersect two notifications sets and marks the new
    local intersected = intersect_posts(oldPosts, newPosts)
    -- save the posts inside redis
    ntop.setPref("ntopng.prefs.blog_feed", json.encode(intersected))

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

function blog_utils.readPostsFromRedis(username)

    local postsJSON = ntop.getPref("ntopng.prefs.blog_feed")
    local posts = nil

    if not isEmptyString(postsJSON) then
        posts = json.decode(postsJSON)
    end

    if(posts == nil) then
        posts = {}
    end

    -- normalize the post data
    for i, p in pairs(posts) do
        p.isNew = p.users[username].isNew
    end

    return posts
end

return blog_utils
