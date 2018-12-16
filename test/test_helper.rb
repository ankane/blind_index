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
  t.string :encrypted_first_name
  t.string :encrypted_first_name_iv
  t.string :encrypted_last_name
  t.string :encrypted_last_name_iv
  t.string :encrypted_initials_bidx
end

class User < ActiveRecord::Base
  attribute :initials, ActiveRecord::Type::String.new if ActiveRecord::VERSION::MAJOR >= 5

  before_validation :set_initials, if: -> { changes.key?(:first_name) || changes.key?(:last_name) }

  attr_encrypted :email, key: SecureRandom.random_bytes(32)
  attr_encrypted :first_name, key: SecureRandom.random_bytes(32)
  attr_encrypted :last_name, key: SecureRandom.random_bytes(32)

  blind_index :email, key: SecureRandom.random_bytes(32)
  blind_index :email_ci, algorithm: :scrypt, key: SecureRandom.random_bytes(32), attribute: :email, expression: ->(v) { v.try(:downcase) }
  blind_index :email_binary, algorithm: :argon2, key: SecureRandom.random_bytes(32), attribute: :email, encode: false
  blind_index :initials, key: SecureRandom.random_bytes(32), size: 16

  validates :email, uniqueness: true
  validates :email_ci, uniqueness: true

  def set_initials
    self.initials = [first_name.first, last_name.first].join
  end

  # ensure custom method still works
  def read_attribute_for_validation(key)
    super
  end
end

class ActiveUser < User
  blind_index :child, key: SecureRandom.random_bytes(32)
end
