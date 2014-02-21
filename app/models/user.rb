class User < ActiveRecord::Base
  acts_as_authentic do |c|
    c.require_password_confirmation = false
    c.validate_email_field = false
    c.validates_length_of_password_field_options = { :minimum => 1, :if => :should_validate? }
    c.ignore_blank_passwords = true
  end
end
