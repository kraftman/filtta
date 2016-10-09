var userSettings = {};
var newPosts = {};
var maxPosts = 10;
var seenPosts = [];
var userID;

$(function() {
  userID = $('#userID').val()
  AddTagVoteListener();
  AddPostVoteListener();
  AddMenuHandler();
  AddFilterSearch();
  GetUserSettings();
  LoadKeybinds();
  LoadNewPosts();
  AddToSeenPosts();
})

function AddToSeenPosts(){
  $.each($('#posts').children(), function(k,v) {
    var postID = $(v).find('.postID').val()
    seenPosts.push(postID)
  })
  console.log(seenPosts)
}

function LoadNewPosts(startAt = 0, endAt = 100){
  $.getJSON('/api/user/'+userID+'/frontpage?startat=1&endat=100',function(data){
    console.log(data)
    if (data.status == 'success'){
      newPosts = data.data
      console.log(newPosts.length+ ' new posts got from server')
    }
  })
}


function OpenLink(e) {
  if ($(':focus').find(".post-link").length) {
    var url = $(':focus').find(".post-link").attr('href')
    console.log(url)
    window.open(url, '_blank');
    e.preventDefault();
  }
}


function OpenComments(e) {
  if ($(':focus').find(".comment-link").length) {
    var url = document.location.origin+$(':focus').find(".comment-link").attr('href')
    console.log(url)
    window.open(url, '_blank');
    e.preventDefault();
  }

}

function Upvote(e) {
  var upvoteButton = $(':focus').find('.postUpvote')
  if (upvoteButton.length) {
    VotePost.call(upvoteButton,e);
  }
}

function Downvote(e) {
  var downvoteButton = $(':focus').find('.postDownvote')
  if (downvoteButton.length) {
    VotePost.call(downvoteButton,e);
  }
}

function MoveFocus(e) {
  e.preventDefault();
  var thisPost = $(':focus')
  if (!thisPost.hasClass('post')) {
    return
  }
  var nextPost
  if (e.key == 'ArrowUp') {
    nextPost = thisPost.prev()
  } else if (e.key == 'ArrowDown') {
    nextPost = thisPost.next()
  } else {
    console.log(e.key)
  }

  if (nextPost.length) {
    nextPost.focus()
  }
}

function LoadKeybinds(){


  Mousetrap.bind('up', MoveFocus);
  Mousetrap.bind('down', MoveFocus);
  Mousetrap.bind("enter", OpenLink)
  Mousetrap.bind('space', OpenComments);
  Mousetrap.bind("right", Upvote)
  Mousetrap.bind("left", Downvote)

  $('#posts').children().first().focus();

}

var userFilters = {};

function GetUserSettings(){
  var userID = $('#userID').val()
  if (!userID) {
    return;
  }
  $.getJSON('/api/user/'+userID+'/settings',function(data){
    console.log(data)
    if (data.status == 'success'){
      userSettings = data.data
    }
  })
}


function ChangeFocus(value) {

  index = index + value;
  var numChildren = $('#posts').children().length -1
  index = Math.max(index, 0)
  index = Math.min(index, numChildren)
  $('#posts').children().eq(index).focus();
}

function UpdateSidebar(filters){
  var filterContainer  = $('.filterContainer')
  filterContainer.empty()
  $.each(filters.data, function(index,value){
    console.log(index,value)

    filterContainer.append(" \
    <ul> \
      <a href ='/f/"+value.name+"' class='filterbarelement'> \
        <span > "+value.name+"</span> \
      </a> \
    </ul> \
    ")
  })
}

function AddFilterSearch(){
  console.log('adding this')
  $('#filterSearch').on('input', function() {
    clearTimeout($(this).data('timeout'));
    var _self = this;
    $(this).data('timeout', setTimeout(function () {
      console.log('searching')

      if (_self.value.trim()){
        $.get('/api/filter/search/'+_self.value, {
            search: _self.value
        }, UpdateSidebar);
      } else {
        $.get('/api/user/filters', {
            search: _self.value
        }, UpdateSidebar);
      }
    }, 200));
  })
}

function AddMenuHandler(){
  $('#box-two').hide();
  $('#infoBoxLink').click(function(e){
    e.preventDefault();
    $('#box-one').show();
    $('#box-two').hide();
  })
  $('#filterBoxLink').click(function(e){
    e.preventDefault();
    $('#box-one').hide();
    $('#box-two').show();
  })
}

function GetFreshPost(){
  var newPost = newPosts.shift()
  while ($.inArray(newPost.id, seenPosts) != -1){

    console.log(newPost)
    if (newPost == null) {
      return
    }
    newPost = newPosts.shift()
  }
  return newPost
}

function LoadMorePosts(template){
  var newPost = template.clone()

  $(newPost).slideDown('fast')

  var postInfo = GetFreshPost()
  if (postInfo == null) {
    return
  }
  newPost.find('.postID').val(postInfo.id)
  newPost.find('.post-link').text(postInfo.title)
  $('#posts').append(newPost)

}

function VotePost(e){
  var className = $('.myclass').attr('class');

  e.preventDefault();
  var postID = $(this).parent().parent().children('.postID').val()
  var postHash = $(this).parent().parent().children('.postHash').val()

  if (userSettings.hideVotedPosts) {
    console.log('this')
    if ($.inArray(postID, seenPosts) == -1){
      seenPosts.push(postID)
    }
    console.log(userSettings.hideVotedPosts)
    var nextPost = $(this).parents('.post').next()
    if (nextPost.length) {
      nextPost.focus()
    }
    LoadMorePosts($(this).parents('.post'));
    $(this).parents('.post').slideUp('fast',function() {

      $(this).remove();
    })
  }

  var uri;
  if ($(this).hasClass('postUpvote')){
    uri = '/api/post/'+postID+'/upvote?hash='+postHash
  } else {
    uri = '/api/post/'+postID+'/downvote?hash='+postHash
  }

  $.get(uri,function(data){
    console.log(data);
  })
}

function AddPostVoteListener(){
  $(".postUpvote").click(VotePost)
  $(".postDownvote").click(VotePost)
}

function AddTagVoteListener(){
  $(".upvote").click(function(){
    var tagCount = $(this).parent().find('.tagcount')
    tagCount.text(Number(tagCount.text())+1)
    var tagID = $(this).parent().data('id')
    var postID = $('#postID').val()
    $.get('/post/upvotetag/'+tagID+'/'+postID,function(data){
      console.log(data);
    })
  })
  $(".downvote").click(function(){
    var tagCount = $(this).parent().find('.tagcount')
    tagCount.text(Number(tagCount.text())-1)
    var tagID = $(this).parent().data('id')
    var postID = $('#postID').val()
    $.get('/post/downvotetag/'+tagID+'/'+postID,function(data){
      console.log(data);
    })
  })
}
