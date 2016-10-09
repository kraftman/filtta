
local api = require 'api.api'

local m = {}





local function FrontPage(self)
  self.pageNum = self.params.page or 1
  local range = 10*(self.pageNum-1)
  local filter = self.req.parsed_url.path:match('/(%w+)$')

  self.posts = api:GetUserFrontPage(self.session.userID or 'default',filter,range, range+10)

  --print(to_json(self.posts))

  --defer until we need it
  if self:GetFilterTemplate():find('filtta') then
    for _,post in pairs(self.posts) do
      local comments =api:GetPostComments(self.session.userID, post.id, 'best')
      _, post.topComment = next(comments[post.id].children)

      if post.topComment then
        print(post.topComment.text)
      end
    end
  end

  if self.session.userID then
    for _,v in pairs(self.posts) do
      if v.id then
        v.hash = ngx.md5(v.id..self.session.userID)
      end
    end
    self.userInfo = api:GetUser(self.session.userID)
  end

  -- if empty and logged in then redirect to seen posts
  if not self.posts or #self.posts == 0 then
    if filter ~= 'seen' then -- prevent loop
      --return { redirect_to = self:url_for("seen") }
    end
  end



  return {render = 'frontpage'}
end

function m:Register(app)
  app:get('home','/',FrontPage)
  app:get('new','/new',FrontPage)
  app:get('best','/best',FrontPage)
  app:get('seen','/seen',FrontPage)
end

return m
