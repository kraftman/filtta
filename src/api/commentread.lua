
local redis = require "resty.redis"
local tinsert = table.insert

local commentread = {}

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

function commentread:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function commentread:GetPostComments(postID)
  local red = GetRedisConnection()

  local ok, err = red:zrange('postComment:time:'..postID,0,-1)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get post comments: ',err)
    return {}
  end

  if ok == ngx.null then
    return {}
  end

  local commentsWithInfo = {}
  red:init_pipeline()
  for k, v in pairs(ok) do
    red:hgetall('comments:'..v)
  end
  local res, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to get comment info: ',err)
    return {}
  end
  for k,v in pairs(res) do
    tinsert(commentsWithInfo,self:ConvertListToTable(v))
  end

  return commentsWithInfo
end

function commentread:GetUserComments(userID)
  local red = GetRedisConnection()
  local ok, err = red:zrange('userComments:'..userID,0,-1)
  SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get user comments, ',err)
    return {}
  end
  if ok == ngx.null then
    return nil
  else
    return ok
  end
end

function commentread:GetComment(commentID)
  local red = GetRedisConnection()
  local ok, err = red:hgetall('comments:'..commentID)
  if not ok then
    ngx.log(ngx.ERR, 'unable to get comment info: ',err)
    return nil
  end

  if ok == ngx.null then
    return nil
  else
    return self:ConvertListToTable(ok)
  end

end

function commentread:GetCommentInfos(commentIDs)
  local red = GetRedisConnection()
  red:init_pipeline()
  for k,v in pairs(commentIDs) do
    red:hgetall('comments:'..v)
  end
  local res, err = red:commit_pipeline()
  if err then
    ngx.log(ngx.ERR, 'unable to get comments: ',err)
    return {}
  end


  local sorted = {}
  for k,v in pairs(res) do
    sorted[k] = self:ConvertListToTable(v)
  end

  return sorted

end



return commentread
