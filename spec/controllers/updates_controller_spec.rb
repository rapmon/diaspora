#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe UpdatesController do
  
  let(:user) { Factory.create :user }
  let(:user2) { Factory.create :user }
  let(:aspect1) { user.aspect(:name => "foo") }
  let(:aspect2) { user2.aspect(:name => "far") }
  before do
    sign_in :user, user
  end
  
  
  describe 'get timestamp url' do
    it 'should get the timestamp from the url once ping is made' do
      dummyUrl = "updates?timestamp=blah&uid=pop"
      put("get_updates", "request" => {
      "destination_url" => dummyUrl
      }
      )
       response.should be_success
      #right now it should fail
    end
  end
  
  describe 'check correct controller' do
    it 'should route to the correct controller (updates controller)' do
      dummyUrl = "get_updates"
      get dummyUrl
      assert_recognizes({:controller => "updates", :action => "get_updates"}, "/updates") 
      #right now it should fail
    end
  end
  
  
 end