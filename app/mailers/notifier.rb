class Notifier < ActionMailer::Base
  default :from => "no-reply@joindiaspora.com"
  
  def new_request(recipient, sender)
    @receiver = recipient
    @sender = sender
<<<<<<< HEAD
    mail(:to => "#{recipient.real_name} <#{recipient.email}>",
    :subject => "new Diaspora* friend request from #{@sender.real_name}")
  end
=======
    mail(:to => recipient.email) do |format|
      format.text { render :text => "This is text!" }
      format.html { render :text => "<h1>#{@receiver.person.profile.first_name}This is HTML</h1>" }
    end
  end


>>>>>>> started the new invitation email
end
