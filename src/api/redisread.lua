

local redis = require "resty.redis"
local tinsert = table.insert

local read = {}

local function GetRedisConnection()
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
      ngx.say("failed to connect: ", err)
      return
  end
  return red
end

local function SetKeepalive(red)
  local ok, err = red:set_keepalive(10000, 100)
  if not ok then
      ngx.say("failed to set keepalive: ", err)
      return
  end
end

function read:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function read:GetAllTags()
  local red = GetRedisConnection()
  local ok, err = red:smembers('tags')
  if not ok then
    ngx.log(ngx.ERR, 'unable to load tags:',err)
    return {}
  end

  red:init_pipeline()
  for k,v in pairs(ok) do
    red:hgetall('tag:'..v)
  end
  local results, err = red:commit_pipeline(#ok)

  for k,v in pairs(results) do
    results[k] = self:ConvertListToTable(v)
  end

  if err then
    ngx.log(ngx.ERR, 'error reading tags from reds: ',err)
  end
  SetKeepalive(red)
  return results
end


function read:GetUserFilters(username)

  local red = GetRedisConnection()

  local ok, err
  if username == 'default' then
    ok, err = red:zrange('filters',0,-1)
  else
    ok, err = red:smembers('filterlist:'..username)
  end
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'error getting filter list for user "',username,'", error:',err)
    return {}
  end

  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function read:GetFilter(filterName)
  local red = GetRedisConnection()
  local ok, err = red:hgetall('filter:'..filterName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load filter info: ',err)
  end
  if ok == ngx.null then
    return nil
  end
  local filter = self:ConvertListToTable(ok)

  ok, err = red:smembers('filter:bannedtags:'..filterName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load banned tags: ',err)
  end
  if ok == ngx.null then
    filter.bannedTags = {}
  else
    filter.bannedTags = ok
  end

  ok, err = red:smembers('filter:requiredtags:'..filterName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load required tags: ',err)
  end
  if ok == ngx.null then
    filter.requiredTags = {}
  else
    filter.requiredTags = ok
  end
  return filter


end

function read:GetPost(postID)
  local red = GetRedisConnection()
  local ok, err = red:hgetall('post:'..postID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get post:',err)
  end

  if ok == ngx.null then
    return nil
  end

  local post = self:ConvertListToTable(ok)
  local postTags,err = red:smembers('post:tags:'..postID)
  if not postTags then
    ngx.log(ngx.ERR, 'unable to get post tags:',err)
  end
  if postTags == ngx.null then
    postTags = {}
  end

  post.tags = {}

  for k, tagName in pairs(postTags) do
    ok, err = red:hgetall('posttags:'..postID..':'..tagName)
    if not ok then
      ngx.log(ngx.ERR, 'unable to load posttags:',err)
    end

    if ok ~= ngx.null then
      tinsert(post.tags,self:ConvertListToTable(ok))
    end
  end

  return post
end


function read:LoadFrontPageList(username)
  local filterList = self:GetUserFilters(username)

  local red = GetRedisConnection()

  if username == 'default' then
    local ok, err = red:zrange('posts',0,-1)
    if ok == ngx.null then
      return {}
    else
      return ok
    end
  end

  startAt = startAt or 0
  red:init_pipeline()
  for k, v in pairs(filterList) do
    red:zrange(v..':score',0,50)
  end
  local results, err = red:commit_pipeline()

  if not results then
    ngx.log(ngx.ERR, 'error getting posts for filters:',err)
    return {}
  end
  for k,v in pairs(results) do
    if not next(v) then
      results[k] = nil
    end
  end

  if results == ngx.null then
    return {}
  else
    return results
  end

end

function read:BatchLoadPosts(posts)
  local red = GetRedisConnection()
  red:init_pipeline()
  for k,postID in pairs(posts) do
      red:hgetall('post:'..postID)
  end
  local results, err = red:commit_pipeline()
  if not results then
    ngx.log(ngx.ERR, 'unable batch get post info:', err)
  end
  local processedResults = {}

  for k,v in pairs(results) do
    tinsert(processedResults,self:ConvertListToTable(v))
  end

  return results
end

function read:GetTag(tagName)
  local red = GetRedisConnection()
  local ok, err = red:hgetall('tag:'..tagName)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load tag:',err)
    return
  end
  local tagInfo = self:ConvertListToTable(ok)

  return tagInfo
end





return read