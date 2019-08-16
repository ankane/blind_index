Mongoid.logger = $logger
Mongo::Logger.logger = $logger if defined?(Mongo::Logger)

Mongoid.configure do |config|
  config.connect_to "blind_index_test"
end

class User
  include Mongoid::Document

  field :email_ciphertext, type: String
  field :email_bidx, type: String
  field :email_ci_bidx, type: String
  field :email_binary_bidx, type: String
  field :first_name, type: String
  field :last_name, type: String
  field :initials, type: String # Mongoid doesn't have virtual attributes
  field :initials_bidx, type: String
  field :phone_ciphertext, type: String
  field :phone_bidx, type: String

  encrypts :email, :phone
end
