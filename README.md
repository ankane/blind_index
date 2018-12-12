# Blind Index

Securely search encrypted database fields

Designed for use with [attr_encrypted](https://github.com/attr-encrypted/attr_encrypted)

Here’s a [full example](https://ankane.org/securing-user-emails-in-rails) of how to use it

[![Build Status](https://travis-ci.org/ankane/blind_index.svg?branch=master)](https://travis-ci.org/ankane/blind_index)

## How It Works

We use [this approach](https://paragonie.com/blog/2017/05/building-searchable-encrypted-databases-with-php-and-sql) by Scott Arciszewski. To summarize, we compute a keyed hash of the sensitive data and store it in a column. To query, we apply the keyed hash function (PBKDF2-HMAC-SHA256 by default) to the value we’re searching and then perform a database search. This results in performant queries for equality operations, while keeping the data secure from those without the key.

## Getting Started

Add these lines to your application’s Gemfile:

```ruby
gem 'attr_encrypted'
gem 'blind_index'
```

Add columns for the encrypted data and the blind index

```ruby
# encrypted data
add_column :users, :encrypted_email, :string
add_column :users, :encrypted_email_iv, :string
add_index :users, :encrypted_email_iv, unique: true

# blind index
add_column :users, :encrypted_email_bidx, :string
add_index :users, :encrypted_email_bidx
```

**Note:** We add a unique index on the IV because reusing an IV with the same key in AES-GCM (the default algorithm for attr_encrypted) can lead to [full compromise](https://csrc.nist.gov/csrc/media/projects/block-cipher-techniques/documents/bcm/joux_comments.pdf) of the key.

And add to your model

```ruby
class User < ApplicationRecord
  attr_encrypted :email, key: [ENV["EMAIL_ENCRYPTION_KEY"]].pack("H*")
  blind_index :email, key: [ENV["EMAIL_BLIND_INDEX_KEY"]].pack("H*")
end
```

We use environment variables to store the keys as hex-encoded strings ([dotenv](https://github.com/bkeepers/dotenv) is great for this). [Here’s an explanation](https://ankane.org/encryption-keys) of why `pack` is used. *Do not commit them to source control.* Generate one key for encryption and one key for hashing. You can generate keys in the Rails console with:

```ruby
SecureRandom.hex(32)
```

For development, you can use these:

```sh
EMAIL_ENCRYPTION_KEY=0000000000000000000000000000000000000000000000000000000000000000
EMAIL_BLIND_INDEX_KEY=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
```

And query away

```ruby
User.where(email: "test@example.org")
```

## Validations

To prevent duplicates, use:

```ruby
class User < ApplicationRecord
  validates :email, uniqueness: true
end
```

We also recommend adding a unique index to the blind index column through a database migration.

## Expressions

You can apply expressions to attributes before indexing and searching. This gives you the the ability to perform case-insensitive searches and more.

```ruby
class User < ApplicationRecord
  blind_index :email, expression: ->(v) { v.downcase } ...
end
```

## Multiple Indexes

You may want multiple blind indexes for an attribute. To do this, add another column:

```ruby
add_column :users, :encrypted_email_ci_bidx, :string
add_index :users, :encrypted_email_ci_bidx
```

And update your model

```ruby
class User < ApplicationRecord
  blind_index :email, ...
  blind_index :email_ci, attribute: :email, expression: ->(v) { v.downcase } ...
end
```

Search with:

```ruby
User.where(email_ci: "test@example.org")
```

## Index Only

If you don’t need to store the original value (for instance, when just checking duplicates), use a virtual attribute:

```ruby
class User < ApplicationRecord
  attribute :email
  blind_index :email, ...
end
```

*Requires ActiveRecord 5.1+*

## Multiple Columns

You can also use virtual attributes to index data from multiple columns:

```ruby
class User < ApplicationRecord
  attribute :initials

  # must come before blind_index method
  before_validation :set_initials, if: -> { changes.key?(:first_name) || changes.key?(:last_name) }
  blind_index :initials, ...

  def set_initials
    self.initials = "#{first_name[0]}#{last_name[0]}"
  end
end
```

*Requires ActiveRecord 5.1+*

## Fixtures

You can use encrypted attributes and blind indexes in fixtures with:

```yml
test_user:
  encrypted_email: <%= User.encrypt_email("test@example.org", iv: Base64.decode64("0000000000000000")) %>
  encrypted_email_iv: "0000000000000000"
  encrypted_email_bidx: <%= User.compute_email_bidx("test@example.org").inspect %>
```

Be sure to include the `inspect` at the end, or it won’t be encoded properly in YAML.

## Algorithms

### PBKDF2-SHA256

The default hashing algorithm. [Key stretching](https://en.wikipedia.org/wiki/Key_stretching) increases the amount of time required to compute hashes, which slows down brute-force attacks.

The default number of iterations is 10,000. For highly sensitive fields, set this to at least 100,000.

```ruby
class User < ApplicationRecord
  blind_index :email, iterations: 100000, ...
end
```

> Changing this value requires you to recompute the blind index.

### Argon2

Argon2 is the state-of-the-art algorithm and recommended for best security.

To use it, add [argon2](https://github.com/technion/ruby-argon2) to your Gemfile and set:

```ruby
class User < ApplicationRecord
  blind_index :email, algorithm: :argon2, ...
end
```

The default cost parameters are `{t: 3, m: 12}`. For highly sensitive fields, set this to at least `{t: 4, m: 15}`.

```ruby
class User < ApplicationRecord
  blind_index :email, algorithm: :argon2, cost: {t: 4, m: 15}, ...
end
```

> Changing this value requires you to recompute the blind index.

## Key Rotation

To rotate keys without downtime, add a new column:

```ruby
add_column :users, :encrypted_email_v2_bidx, :string
add_index :users, :encrypted_email_v2_bidx
```

And add to your model

```ruby
class User < ApplicationRecord
  blind_index :email, key: [ENV["EMAIL_BLIND_INDEX_KEY"]].pack("H*")
  blind_index :email_v2, attribute: :email, key: [ENV["EMAIL_V2_BLIND_INDEX_KEY"]].pack("H*")
end
```

Backfill the data

```ruby
User.find_each do |user|
  user.compute_email_v2_bidx
  user.save!
end
```

Then update your model

```ruby
class User < ApplicationRecord
  blind_index :email, bidx_attribute: :encrypted_email_v2_bidx, key: [ENV["EMAIL_V2_BLIND_INDEX_KEY"]].pack("H*")

  # remove this line after dropping column
  self.ignored_columns = ["encrypted_email_bidx"]
end
```

Finally, drop the old column.

## Reference

By default, blind indexes are encoded in Base64. Set a different encoding with:

```ruby
class User < ApplicationRecord
  blind_index :email, encode: ->(v) { [v].pack("H*") }
end
```

## Alternatives

One alternative to blind indexing is to use a deterministic encryption scheme, like [AES-SIV](https://github.com/miscreant/miscreant). In this approach, the encrypted data will be the same for matches.

## Upgrading

### 0.3.0

This version introduces a breaking change to enforce secure key generation. An error is thrown if your blind index key isn’t both binary and 32 bytes.

We recommend rotating your key if it doesn’t meet this criteria. You can generate a new key in the Rails console with:

```ruby
SecureRandom.hex(32)
```

Update your model to convert the hex key to binary.

```ruby
class User < ApplicationRecord
  blind_index :email, key: [ENV["EMAIL_BLIND_INDEX_KEY"]].pack("H*")
end
```

And recompute the blind index.

```ruby
User.find_each do |user|
  user.compute_email_bidx
  user.save!
end
```

To continue without rotating, set:

```ruby
class User < ApplicationRecord
  blind_index :email, insecure_key: true, ...
end
```

## History

View the [changelog](https://github.com/ankane/blind_index/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/blind_index/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/blind_index/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development and testing:

```sh
git clone https://github.com/ankane/blind_index.git
cd blind_index
bundle install
rake test
```
