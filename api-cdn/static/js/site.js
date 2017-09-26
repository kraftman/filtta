

// all the base site js for the sidebar, topbar, etc


var $ = require('jquery');

var validate = require('validate.js');

var TagVoteListener = function(userID, userSettings) {
  this.userID = userID;
  this.userSettings = userSettings;
};

TagVoteListener.prototype = function() {

  var load = function(userID){
    addMenuListener.call(this);
    addInfoBar.call(this);
    //hideRecapchta.call(this);
    randomCrap.call(this);
    togglePosts.call(this);
  },
  togglePosts = function() {
    $('.filter-topbar').click(function(e){
      if ($(e.currentTarget).hasClass('.filter-topbar')) {
        $(e.currentTarget).parent().find('.filter-body').toggle()
      }
    })
  },
  randomCrap = function() {
    $('.form-login').submit(function(e){
      e.preventDefault()
      var email = $('.register-box').val().replace(' ', '')
      if (!email) {
        window.location.replace('/login');
      };
      var constraints = {
        from: {
          email: true
        }
      };


      var isInvalid = validate({from: email}, constraints);
      if (isInvalid) {
        window.alert('Invalid email!');
        return false;
      }
      grecaptcha.execute();


      return false;
    });

    $('.post-full-topbar').click(function(e){
      console.log(e.currentTarget)
      $(e.currentTarget).parent().find('.linkImg').toggle()
    })

    $('.post').hover(function(e){
      $(e.target).children('.post-full-bottombar').show();
      //$(e.target).find('.post-filters').show();
    })

    $('.post').focusout(function(e){
      $(e.target).children('.post-full-bottombar').hide();
      //$(e.target).find('.post-filters').hide();
    })
  },

  addInfoBar = function(){
    $('.infobar-title').click(function(e){
      $('.infobar-body').toggle()
      e.preventDefault()
    })
  },
  // hideRecapchta = function() {
  //   $('.form-login').focusin(function(){
  //     $('.form-login > div').show()
  //   })
  //
  //   $('.form-login').focusout(function(){
  //     $('.form-login > div').hide();
  //   })
  //
  //   $('.g-recaptcha').prop('disabled',true)
  // },

  addMenuListener = function() {
    $('.settings-link').click(function(e){
      var settingsMenu = $('.settings-menu')
      settingsMenu.toggle()
      // settingsMenu.focus()
      // settingsMenu.focusout(function(e){
      //   if ($(e.relatedTarget).parents('.settings-menu').length){
      //
      //   } else {
      //     settingsMenu.hide()
      //   }
      // })

      e.preventDefault();
    })
  };


  return {
    load: load,
  };
}();

module.exports = TagVoteListener;
