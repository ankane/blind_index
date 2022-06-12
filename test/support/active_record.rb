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
    t.references :group
  end

  create_table :groups, force: true do |t|
  end
end

class User < ActiveRecord::Base
  attribute :initials, :string

  has_encrypted :email, :first_name, :last_name, :city

  if ActiveRecord::VERSION::MAJOR >= 7
    alias_attribute :phone, :encrypted_phone
  else
    attr_encrypted :phone, key: SecureRandom.random_bytes(32)
  end

  # ensure custom method still works
  def read_attribute_for_validation(key)
    super
  end
end

class Group < ActiveRecord::Base
end
