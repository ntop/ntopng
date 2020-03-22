--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if ((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then
    package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path
end

require "lua_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('application/json')

local blog_module = {}

function blog_module.updateRedis(newPosts)

    ntop.setPref("ntopng.notifications.blog_feed", json.encode({}))

    local oldPostsJSON = ntop.getPref("ntopng.notifications.blog_feed")
    local oldPosts = json.decode(oldPostsJSON)

    -- merge the posts array
    local posts = {}
    for i, p in ipairs(oldPosts) do
        posts[p.id] = p
    end
    for i, p in ipairs(newPosts) do
        if (posts[p.id] == nil) then
            posts[p.id] = p
        end
    end

    local prePosts = {}
    for i, post in pairs(posts) do
        table.insert(prePosts, post)
    end

    table.sort(prePosts, function(p1, p2) return p1.epoch > p2.epoch end)
    local firstPosts = {prePosts[1], prePosts[2], prePosts[3]}

    -- save the posts inside redis
    ntop.setPref("ntopng.notifications.blog_feed", json.encode(firstPosts))

end

function blog_module.fetchLatestPosts()

    local JSON_FEED = "https://www.ntop.org/blog/feed/json"
    local response = ntop.httpGet(JSON_FEED)
    local jsonFeed = json.decode(response["CONTENT"])
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
    blog_module.updateRedis(formattedPosts)

end

function blog_module.readPostsFromRedis()

    local postsJSON = ntop.getPref("ntopng.notifications.blog_feed")
    local posts = json.decode(postsJSON)

    return posts
end

print(json.encode({
    success = true,
    posts = blog_module.readPostsFromRedis()
}))


return blog_module