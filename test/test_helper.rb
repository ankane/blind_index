require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "scrypt"

BlindIndex.master_key = BlindIndex.generate_key

$logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)

if defined?(Mongoid)
  require_relative "support/mongoid"
else
  require_relative "support/active_record"
end

class User
  # must come before blind_index
  before_validation :set_initials, if: -> { changes.key?(:first_name) || changes.key?(:last_name) }

  blind_index :email
  blind_index :email_ci, algorithm: :scrypt, attribute: :email, expression: ->(v) { v.try(:downcase) }
  blind_index :email_binary, algorithm: :argon2, key: BlindIndex.generate_key, attribute: :email, encode: defined?(Mongoid) # can't get binary working with Mongoid
  blind_index :initials, key: BlindIndex.generate_key, size: 16
  blind_index :phone

  validates :email, uniqueness: true
  validates :email_ci, uniqueness: true

  def set_initials
    self.initials = [first_name.first, last_name.first].join
  end
end

class ActiveUser < User
  blind_index :child, key: BlindIndex.generate_key
end
