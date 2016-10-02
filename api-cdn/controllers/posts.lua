

local api = require 'api.api'
local util = require("lapis.util")

local from_json = util.from_json
local to_json = util.to_json

local m = {}

local respond_to = (require 'lapis.application').respond_to
local trim = util.trim


local function CreatePost(self)
  print(self.params.selectedtags)
  local selectedTags = from_json(self.params.selectedtags)

  if trim(self.params.link) == '' then
    self.params.link = nil
  end

  local info ={
    title = self.params.title,
    link = self.params.link,
    text = self.params.text,
    createdBy = self.session.userID,
    tags = selectedTags
  }

  local ok, err = api:CreatePost(self.session.userID, info)

  if ok then
    return {json = ok}
  else
    ngx.log(ngx.ERR, 'error from api: ',err or 'none')
    return {json = err}
  end

end

local function GetPost(self)
  local sortBy = self.params.sort or 'best'
  sortBy = sortBy:lower()

  local postID = self.params.postID
  if #postID < 10 then
    postID = api:ConvertShortURL(postID) or postID
  else
    local post = api:GetPost(self.session.userID, postID)
    if post.shortURL then
      return { redirect_to = self:url_for("viewpost",{postID = post.shortURL}) }
    end
  end

  local comments = api:GetPostComments(self.session.userID, postID,sortBy)

  for _,v in pairs(comments) do
    -- one of the 'comments' is actually the postID
    -- may shift this to api later
    if v.id and self.session.userID then
      v.commentHash = ngx.md5(v.id..self.session.userID)
    end
  end

  self.comments = comments

  local post,err = api:GetPost(self.session.userID, postID)
  print(to_json(post))

  if not post then
    if type(err) == 'number' then
      return {status = err}
    end
    return err
  end

  for _,v in pairs(post.tags) do
    if v.name:find('^meta:sourcePost:') then
      post.containsSources = true
      local postID = v.name:match('meta:sourcePost:(%w+)')
      if postID then
        print(postID)
        local parentPost = (api:GetPost(self.session.userID, postID))
        print(to_json(parentPost))
        if v.name and parentPost.title then
          v.fakeName = parentPost.title
          v.postID = postID
        end
      end
    end
  end

  self.filters = api:GetFilterInfo(post.filters)

  if self.session.userID then
    post.hash = ngx.md5(post.id..self.session.userID)
    post.userHasVoted = api:UserHasVotedPost(self.session.userID, post.id)
    self.userLabels = api:GetUserInfo(self.session.userID).userLabels
  end

  self.post = post

  self.GetColorForDepth =function(_,child, depth)
    depth = depth or 1
    if not child then
      return ''
    end

    local username = child.username
    local colors = { '#ffcccc', '#ccddff', '#ccffcc', '#ffccf2','lightpink','lightblue','lightyellow','lightgreen','lightred'};
    local sum = 0

    for i = 1, #username do
      sum = sum + (username:byte(i))
    end

    sum = sum % #colors + 1

    if false then
      return 'style="background: '..colors[sum]..';"'
    end

    function DEC_HEX(IN)
      local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
      while IN>0 do
          I=I+1
          IN,D=math.floor(IN/B),(IN % B)+1
          OUT=string.sub(K,D,D)..OUT
      end
      return OUT
    end

    depth = 4 + depth*2
    depth = DEC_HEX(depth)
    print(depth )
    depth = '#'..depth..depth..depth..depth..depth..depth
    return 'style="background: '..depth..';"'
  end

  self.GetColorForName = function(_,username)

    local colors = { '#992244', '#442211', '#662288','darkpink','darkblue','darkyellow','darkgreen','darkred'};
    local sum = 0

    for i = 1, #username do
      sum = sum + (username:byte(i))
    end

    sum = sum % #colors + 1

      return 'style="color: '..colors[sum]..';"'

  end

  return {render = 'post.view'}
end

local function CreatePostForm(self)
  if not self.session.userID then
    return { redirect_to = self:url_for("login") }
  end

  local tags = api.GetAllTags(api)

  self.tags = tags

  return { render = 'post.create' }
end




local function UpvoteTag(self)

  api:VoteTag(self.session.userID, self.params.postID, self.params.tagID, 'up')
  return 'meep'

end

local function DownvoteTag(self)
  api:VoteTag(self.session.userID, self.params.postID, self.params.tagID, 'down')
  return 'meep'

end

local function HashIsValid(self)
  --print(self.params.postID, self.session.userID)
  local realHash = ngx.md5(self.params.postID..self.session.userID)
  if realHash ~= self.params.hash then
    ngx.log(ngx.ERR, 'hashes dont match!')
    return false
  end
  return true
end


local function UpvotePost(self)
  if not HashIsValid(self) then
    return 'invalid hash'
  end
  local ok, err = api:VotePost(self.session.userID, self.params.postID, 'up')
  if ok then
    return { redirect_to = self:url_for("home") }
  else
    return 'fail: ', err
  end
end



local function DownvotePost(self)
  if not HashIsValid(self) then
    return 'invalid hash'
  end
  local ok, err = api:VotePost(self.session.userID, self.params.postID,'down')
  if ok then
    return { redirect_to = self:url_for("home") }
  else
    return 'fail: ', err
  end
end

local function GetIcon(self)
  if not self.params.postID then
    return 'nil'
  end

  local post = api:GetPost(self.params.postID)
  if not post.icon then
    return ''
  end
  self.post = post
  if not type(post.icon) == 'string' then
    return ''
  end
  print(post.icon)

  self.iconData = ngx.decode_base64(post.icon)

  return {layout = 'layout.blanklayout',content_type = 'image'}


end

local function AddSource(self)
  print('adding source')
  local sourceURL = self.params.sourceurl
  local userID = self.session.userID
  if not sourceURL then
    return 'no url given!'
  elseif not userID then
    return 'you must be logged in to do that!'
  end

  local ok, err = api:AddSource(userID, self.params.postID, sourceURL)
  if ok then
    return 'success!'
  else
    return 'error: '..err
  end

end

local function AddTag(self)
  local tagName = self.params.addtag
  local userID = self.session.userID
  local postID = self.params.postID

  local ok, err = api:AddPostTag(userID, postID, tagName)
  if ok then
    return { redirect_to = self:url_for("viewpost",{postID = self.params.postID}) }
  else
    print('failed: ',err)
    return 'failed: '..err
  end

end

local function EditPost(self)

  if self.params.sourceurl then
    return AddSource(self)
  end

  if self.params.addtag then
    return AddTag(self)
  end

  local post = {
    id = self.params.postID,
    title = self.params.posttitle,
    text = self.params.posttext
  }

  local ok,err = api:EditPost(self.session.userID, post)
  if ok then
    return { redirect_to = self:url_for("viewpost",{postID = self.params.postID}) }
  else
    return 'fail: '..err
  end


end

local function DeletePost(self)
  local confirmed = self.params.confirmdelete

  if not confirmed then
    return {render = 'post.confirmdelete'}
  end

  local postID = self.params.postID
  local userID = self.params.userID

  local ok, err = api:DeletePost(userID, postID)

  if ok then
    return 'success'
  else
    return 'failed: '..err
  end

end

local function SubscribePost(self)
  local ok, err = api:SubscribePost(self.session.userID,self.params.postID)
  if ok then
    return { redirect_to = self:url_for("viewpost",{postID = self.params.postID}) }
  else
    return 'error subscribing: '..err
  end
end

function m:Register(app)
  app:match('newpost','/post/new', respond_to({
    GET = CreatePostForm,
    POST = CreatePost
  }))
  app:match('viewpost','/post/:postID', respond_to({
    GET = GetPost,
    POST = EditPost,
  }))
  app:match('deletepost','/post/delete/:postID', respond_to({
    GET = DeletePost,
    POST = DeletePost,
  }))

  app:get('upvotetag','/post/upvotetag/:tagID/:postID',UpvoteTag)
  app:get('downvotetag','/post/downvotetag/:tagID/:postID',DownvoteTag)
  app:get('upvotepost','/post/:postID/upvote', UpvotePost)
  app:get('downvotepost','/post/:postID/downvote', DownvotePost)
  app:get('geticon', '/icon/:postID', GetIcon)
  app:get('subscribepost', '/post/:postID/subscribe', SubscribePost)

end

return m