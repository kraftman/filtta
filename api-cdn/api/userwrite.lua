
local userwrite = {}

local redis = require 'resty.redis'
local to_json = (require 'lapis.util').to_json
local addKey = require 'redisscripts.addkey'
local util = require 'util'

function userwrite:ConvertListToTable(list)
  local info = {}
  for i = 1,#list, 2 do
    info[list[i]] = list[i+1]
  end
  return info
end

function userwrite:LoadScript(script)
  local red = util:GetUserWriteConnection()
  local ok, err = red:script('load',script)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add script to redis:',err)
    return nil
  else
    ngx.log(ngx.ERR, 'added script to redis: ',ok)
  end

  return ok
end

function userwrite:AddUserTagVotes(userID, postID, tagIDs)
  local red = util:GetUserWriteConnection()
  for k,v in pairs(tagIDs) do
    tagIDs[k] = postID..':'..v
  end

  local ok, err = red:sadd('userTagVotes:'..userID, tagIDs)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user tag vote: ',err)
  end
  return ok
end

function userwrite:AddUserCommentVotes(userID, commentID)
  local red = util:GetUserWriteConnection()

  local ok, err = red:sadd('userCommentVotes:'..userID, commentID)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user comment vote: ',err)
  end
  return ok
end


function userwrite:AddUserPostVotes(userID, postID)
  local red = util:GetUserWriteConnection()

  local ok, err = red:sadd('userPostVotes:'..userID, postID)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add user post vote: ',err)
  end
  return ok

end

function userwrite:AddUserAlert(createdAt,userID, alert)
  local red = util:GetUserWriteConnection()
  print('adding user alert for ',userID,to_json(alert))
  local ok, err = red:zadd('UserAlerts:'..userID,createdAt,alert)
  if not ok then
    ngx.log(ngx.ERR, 'unable to create alert: ',err)
  end
  util:SetKeepalive(red)
  return ok
end

function userwrite:UpdateLastUserAlertCheck(userID, checkedAt)
  local red = util:GetUserWriteConnection()
  local ok, err = red:hmset('user:'..userID,'alertCheck',checkedAt)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to set user alert check:',err)
  end
  return ok
end

function userwrite:AddComment(commentInfo)
  local red = util:GetUserWriteConnection()
  local ok, err = red:zadd('userComments:'..commentInfo.createdBy, commentInfo.createdAt, commentInfo.postID..':'..commentInfo.id)
  if not ok then
    ngx.log(ngx.ERR, 'unable to add comment: ', err)
  end
end

function userwrite:CreateAccount(account)

  local red = util:GetUserWriteConnection()
  local ok, err = red:del('account:'..account.id)

  local users = account.users
  local sessions = account.sessions
  account.sessions = nil
  account.users = nil

  for _,v in pairs(users) do
    account['user:'..v] = v
  end
  for _,session in pairs(sessions) do
    account['session:'..session.id] = to_json(session)
  end
  local ok, err = red:del('account:'..account.id)
  local ok, err = red:hmset('account:'..account.id,account)

  return ok, err

end

function userwrite:CreateMasterUser(masterInfo)
  -- pipeline
  local red = util:GetUserWriteConnection()
  local users = masterInfo.users
  masterInfo.users = nil
  local ok, err = red:hmset('master:'..masterInfo.id,masterInfo)
  if not ok then
    ngx.log(ngx.ERR, 'unable to create master info:',err)
    return false
  end

  red:hset('useremails',masterInfo.email,masterInfo.id)

  for k, v in pairs(users) do
    ok, err = red:sadd('masterusers:'..masterInfo.id, v)
  end
  if not ok then
    ngx.log(ngx.ERR, 'unable to create master user: ',err)
  end

end

function userwrite:AddSeenPosts(userID,seenPosts)
  local red = util:GetUserWriteConnection()
  local addKeySHA1 = addKey:GetSHA1()

  red:init_pipeline()
    for k,postID in pairs(seenPosts) do
      red:evalsha(addKeySHA1,0,userID,10000,0.01,postID)
      red:zadd('userSeen:'..userID,ngx.time(),postID)
    end
  local res,err = red:commit_pipeline()
  util:SetKeepalive(red)
  if err then
    ngx.log(ngx.ERR, 'unable to add seen post: ',err)
    return nil
  end
  return true
end

function userwrite:LabelUser(userID, targetUserID, label)
  local red = util:GetUserWriteConnection()

  local ok, err = red:hset('user:'..userID, 'userlabel:'..targetUserID, label)
  if err then
    ngx.log(ngx.ERR, 'unable to set user label')
  end
  return ok, err
end

function userwrite:IncrementUserStat(userID, statName, value)
  local red = util:GetUserWriteConnection()
  local ok, err = red:hincrby('user:'..userID, statName, value)
  util:SetKeepalive(red)
  return ok, err
end

function userwrite:CreateSubUser(userInfo)
  local red = util:GetUserWriteConnection()
  local filters = userInfo.filters or {}
  userInfo.filters = nil

  for k,v in pairs(userInfo) do
    ngx.log(ngx.ERR, k, to_json(v))
  end

  red:init_pipeline()
    red:hmset('user:'..userInfo.id,userInfo)
    for _,filterID in pairs(filters) do
      red:sadd('userfilters:'..userInfo.id,filterID)
    end
    red:hset('userToID',userInfo.username:lower(),userInfo.id)
  local results, err = red:commit_pipeline()
  util:SetKeepalive(red)

  if err then
    ngx.log(ngx.ERR, 'unable to create new user: ',err)
    return nil
  end
  return true

end

function userwrite:ActivateAccount(userID)
  local red = util:GetUserWriteConnection()
  local ok, err = red:hset('master:'..userID,'active',1)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to activate account:',err)
  end
end

function userwrite:SubscribeToFilter(userID,filterID)
  local userID = userID or 'default'
  local red = util:GetUserWriteConnection()
  print('adding filter ',filterID, ' to ',userID)
  local ok, err = red:sadd('userfilters:'..userID, filterID)

  if not ok then
    util:SetKeepalive(red)
    ngx.log(ngx.ERR, 'unable to add filter to list: ',err)
    return
  end

  ok, err = red:hincrby('filter:'..filterID,'subs',1)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to incr subs: ',err)
  end

end

function userwrite:UnsubscribeFromFilter(userID, filterID)
  local red = util:GetUserWriteConnection()
  local ok, err = red:srem('userfilters:'..userID,filterID)
  if not ok then
    util:SetKeepalive(red)
    ngx.log(ngx.ERR, 'unable to remove filter from users list:',err)
    return
  end

  ok, err = red:hincrby('filter:'..filterID,'subs',-1)
  util:SetKeepalive(red)
  if not ok then
    ngx.log(ngx.ERR, 'unable to incr subs: ',err)
  end

end

return userwrite