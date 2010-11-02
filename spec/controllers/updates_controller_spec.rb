#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'
 
describe UpdatesController do
  
  before do
    
    @user    = Factory.create(:user)
    @aspect11  = @user.aspect(:name => "Work1")
    @aspect12 = @user.aspect(:name => "Fun1")
    
    @user2   = Factory.create(:user)
    @aspect21 = @user2.aspect(:name => "Work2")
    
    @user3 =   Factory.create(:user)
    @aspect31 = @user3.aspect(:name => "Fun3")
       
    friend_users(@user,@aspect11, @user2, @aspect21)  #users 1 and 2 related by work
    friend_users(@user,@aspect12, @user3, @aspect31)  #users 1 and 3 related by fun
    sign_in :user, @user
    sign_in :user, @user2
     
  end
  
  
  describe 'user updating without an id or token should not be allowed' do
    it 'should show the error as No Person and suggest synchronization' do
      dummyUrl = "updates"
      put("get_updates", "request" => {
      "destination_url" => dummyUrl
      }
      )
      response.body.should match(/No Person/i)
    end
  end
  
  describe 'user udpating with correct person id and no token should not be authenticated' do
    it 'should deny access' do
     
       dummyUrl = "get_updates"
       get dummyUrl,:pid  => @user.person.id
       response.body.should match(/Failed Authentication/i)
    end
  end
  
  
  describe 'user with valid token and valid person id should be authenticated and posts should
     be sent to correct users . ' do
    it 'should authenticate user' do
      
      key = @user.encryption_key
      unix_time = Time.now.to_i.to_s
      unix_encrypted = key.private_encrypt(unix_time)
      unix_encrypted_base64 = Base64.encode64 unix_encrypted 
      unix_sig = unix_encrypted_base64.gsub("\n", "")
       sign_in :user, @user3
      dummyUrl = "get_updates"
      @params  = {:pid  => @user.person.id,:token => unix_sig }  
       get dummyUrl, @params
       response.body.should match(/Authenticated!/i)
   end
   
   it 'should post' do
     status_message = @user.post( :status_message, :message => "This is work related", :to => @aspect11.id )
     @user.visible_posts.count.should eq(1)
     
   end
   
   it 'should sent posts to correct users' do
    
      #user1 posts in Work aspect 
      status_message = @user.post( :status_message, :message => "This is work related", :to => @aspect11.id )
      status_message.save
#      @user2.receive   status_message.to_diaspora_xml, @user.person
 #     @user3.receive   status_message.to_diaspora_xml, @user.person
      
      @aspect11.reload
      
      key = @user.encryption_key
      unix_time = Time.now.to_i.to_s
      unix_encrypted = key.private_encrypt(unix_time)
      unix_encrypted_base64 = Base64.encode64 unix_encrypted 
      unix_sig = unix_encrypted_base64.gsub("\n", "")
      
      dummyUrl = "get_updates"
      @params  = {:pid  => @user2.person.id,:token => unix_sig, :timestamp => "2007-10-16T19:45:35Z" }  
       get dummyUrl, @params    
       
       #now user2 should have got it
       response.body.should match(/#{@user2.person.id}/)
   end
   
   
   it 'should not send posts to incorrect users/aspects' do
    
      #user1 posts in Work aspect 
      status_message = @user.post( :status_message, :message => "This is work related", :to => @aspect11.id )
      status_message.save
#      @user2.receive   status_message.to_diaspora_xml, @user.person
 #     @user3.receive   status_message.to_diaspora_xml, @user.person
      
      @aspect11.reload
      
      key = @user.encryption_key
      unix_time = Time.now.to_i.to_s
      unix_encrypted = key.private_encrypt(unix_time)
      unix_encrypted_base64 = Base64.encode64 unix_encrypted 
      unix_sig = unix_encrypted_base64.gsub("\n", "")
      
      dummyUrl = "get_updates"
     
      @params  = {:pid  => @user3.person.id,:token => unix_sig, :timestamp => "2007-10-16T19:45:35Z" }  
       get dummyUrl, @params    
       
       #now user2 should have got it
       response.body.should_not match(/#{@user3.person.id}/)
   end

end


  describe 'synchronize button' do
    it 'should pulled correct posts upon hitting the synchronize button ' do
      
      #user1 posts
      status_message = @user.post( :status_message, :message => "Hmphhhh...work again", :to => @aspect11.id )
      status_message.save
       @aspect11.reload
       
       #simulating user2 requesting
       
       #sleep to expire the timestamp
      sleep 15
      friends = @user2.friends
      html_response = ""
      big_string = ""
        aspect = @user2.aspects(:all)
        recent_post_time = nil
        all_posts = []
        aspect.each do | a |
          a.posts.each do | p |
            if recent_post_time.nil? or p.created_at > recent_post_time
              recent_post_time = p.created_at
            end
          end
        end
    #recent_post_time is the latest post time of the requester i.e. user2
    
    #unix sign
    
      key = @user.encryption_key
      unix_time = Time.now.to_i.to_s
      unix_encrypted = key.private_encrypt(unix_time)
      unix_encrypted_base64 = Base64.encode64 unix_encrypted 
      unix_sig = unix_encrypted_base64.gsub("\n", "")
    
      dummyUrl = "get_updates"
      
      
     friends.each do | friend | 
       @params  = {:pid  => @user2.person._id,:token => unix_sig, :timestamp => recent_post_time }  
       get dummyUrl, @params    
   end
   
   #after this, the user user2 should have 1 post in its visible posts
    @user2.aspects[0].posts.count.should eq(1)
   
   
  end
  
  describe 'user with expired token and valid person id should not be authenticated. ' do
    it 'should not authenticate user' do
      
      key = @user.encryption_key
      unix_time = Time.now.to_i.to_s
      unix_encrypted = key.private_encrypt(unix_time)
      unix_encrypted_base64 = Base64.encode64 unix_encrypted 
      unix_sig = unix_encrypted_base64.gsub("\n", "")
      
      sleep 20
      
      dummyUrl = "get_updates"
      @params  = {:pid  => @user.person.id,:token => unix_sig }  
       get dummyUrl, @params
       response.body.should match(/Failed Authentication/i)
    end
  end
 
  
  #describe 'get timestamp url' do
   # it 'should get the timestamp from the url once ping is made' do
    #  dummyUrl = "updates?id=blah"
     # put("get_updates", "request" => {
     # "destination_url" => dummyUrl
     # }
     # )
     #  response.should be_success
      #right now it should fail
   # end
 # end
  
  #describe 'check correct controller' do
   # it 'should route to the correct controller (updates controller)' do
    #  dummyUrl = "get_updates"
     # get dummyUrl
      #assert_recognizes({:controller => "updates", :action => "get_updates"}, "/updates") 
      #right now it should fail
    #end
  #end
  
  end
 end