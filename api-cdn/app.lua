

local lapis = require("lapis")
local app = lapis.Application()
package.loaded.app = app
local date = require("date")
local util = require 'util'
local errorHandler = require 'middleware.errorhandler'
--https://github.com/bungle/lua-resty-scrypt/issues/1
local checksession = require 'middleware.checksession'
local config = require("lapis.config").get()
local markdown = require 'lib.markdown'



app:enable("etlua")
app.layout = require 'views.layout'
app.cookie_attributes = function(self)
  local expires = date(true):adddays(365):fmt("${http}")
  return "Expires=" .. expires .. "; Path=/; HttpOnly"
end



-- DEV ONLY
-- TODO move this to env
to_json = (require 'lapis.util').to_json
from_json = (require 'lapis.util').from_json

app:before_filter(function(self)
  checksession:Run(self)
end)

app:before_filter(function(self)

  self.enableAds = false

  self.GetFilterTemplate = util.GetFilterTemplate
  self.GetStyleSelected = util.GetStyleSelected
  self.filterStyles = util.filterStyles
  self.CalculateColor = util.CalculateColor
  self.TagColor = util.TagColor
  self.markdown = markdown
  self.UserHasFilter = util.UserHasFilter
  self.TimeAgo = util.TimeAgo
  self.Paginate = util.Paginate

end)

app.handle_error = errorHandler
app.handle_404 = function(self)
  ngx.log(ngx.NOTICE, 'Accessed unkown route: ',self.req.cmd_url)
  return {render = 'errors.404'}
end


-- Random stuff that doesnt go anywhere yet
app:get('createpage', '/nojs/create', function() return {render = 'createpage'} end)
app:get('about', '/about',function() return {render = true} end)


--TODO: change to this: https://gist.github.com/leafo/92ef8250f1f61e3f45ec
require 'tags'
require 'posts'
require 'frontpage'
require 'user'
require 'settings'
require 'messages'
require 'filters'
require 'comments'
require 'alerts'
require 'api'
require 'admin'
require 'search'
require 'images'

if config._name == 'development' then
  require 'auto':Register(app)
  require 'testing.perftest':Register(app)


  -- TESTING
  app:get('/test', function(request)
    local test = 'test: '
    test = test..(ngx.var.geoip_region or 'no region')
    test = test..(ngx.var.geoip_org or 'no org')
    test = test..(ngx.var.geoip_city or 'no city')
    test = test..(ngx.var.geoip_region_name or 'no region')
    test = test..ngx.var.remote_addr

    for k,v in pairs(request.req.headers) do
      if type(v) == 'string' then
        print(k, ' ', v)
      end
    end
    print('this')


    return test

  end)
end



return app
