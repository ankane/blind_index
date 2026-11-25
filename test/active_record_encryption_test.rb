require_relative "test_helper"

class ActiveRecordEncryptionTest < Minitest::Test
  def setup
    skip if defined?(Mongoid)

    EncryptedUser.delete_all
  end

  def test_find_by
    first = EncryptedUser.create!(email: "first@example.org")
    second = EncryptedUser.create!(email: "second@example.org")

    assert_equal first, EncryptedUser.where(email: first.email).first
    assert_equal first, EncryptedUser.find_by(email: first.email)
    assert_equal second, EncryptedUser.find_by(email: second.email)
    assert_equal first, EncryptedUser.find_by("email_address" => first.email)
    assert_equal second, EncryptedUser.find_by(id: second.id)
    assert_nil EncryptedUser.find_by(id: first.id, email: second.email)
  end

  def test_find_by_bang
    user = EncryptedUser.create!(email: "test@example.org")

    assert_equal user, EncryptedUser.find_by!(email: user.email)
    assert_raises(ActiveRecord::RecordNotFound) do
      EncryptedUser.find_by!(email: "missing@example.org")
    end
  end
end
