#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class UpdatesController < ApplicationController
  require File.join(Rails.root, 'app/models/user')
  require 'time'
  
  # filter-authentication if doing /updates/grab
  before_filter :authenticate_user!, :only => [:grab]

  
  # How many +/- seconds are allowed before we consider a token
  # invalid? 
  WINDOW_MARGIN_OF_ACCEPTANCE = 10

  def get_updates
    
    # authentication!
    # URL will be ...
    # /updates?id=PERSONID&timestamp=TIMESTAMP&token=TOKEN
    # ... where TOKEN = PRIVATE_KEY.encrypt(UNIX EPOCH TIME)
    # 

    # For testing purposes: if user goes to /update URL without anything else, provide them
    # ablity to jump in the recursive link loop to test functionality
    # 
    # If personid not set, but test is set, start them off 
    if params[:pid].nil? and !params[:test].nil?
      sig = unix_signature # the signature of time stamp signed by the sender's private key
      redirect_to "http://localhost:3000/updates?timestamp=asdf&pid=#{current_user.person._id}&test=1&&token=#{sig}"
      return
    end
    
    # conduct the test!
    # test simply shows 
    #   1) the URL of the current-second-unix-signature
    #   2) the decoded token of the current-page to verify it's really decoding
    if !params[:test].nil?  
      person = Person.find_by_id(params[:pid].to_s)
      
      sig = unix_signature
      s = "<a href=\"http://localhost:3000/updates?timestamp=asdf&pid=#{current_user.person._id}&test=1&token=#{sig}\">http://localhost:3000/updates?timestamp=asdf&pid=#{current_user.person._id}&test=1&token=#{sig}</a><br /><br /><br />"
      render :inline =>  s + unsign_token(person, params[:token])  
      return
    end
    
    person = Person.find_by_id(params[:pid])
    
    # If the authentication fails, render "Failed." for testing
    # purposes.
    if !person || !params[:token] || !user_authentic_token?(person, params[:token]) 
      if !person
        msg = "<div id =test> No person! Did you mean to test?  If so, add ?test=1 to your URL. </div>"
        msg  += "person id is: #{params[:pid]}"
        msg  += "person is: #{}"
        render :inline => msg
        return
      end
      
      if !params[:token]
        msg = "<h1>Failed Authentication, No token Provided.</h1><br />\n"
        render :inline => msg
        return
      end
      
      msg = "<h1>Failed Authentication.</h1><br />\n"
      msg += "Now is: #{Time.now.to_i.to_s}<br />\n"
      msg += "You is: #{unsign_token(person, params[:token])}<br />\n"
      msg += "Allowed Margin is: #{WINDOW_MARGIN_OF_ACCEPTANCE}<br />\n"
      msg += "Your Margin is: #{ (Time.now.to_i - unsign_token(person, params[:token]).to_i).abs }<br />\n"
      render :inline => msg
      return
    end
    
    msg = "<h1>Authenticated!</h1><br />\n"
    msg += "Now is: #{Time.now.to_i.to_s}<br />\n"
    msg += "You is: #{unsign_token(person, params[:token])}<br />\n"
    msg += "Allowed Margin is: #{WINDOW_MARGIN_OF_ACCEPTANCE}<br />\n"
    msg += "Your Margin is: #{ (Time.now.to_i - unsign_token(person, params[:token]).to_i).abs }<br />\n"
    render :inline => msg
    
    
    allposts = getListOfUpdatesSince(params[:timestamp])
    for newpost in allposts do 
      #send each post
      #see if the username does exist or not
      if current_user.isPostForPerson?(newpost, params[:pid])
        current_user.push_to_people(newpost, User.find_by_username(params[:pid]).person )  
      end
    end
  end 


  # go here when processing current_user requesting sync'ing / updates from friends
  def grab
    ## pseudocode of course...
    # friends = getAllFriends();
    # friends.each do | friend |
    # last_post_timestamp = getTimestampOfLastPostWeHaveFrom(friend);
    # html_response = http_get("http://#{friend.server_url}/updates"
    #                        + "?timestamp=#{last_post_timestamp}"
    #                        + "&id=#{current_user.person._id}"     ## NOTE: here, we *DO* use current_user
    #                        + "&token=#{unix_signature()}");       ##       b/c we're telling friend about ourselves
    
    friends = nil
    
    flash[:notice] = "Not yet implemented -- we're working on it!"
    redirect_to root_url
  end  
  
  def getListOfUpdatesSince(timestamp)
    
    latestUpdates = []
    current_user.visible_posts.each do |current_post|
      if Time.parse(timestamp) < current_post.created_at
        latestUpdates << current_post
        #latestUpdates << current_post.created_at
      end
    end
    latestUpdates
  end
  
  def user_authentic_token?(person, token)
    
    if !(person == nil || token== nil)
    # find out what time was passed to us, given the person
   
    requested_time = (unsign_token person, token).to_i
    
    # get the current unix-time
    current_time = Time.now.to_i
    
    # check to see it's within the margin of error
    difference = (current_time - requested_time).abs
    
    # return the value of this boolean expression
    # returns TRUE if the passed in token is within margin
    # returns FALSE if not within the window
    difference <= WINDOW_MARGIN_OF_ACCEPTANCE
    end
  end
  
  # grab the signed value of the unix-time, for generating update-tokens
  def unix_signature
    # get the current user's private key
    key = current_user.encryption_key
    
    # get the current unix epoch time 
    unix_time = Time.now.to_i.to_s
    
    # sign the current unix epoch time with the sender's private key
    unix_encrypted = key.private_encrypt(unix_time)
    
    # convert to base64 for URL-friendliness 
    unix_encrypted_base64 = Base64.encode64 unix_encrypted 
    
    # strip out the newlines for the final unix signature, for good measure and safety
    unix_sig = unix_encrypted_base64.gsub("\n", "")
  end
  
  def unsign_token(person, token)
    # token get string replaces "+" with " ", so replace them back
    signed_base64 = token.gsub(" ", "+")
    
    # decode from base64
    signed = Base64.decode64 signed_base64
    
    # get the public key of the person
    public_key = person.public_key
    
    # decrypt the signed token, and return it
    unsigned_token = public_key.public_decrypt(signed)
  end

end