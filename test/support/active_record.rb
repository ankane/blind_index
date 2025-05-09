ActiveRecord::Base.logger = $logger
ActiveRecord::Migration.verbose = ENV["VERBOSE"]

adapter = ENV["ADAPTER"] || "sqlite"
case adapter
when "sqlite"
  ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
when "postgresql"
  ActiveRecord::Base.establish_connection adapter: "postgresql", database: "blind_index_test"
when "mysql"
  ActiveRecord::Base.establish_connection adapter: "mysql2", database: "blind_index_test"
when "trilogy"
  ActiveRecord::Base.establish_connection adapter: "trilogy", database: "blind_index_test", host: "127.0.0.1"
else
  raise "Unknown adapter: #{adapter}"
end

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :email_ciphertext
    t.string :email_bidx, index: {unique: true}
    t.string :email_ci_bidx, index: {unique: true}
    t.binary :email_binary_bidx
    t.string :first_name_ciphertext
    t.string :last_name_ciphertext
    t.string :initials_bidx
    t.string :encrypted_phone
    t.string :encrypted_phone_iv
    t.string :phone_bidx
    t.string :city_ciphertext
    t.string :city_bidx_v2
    t.string :city_bidx_v3
    t.string :region_ciphertext
    t.string :region_bidx
    t.references :group
  end

  create_table :admins, force: true do |t|
    t.string :email_ciphertext
    t.string :email_bidx
  end

  create_table :groups, force: true do |t|
  end
end

class User < ActiveRecord::Base
  attribute :initials, :string

  has_encrypted :email, :first_name, :last_name, :city, :region

  normalizes :region, with: ->(v) { v&.downcase }

  attr_encrypted :phone, key: SecureRandom.random_bytes(32)

  # ensure custom method still works
  def read_attribute_for_validation(key)
    super
  end
end

class Admin < ActiveRecord::Base
  has_encrypted :email
  blind_index :email

  belongs_to :user, primary_key: "email", foreign_key: "email", optional: true
end

class Group < ActiveRecord::Base
end
