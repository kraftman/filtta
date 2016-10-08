
local CONFIG_CHECK_INTERVAL = 10

local config = {}
config.__index = config
config.http = require 'lib.http'
config.cjson = require 'cjson'

local redisRead = require 'api.redisread'
local redisWrite = require 'api.rediswrite'
local cache = require 'api.cache'
local tinsert = table.insert
local to_json = (require 'lapis.util').to_json
local from_json = (require 'lapis.util').from_json


function config:New(util)
  local c = setmetatable({},self)
  c.util = util
  c.lastUpdate = ngx.now()*1000

  return c
end

function config.Run(_,self)
  local ok, err = ngx.timer.at(CONFIG_CHECK_INTERVAL, self.Run, self)
  if not ok then
    if not err:find('process exiting') then
      ngx.log(ngx.ERR, 'WARNING: unable to reschedule postupdater: '..err)
    end
  end

  -- no need to lock since we should be grabbing a different one each time anyway
  self:InvalidateCache()
	self:TrimInvalidations()

end

function config:MilliSecondTime()
	return ngx.now()*1000 --milliseconds
end

function config:TrimInvalidations()
	--delete invalidations older than time - 10 minutes
	local ok, err = self.util:GetLock('TrimCacheInvalidations', 100)
	if not ok then
		print('couldnt get lock: ',err)
		return
	end
	local cutOff = self:MilliSecondTime() - 10*60*1000
	ok, err = redisWrite:RemoveInvalidations(cutOff)
	if not ok then
		print('error trimming: ',err)
	end
end

function config:InvalidateCache()
  -- we want this to run on all workers so dont use locks

  local timeNow = self:MilliSecondTime()

  local ok, err = redisRead:GetInvalidationRequests(self.lastUpdate, timeNow)
  if not ok then
    return
  end
  for k,v in pairs(ok) do
    v = from_json(v)
    cache:PurgeKey(v)
  end

  self.lastUpdate = timeNow

end

return config
