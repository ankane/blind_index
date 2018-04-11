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
    assert_includes user.errors.full_messages.first, "has already been taken"
  end

  def test_nil
    user = create_user(email: nil)
    assert_nil user.encrypted_email_bidx
    assert User.where(email: nil).first
  end

  def test_unset
    user = create_user
    user.email = nil
    user.save!
    assert_nil user.encrypted_email_bidx
    assert User.where(email: nil).first
  end

  private

  def create_user(email: "test@example.org")
    User.create!(email: email)
  end
end
