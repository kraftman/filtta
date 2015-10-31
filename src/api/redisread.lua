

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

function read:GetUnseenElements(checkSHA,baseKey, elements)
  local red = GetRedisConnection()
  red:init_pipeline()
  for k,v in pairs(elements) do
    red:evalsha(checkSHA,0,baseKey,10000,0.01,v)
  end
  local res, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to check for elemets: ',err)
    return {}
  end
  return res

end

--[[function read:CheckKey(checkSHA,addSHA)
  local keys = {'testr','rsitenrsi','rsiteunrsit'}
  local red = GetRedisConnection()

  local ok, err = red:evalsha(addSHA,0,'basekey',10000,0.01,'testr')
  if not ok then
    ngx.log(ngx.ERR, 'unable to add key: ',err)
  end

  red:init_pipeline()
    for k,v in pairs(keys) do
      red:evalsha(checkSHA,0,'basekey',10000,0.01,v)
    end
  local res, err = red:commit_pipeline()
  SetKeepalive(red)
  for k,v in pairs(res) do
    ngx.log(ngx.ERR,'k:',k,' v: ',v)
  end


end
--]]


function read:GetFilterIDsByTags(tags)

  local red = GetRedisConnection()
  red:init_pipeline()
  for k,v in pairs(tags) do
    red:hgetall('tag:filters:'..v.id)
  end
  local results, err = red:commit_pipeline()
  SetKeepalive(red)

  for k,v in pairs(results) do
    results[k] = self:ConvertListToTable(v)
  end

  if err then
    ngx.log(ngx.ERR, 'error retrieving filters for tags:',err)
  end

  return results
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

function read:GetFiltersBySubs(startAt,endAt)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filters',startAt,endAt)

  if not ok then
    ngx.log(ngx.ERR, 'unable to get filters: ',err)
    SetKeepalive(red)
    return
  end

  if ok == ngx.null then
    SetKeepalive(red)
    return
  else
    return ok
  end
end

function read:GetUserThreads(userID)
  local red = GetRedisConnection()
  local ok, err = red:zrange('UserThreads:'..userID,0,10)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user threads: ',err)
    return {}
  end
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end

function read:ConvertThreadFromRedis(thread)

  thread  = self:ConvertListToTable(thread)
  local viewers = {}


  for k,_ in pairs(thread) do
    if k:find('viewer') then
      ngx.log(ngx.ERR, 'found viewer:',k)
      local viewerID = k:match('viewer:(%w+)')
      if viewerID then
        thread[k] = nil
        tinsert(viewers,viewerID)
      end
    end
  end

  thread.viewers = viewers

  return thread
end

function read:GetThreadInfo(threadID)
  local red = GetRedisConnection()

  local ok, err = red:hgetall('Thread:'..threadID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get thread info:',err)
    return {}
  end

  local thread = read:ConvertThreadFromRedis(ok)

  ok,err = red:hgetall('ThreadMessages:'..threadID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load thread messages: ',err)
    return thread
  end

  thread.messages = self:ConvertListToTable(ok)
  for k,v in pairs(thread.messages) do
    thread.messages[k] = from_json(v)
  end

  return thread
end

function read:GetThreadInfos(threadIDs)
  local red = GetRedisConnection()
  red:init_pipeline()
    for _,threadID in pairs(threadIDs) do
      red:hgetall('Thread:'..threadID)
    end
  local res, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to load thread: ',err)
    return {}
  end
  for k,v in pairs(res) do
    res[k] = self:ConvertThreadFromRedis(v)
  end

  -- TODO: work out if this can be combined with the above
  red:init_pipeline()
    for k,thread in pairs(res) do
      red:hgetall('ThreadMessages:'..thread.id)
    end
  local msgs, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to get thread messages: ',err)
    return {}
  end

  --convert from json
  for k,message in pairs(msgs) do
    msgs[k] = self:ConvertListToTable(message)
    local threadID
    for m,n in pairs(msgs[k]) do

      msgs[k][m] = from_json(n)
      if not threadID then
      threadID = msgs[k][m].threadID
      end
    end
    for m,thread in pairs(res) do
      if thread.id == threadID then
        thread.messages = msgs[k]
      end
    end
    -- TODO sort the messages

  end


  return res
end

function read:GetFilterID(filterName)
  local red = GetRedisConnection()
  local ok, err = red:get('filterid:'..filterName)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter id from name: ',err)
  end
  SetKeepalive(red)
  if ok == ngx.null then
    return {}
  else
    return ok
  end
end



function read:GetFilter(filterID)
  local red = GetRedisConnection()
  local ok, err = red:hgetall('filter:'..filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load filter info: ',err)
  end
  if ok == ngx.null then
    return nil
  end
  local filter = self:ConvertListToTable(ok)

  filter.bannedUsers = {}
  filter.bannedDomains = {}
  local banInfo
  for k, v in pairs(filter) do
    if k:find('^bannedUser:') then
      banInfo = from_json(v)
      filter.bannedUsers[banInfo.userID] = banInfo
      filter[k] = nil
    elseif k:find('^bannedDomain:') then
      tinsert(filter.bannedDomains, from_json(v))
      banInfo = from_json(v)
      filter.bannedDomains[banInfo.domainName] = banInfo
      filter[k] = nil
    end
  end


  --print(to_json(filter))

  ok, err = red:smembers('filter:bannedtags:'..filterID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to load banned tags: ',err)
  end
  if ok == ngx.null then
    filter.bannedTags = {}
  else
    filter.bannedTags = ok
  end

  ok, err = red:smembers('filter:requiredtags:'..filterID)
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

  local postTags,err = red:smembers('post:tagIDs:'..postID)
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


  ok,err =red:smembers('postfilters:'..postID)
  if not ok then
    ngx.log(ngx.ERR, 'could not load filters: ',err)
  end
  --ngx.log(ngx.ERR, to_json(ok))
  post.filters = ok

  return post
end

function read:GetFilterPosts(filter)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filterposts:score:'..filter.id,0,50)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get filter posts ',err)
  end
  ok = ok ~= ngx.null and ok or {}
  SetKeepalive(red)
  return ok
end


function read:GetAllNewPosts(rangeStart,rangeEnd)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filterpostsall:date',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get new posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:GetAllFreshPosts(rangeStart,rangeEnd)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filterpostsall:datescore',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get fresh posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
end

function read:GetAllBestPosts(rangeStart,rangeEnd)
  local red = GetRedisConnection()
  local ok, err = red:zrange('filterpostsall:score',rangeStart,rangeEnd)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get best posts: ',err)
  end

  return ok ~= ngx.null and ok or {}
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
