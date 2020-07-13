ActiveRecord::Base.logger = $logger

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

ActiveRecord::Migration.create_table :users, force: true do |t|
  t.string :encrypted_email
  t.string :encrypted_email_iv
  t.string :email_bidx, index: {unique: true}
  t.string :email_ci_bidx, index: {unique: true}
  t.binary :email_binary_bidx
  t.string :encrypted_first_name
  t.string :encrypted_first_name_iv
  t.string :encrypted_last_name
  t.string :encrypted_last_name_iv
  t.string :initials_bidx
  t.string :phone_ciphertext
  t.string :phone_bidx
end

class User < ActiveRecord::Base
  attribute :initials, :string

  attr_encrypted :email, key: SecureRandom.random_bytes(32)
  attr_encrypted :first_name, key: SecureRandom.random_bytes(32)
  attr_encrypted :last_name, key: SecureRandom.random_bytes(32)

  encrypts :phone

  # ensure custom method still works
  def read_attribute_for_validation(key)
    super
  end
end
