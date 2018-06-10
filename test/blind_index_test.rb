require_relative "test_helper"

class BlindIndexTest < Minitest::Test
  def setup
    User.delete_all
  end

  def test_find_by
    create_user
    assert User.find_by(email: "test@example.org")
  end

  def test_where
    create_user
    assert User.where(email: "test@example.org").first
  end

  def test_where_not
    create_user
    assert User.where.not(email: "test2@example.org").first
  end

  def test_where_not_empty
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
    user = create_user
    assert User.find_by(email_binary: "test@example.org")
    assert_equal 32, user.encrypted_email_binary_bidx.bytesize
  end

  def test_validation
    create_user
    user = User.new(email: "test@example.org")
    assert !user.valid?
    assert_equal "Email has already been taken", user.errors.full_messages.first
  end

  def test_validation_case_insensitive
    create_user
    user = User.new(email: "TEST@example.org")
    assert !user.valid?
    assert_equal "Email ci has already been taken", user.errors.full_messages.first
  end

  def test_nil
    user = create_user(email: nil)
    assert_nil user.encrypted_email_bidx
    assert User.where(email: nil).first
    assert_nil User.where(email: "").first
  end

  def test_empty_string
    user = create_user(email: "")
    assert user.encrypted_email_bidx
    assert User.where(email: "").first
    assert_nil User.where(email: nil).first
  end

  def test_unset
    user = create_user
    user.email = nil
    user.save!
    assert_nil user.encrypted_email_bidx
    assert User.where(email: nil).first
  end

  def test_class_method
    user = create_user
    assert_equal user.encrypted_email_bidx, User.compute_email_bidx("test@example.org")
  end

  def test_secure_key
    error = assert_raises(BlindIndex::Error) do
      BlindIndex.generate_bidx("test@example.org", key: "bad")
    end
    assert_equal "Key must use binary encoding", error.message
  end

  # def test_secure_key_ascii
  #   error = assert_raises(BlindIndex::Error) do
  #     BlindIndex.generate_bidx("test@example.org", key: ("0"*32).encode("BINARY"))
  #   end
  #   assert_equal "Key must not be ASCII", error.message
  # end

  def test_secure_key_length
    error = assert_raises(BlindIndex::Error) do
      BlindIndex.generate_bidx("test@example.org", key: SecureRandom.random_bytes(20))
    end
    assert_equal "Key must be 32 bytes", error.message
  end

  def test_inheritance
    assert_equal %i[email email_ci email_binary], User.blind_indexes.keys
    assert_equal %i[email email_ci email_binary child], ActiveUser.blind_indexes.keys
  end

  private

  def create_user(email: "test@example.org")
    User.create!(email: email)
  end
end
