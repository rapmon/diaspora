#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe UpdatesController do
  
  before do
    @user = Factory.create(:user)
    @user.aspect(:name => "lame-os")
    sign_in :user, @user
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
  
  
  describe 'user with valid token and valid person id should be authenticated. ' do
    it 'should authenticate user' do
      
      key = @user.encryption_key
      unix_time = Time.now.to_i.to_s
      unix_encrypted = key.private_encrypt(unix_time)
      unix_encrypted_base64 = Base64.encode64 unix_encrypted 
      unix_sig = unix_encrypted_base64.gsub("\n", "")
      
      dummyUrl = "get_updates"
      @params  = {:pid  => @user.person.id,:token => unix_sig }  
       get dummyUrl, @params
       response.body.should match(/Authenticated!/i)
    end
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