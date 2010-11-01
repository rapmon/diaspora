#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class UpdatesController < ApplicationController
  require File.join(Rails.root, 'lib/diaspora/ostatus_builder')
  require File.join(Rails.root, 'lib/diaspora/exporter')
  require File.join(Rails.root, 'lib/diaspora/importer')
  require File.join(Rails.root, 'lib/collect_user_photos')
  require File.join(Rails.root, 'app/models/user')
  require 'time'
  before_filter :authenticate_user!, :except => [:new, :create, :public, :import]

  
  def get_updates 
    #let's get the person_id and forget about authentication for a while
    # @updates = getHashOfUpdatesSince(:timestamp);
    
    # authentication!
    # URL will be ...
    # /updates?personid=PERSONID&timestamp=TIMESTAMP&token=TOKEN
    # ... where TOKEN = PRIVATE_KEY.encrypt(UNIX EPOCH TIME)
    # 
    
    # If the authentication fails, render "Failed." for testing
    # purposes.
    
    person = Person.find_by_id(params[:personid])
    
    sig = unix_signature
    
    s = "<a href=\"http://localhost:3000/updates?timestamp=asdf&personid=4cc3d4c627391054b3000005&token=#{sig}\">http://localhost:3000/updates?timestamp=asdf&personid=4cc3d4c627391054b3000005&token=#{sig}</a><br /><br /><br />"
    
    render :inline => s + user_authentic_token?(person, params[:token])  
    
    return
    
    
    if !person || !user_authentic_token?(person, params[:token])
      render :inline => "Failed."
      
      
      person.public_key.public_decrypt(Base64.decode64 params[:token].gsub(" ", "+"))
      
      
      
      return
    end
    
    allposts = getListOfUpdatesSince(params[:timestamp])
    
    for newpost in allposts do 
      #send each post
      #see if the username does exist or not
        
      if current_user.isPostForPerson?(newpost, params[:personid])
        render :json => current_post
        current_user.push_to_people(newpost, User.find_by_username(params[:personid]).person )  
      end
    end
    
    #render :json => allposts
    #render :json => current_user.person.id
    #render :nothing => true # will render nothing when we want it to...
    render :inline => "Success."
  end 


  
  private
  
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
    ### to play with the encryption / decryption...
    #
    #        time = Time.now.to_i.to_s
    #        plain = "plain: " + time
    #        cipher = "cipher: " + person.encrypt(plain)
    #        #decr = "decr: " + current_user.aes_decrypt(person.encrypt(plain), current_user.gen_aes_key)
    #        decr = "decr: " + current_user.decrypt (person.encrypt(plain))
    #        final = plain + "<br />" + cipher + "<br />" + decr + "<br />"
    #        render :inline => final
    
    # token get string replaces "+" with " ", so replace them back
    signed = token.gsub(" ", "+")
    
    result = person.public_key.public_decrypt(Base64.decode64 signed)
    
    result
  end
  
  # grab the signed value of the unix-time, for generating update-tokens
  def unix_signature
    # get the current user's private key
    key = current_user.encryption_key
    
    # get the current unix epoch time 
    unix_time = Time.now.to_i.to_s
    
    # sign the current unix epoch time with my private key
    unix_encrypted = key.private_encrypt(unix_time)
    
    # convert to base64 for URL-friendliness 
    unix_encrypted_base64 = Base64.encode64 unix_encrypted 
    
    # strip out the newlines for the final unix signature, for good measure and safety
    unix_sig = unix_encrypted_base64.gsub("\n", "")
  end
  
  # everything after this is unneeded -- just copied/pasted for the example
  def edit
    @aspect  = :user_edit
    @user    = current_user
    @person  = @user.person
    @profile = @user.person.profile
    @photos  = current_user.visible_posts(:person_id => current_user.person.id, :_type => 'Photo').paginate :page => params[:page], :order => 'created_at DESC'

    @fb_access_url = MiniFB.oauth_url(FB_APP_ID, APP_CONFIG[:pod_url] + "services/create",
                                      :scope=>MiniFB.scopes.join(","))
  end

  def update
    @user = current_user
    params[:user].delete(:password) if params[:user][:password].blank?
    params[:user].delete(:password_confirmation) if params[:user][:password].blank? and params[:user][:password_confirmation].blank?

    if params[:user][:password] && params[:user][:password_confirmation]
      if @user.update_attributes(:password => params[:user][:password], :password_confirmation => params[:user][:password_confirmation])
        flash[:notice] = "Password Changed"
      else
        flash[:error] = "Password Change Failed"
      end
    else
      prep_image_url(params[:user])
      if @user.update_profile params[:user][:profile]
        flash[:notice] = "Profile updated"
      else
        flash[:error] = "Failed to update profile"
      end
    end
    redirect_to edit_user_path(@user)

  end

  def destroy
    current_user.destroy
    sign_out current_user
    flash[:notice] = t('user.destroy')
    redirect_to root_path
  end

  def public
    user = User.find_by_username(params[:username])

    if user
      director = Diaspora::Director.new
      ostatus_builder = Diaspora::OstatusBuilder.new(user)

      render :xml => director.build(ostatus_builder), :content_type => 'application/atom+xml'
    else
      flash[:error] = "User #{params[:username]} does not exist!"
      redirect_to root_url
    end
  end

  def export
    exporter = Diaspora::Exporter.new(Diaspora::Exporters::XML)
    send_data exporter.execute(current_user), :filename => "#{current_user.username}_diaspora_data.xml", :type => :xml
  end

  def export_photos
    tar_path = PhotoMover::move_photos(current_user)
    send_data( File.open(tar_path).read, :filename => "#{current_user.id}.tar" )
  end

  def invite
    User.invite!(:email => params[:email])
  end
  
  
  def import
    xml = params[:upload][:file].read

    params[:user][:diaspora_handle] = 'asodij@asodij.asd'


    begin
      importer = Diaspora::Importer.new(Diaspora::Parsers::XML)
      importer.execute(xml, params[:user])
      flash[:notice] = "hang on a sec, try logging in!"

    rescue Exception => e
      flash[:error] = "Derp, something went wrong: #{e.message}"
    end

      redirect_to new_user_registration_path
    #redirect_to user_session_path
  end

end