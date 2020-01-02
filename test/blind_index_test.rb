require_relative "test_helper"

class BlindIndexTest < Minitest::Test
  def setup
    User.delete_all
  end

  def test_find_by
    create_user
    assert User.find_by(email: "test@example.org")
  end

  def test_find_by_string_key
    create_user
    assert User.find_by({"email" => "test@example.org"})
  end

  def test_delete_by
    skip unless activerecord6?

    create_user
    assert_equal 1, User.delete_by(email: "test@example.org")
    assert_equal 0, User.count
  end

  def test_destroy_by
    skip unless activerecord6?

    user = create_user
    assert_equal [user], User.destroy_by(email: "test@example.org")
    assert_equal 0, User.count
  end

  def test_dynamic_finders
    skip if mongoid?

    user = create_user
    assert User.find_by_email("test@example.org")
    assert User.find_by_id_and_email(user.id, "test@example.org")
  end

  def test_where
    create_user
    assert User.where(email: "test@example.org").first
  end

  def test_where_array
    create_user
    create_user(email: "test2@example.org")
    key = mongoid? ? :email.in : :email
    assert_equal 2, User.where(key => ["test@example.org", "test2@example.org"]).count
  end

  def test_where_string_key
    create_user
    assert User.where({"email" => "test@example.org"}).first
  end

  def test_where_not
    skip if mongoid?

    create_user
    assert User.where.not(email: "test2@example.org").first
  end

  def test_where_not_empty
    skip if mongoid?

    create_user
    assert_nil User.where.not(email: "test@example.org").first
  end

  def test_expression
    create_user
    assert User.where(email_ci: "TEST@example.org").first
  end

  def test_expression_different_case
    create_user email: "TEST@example.org"
    assert User.where(email_ci: "test@example.org").first
  end

  def test_encode
    skip if mongoid?

    user = create_user
    assert User.find_by(email_binary: "test@example.org")
    assert_equal 32, user.email_binary_bidx.bytesize
  end

  def test_validation
    create_user
    user = User.new(email: "test@example.org")
    assert !user.valid?
    expected = mongoid? ? "Email is already taken" : "Email has already been taken"
    assert_equal expected, user.errors.full_messages.first
  end

  def test_validation_case_insensitive
    create_user
    user = User.new(email: "TEST@example.org")
    assert !user.valid?
    expected = mongoid? ? "Email ci is already taken" : "Email ci has already been taken"
    assert_equal expected, user.errors.full_messages.first
  end

  def test_nil
    user = create_user(email: nil)
    assert_nil user.email_bidx
    assert User.where(email: nil).first
    assert_nil User.where(email: "").first
  end

  def test_empty_string
    user = create_user(email: "")
    assert user.email_bidx
    assert User.where(email: "").first
    assert_nil User.where(email: nil).first
  end

  def test_unset
    user = create_user
    user.email = nil
    user.save!
    assert_nil user.email_bidx
    assert User.where(email: nil).first
  end

  def test_class_method
    user = create_user
    assert_equal user.email_bidx, User.generate_email_bidx("test@example.org")
    assert_equal user.email_bidx, User.compute_email_bidx("test@example.org")
  end

  def test_secure_key
    error = assert_raises(BlindIndex::Error) do
      BlindIndex.generate_bidx("test@example.org", key: "bad")
    end
    assert_equal "Key must use binary encoding", error.message
  end

  def test_secure_key_length
    error = assert_raises(BlindIndex::Error) do
      BlindIndex.generate_bidx("test@example.org", key: SecureRandom.random_bytes(20))
    end
    assert_equal "Key must be 32 bytes", error.message
  end

  def test_inheritance
    assert_equal %i[email email_ci email_binary initials phone], User.blind_indexes.keys
    assert_equal %i[email email_ci email_binary initials phone child], ActiveUser.blind_indexes.keys
  end

  def test_initials
    create_user(first_name: "Test", last_name: "User")
    assert User.find_by(initials: "TU")

    user = User.last
    user.email = "test2@example.org"
    user.save!
    assert User.find_by(initials: "TU")
  end

  def test_size
    result = BlindIndex.generate_bidx("secret", key: random_key, size: 16, encode: false)
    assert_equal 16, result.bytesize
  end

  def test_invalid_size
    error = assert_raises(BlindIndex::Error) do
      BlindIndex.generate_bidx("secret", key: random_key, size: 0, encode: false)
    end
    assert_equal "Size must be between 1 and 32", error.message
  end

  def test_backfill
    create_user
    User.update_all(email_bidx: nil)
    user = User.last
    assert_nil user.email_bidx
    user.compute_email_bidx
    assert user.email_bidx
  end

  def test_index_key
    index_key = BlindIndex.index_key(table: "users", bidx_attribute: "email_bidx", master_key: "0"*64)
    assert_equal "289737bab72fa97b1f4b081cef00d7b7d75034bcf3183c363feaf3e6441777bc", index_key
  end

  def test_default_algorithm
    create_user
    expected = BlindIndex.generate_bidx("test@example.org", algorithm: :argon2id, key: User.blind_indexes[:email][:key])
    assert_equal expected, User.last.email_bidx
  end

  def test_lockbox
    create_user(phone: "555-555-5555")
    assert User.find_by(phone: "555-555-5555")
  end

  def test_bad_master_key
    previous_value = BlindIndex.master_key
    begin
      BlindIndex.master_key = "bad"
      assert_raises(BlindIndex::Error) do
        User.create!(email: "test@example.org")
      end
    ensure
      BlindIndex.master_key = previous_value
    end
  end

  private

  def random_key
    SecureRandom.random_bytes(32)
  end

  def create_user(email: "test@example.org", **attributes)
    User.create!({email: email}.merge(attributes))
  end

  def mongoid?
    defined?(Mongoid)
  end

  def activerecord6?
    defined?(ActiveRecord) && ActiveRecord::VERSION::MAJOR >= 6
  end
end
