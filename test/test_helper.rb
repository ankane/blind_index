require "bundler/setup"
require "active_record"
require "attr_encrypted"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "scrypt"
require "argon2"

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

if ENV["VERBOSE"]
  ActiveRecord::Base.logger = ActiveSupport::Logger.new(STDOUT)
end

ActiveRecord::Migration.create_table :users do |t|
  t.string :encrypted_email
  t.string :encrypted_email_iv
  t.string :encrypted_email_bidx
  t.string :encrypted_email_ci_bidx
  t.binary :encrypted_email_binary_bidx
end

class User < ActiveRecord::Base
  attr_encrypted :email, key: SecureRandom.random_bytes(32)

  blind_index :email, key: SecureRandom.random_bytes(32)
  blind_index :email_ci, algorithm: :scrypt, key: SecureRandom.random_bytes(32), attribute: :email, expression: ->(v) { v.try(:downcase) }
  blind_index :email_binary, algorithm: :argon2, key: SecureRandom.random_bytes(32), attribute: :email, encode: false

  validates :email, uniqueness: true
  validates :email_ci, uniqueness: true

  # ensure custom method still works
  def read_attribute_for_validation(key)
    super
  end
end

class ActiveUser < User
  blind_index :child, key: SecureRandom.random_bytes(32)
end
