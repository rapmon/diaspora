
require 'spec_helper'

describe Notifier do

<<<<<<< HEAD
  let!(:user) {Factory.create :user}
  let!(:person) {Factory.create :person}
  let!(:request_mail) {Notifier.new_request(user, person)}
=======
  let(:user) {Factory.create :user}
  let(:person) {Factory.create :person}
  let(:request_mail) {Notifier.new_request(user, person)}
>>>>>>> started the new invitation email

  describe "#new_request" do
    it 'goes to the right person' do
      request_mail.to.should == [user.email]
    end

    it 'has the receivers name in the body' do
<<<<<<< HEAD
      request_mail.body.encoded.include?(user.person.profile.first_name).should be true
    end


    it 'has the name of person sending the request' do
      request_mail.body.encoded.include?(person.real_name).should be true
=======
      request_mail.body.encoded.includes?(user.first_name).should be true
>>>>>>> started the new invitation email
    end
  end
end
