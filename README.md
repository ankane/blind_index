# Blind Index

Securely search encrypted database fields

Works with [Lockbox](https://github.com/ankane/lockbox) ([full example](https://ankane.org/securing-user-emails-lockbox)) and [attr_encrypted](https://github.com/attr-encrypted/attr_encrypted) ([full example](https://ankane.org/securing-user-emails-in-rails))

Learn more about [securing sensitive data in Rails](https://ankane.org/sensitive-data-rails)

[![Build Status](https://travis-ci.org/ankane/blind_index.svg?branch=master)](https://travis-ci.org/ankane/blind_index)

## How It Works

We use [this approach](https://paragonie.com/blog/2017/05/building-searchable-encrypted-databases-with-php-and-sql) by Scott Arciszewski. To summarize, we compute a keyed hash of the sensitive data and store it in a column. To query, we apply the keyed hash function to the value we’re searching and then perform a database search. This results in performant queries for exact matches. `LIKE` queries are not possible, but you can index expressions.

## Leakage

An important consideration in searchable encryption is leakage, which is information an attacker can gain. Blind indexing leaks that rows have the same value. If you use this for a field like last name, an attacker can use frequency analysis to predict the values. In an active attack where an attacker can control the input values, they can learn which other values in the database match.

Here’s a [great article](https://blog.cryptographyengineering.com/2019/02/11/attack-of-the-week-searchable-encryption-and-the-ever-expanding-leakage-function/) on leakage in searchable encryption. Blind indexing has the same leakage as deterministic encryption.

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'blind_index'
```

On Windows, also add:

```ruby
gem 'argon2', git: 'https://github.com/technion/ruby-argon2.git', submodules: true
```

Until `argon2 >= 2.0.1` is released.

## Getting Started

> Note: Your model should already be set up with Lockbox or attr_encrypted. The examples are for a `User` model with `encrypts :email` or `attr_encrypted :email`. See the full examples for [Lockbox](https://ankane.org/securing-user-emails-lockbox) and [attr_encrypted](https://ankane.org/securing-user-emails-in-rails) if needed.

First, generate a key

```ruby
BlindIndex.generate_key
```

Store the key with your other secrets. This is typically Rails credentials or an environment variable ([dotenv](https://github.com/bkeepers/dotenv) is great for this). Be sure to use different keys in development and production. Keys don’t need to be hex-encoded, but it’s often easier to store them this way.

Set the following environment variable with your key (you can use this one in development)

```sh
BLIND_INDEX_MASTER_KEY=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
```

or create `config/initializers/blind_index.rb` with something like

```ruby
BlindIndex.master_key = Rails.application.credentials.blind_index_master_key
```

Create a migration to add a column for the blind index

```ruby
add_column :users, :email_bidx, :string
add_index :users, :email_bidx # unique: true if needed
```

Add to your model

```ruby
class User < ApplicationRecord
  blind_index :email
end
```

For more sensitive fields, use

```ruby
class User < ApplicationRecord
  blind_index :email, slow: true
end
```

Backfill existing records

```ruby
User.unscoped.where(email_bidx: nil).find_each do |user|
  user.compute_email_bidx
  user.save(validate: false)
end
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
  blind_index :email, expression: ->(v) { v.downcase }
end
```

## Multiple Indexes

You may want multiple blind indexes for an attribute. To do this, add another column:

```ruby
add_column :users, :email_ci_bidx, :string
add_index :users, :email_ci_bidx
```

Update your model

```ruby
class User < ApplicationRecord
  blind_index :email
  blind_index :email_ci, attribute: :email, expression: ->(v) { v.downcase }
end
```

Backfill existing records

```ruby
User.unscoped.where(email_ci_bidx: nil).find_each do |user|
  user.compute_email_ci_bidx
  user.save(validate: false)
end
```

And query away

```ruby
User.where(email_ci: "test@example.org")
```

## Index Only

If you don’t need to store the original value (for instance, when just checking duplicates), use a virtual attribute:

```ruby
class User < ApplicationRecord
  attribute :email, :string
  blind_index :email
end
```

## Multiple Columns

You can also use virtual attributes to index data from multiple columns:

```ruby
class User < ApplicationRecord
  attribute :initials, :string

  # must come before the blind_index method so it runs first
  before_validation :set_initials, if: -> { changes.key?(:first_name) || changes.key?(:last_name) }

  blind_index :initials

  def set_initials
    self.initials = "#{first_name[0]}#{last_name[0]}"
  end
end
```

## Key Rotation

To rotate keys without downtime, add a new column:

```ruby
add_column :users, :email_bidx_v2, :string
add_index :users, :email_bidx_v2
```

And add to your model

```ruby
class User < ApplicationRecord
  blind_index :email, rotate: {version: 2, master_key: ENV["BLIND_INDEX_MASTER_KEY_V2"]}
end
```

This will keep the new column synced going forward. Next, backfill the data:

```ruby
User.unscoped.where(email_bidx_v2: nil).find_each do |user|
  user.compute_rotated_email_bidx
  user.save(validate: false)
end
```

Then update your model

```ruby
class User < ApplicationRecord
  blind_index :email, version: 2, master_key: ENV["BLIND_INDEX_MASTER_KEY_V2"]
end
```

Finally, drop the old column.

## Key Separation

The master key is used to generate unique keys for each blind index. This technique comes from [CipherSweet](https://ciphersweet.paragonie.com/internals/key-hierarchy). The table name and blind index column name are both used in this process. If you need to rename a table with blind indexes, or a blind index column itself, get the key:

```ruby
BlindIndex.index_key(table: "users", bidx_attribute: "email_bidx")
```

And set it directly before renaming:

```ruby
class User < ApplicationRecord
  blind_index :email, key: ENV["USER_EMAIL_BLIND_INDEX_KEY"]
end
```

## Algorithm

Argon2id is used for best security. The default cost parameters are 3 iterations and 4 MB of memory. For `slow: true`, the cost parameters are 4 iterations and 32 MB of memory.

A number of other algorithms are [also supported](docs/Other-Algorithms.md). Unless you have specific reasons to use them, go with Argon2id.

## Fixtures

You can use blind indexes in fixtures with:

```yml
test_user:
  email_bidx: <%= User.generate_email_bidx("test@example.org").inspect %>
```

Be sure to include the `inspect` at the end or it won’t be encoded properly in YAML.

## Reference

Set default options in an initializer with:

```ruby
BlindIndex.default_options = {algorithm: :pbkdf2_sha256}
```

By default, blind indexes are encoded in Base64. Set a different encoding with:

```ruby
class User < ApplicationRecord
  blind_index :email, encode: ->(v) { [v].pack("H*") }
end
```

By default, blind indexes are 32 bytes. Set a smaller size with:

```ruby
class User < ApplicationRecord
  blind_index :email, size: 16
end
```

Set a key directly for an index with:

```ruby
class User < ApplicationRecord
  blind_index :email, key: ENV["USER_EMAIL_BLIND_INDEX_KEY"]
end
```

## Alternatives

One alternative to blind indexing is to use a deterministic encryption scheme, like [AES-SIV](https://github.com/miscreant/miscreant). In this approach, the encrypted data will be the same for matches.

## Upgrading

### 1.0.0

1.0.0 brings a number of improvements. Here are a few to be aware of:

- Argon2id is the default algorithm for stronger security
- You can use a master key instead of individual keys for each column
- Columns no longer have an `encrypted_` prefix

For existing fields, add:

```ruby
class User < ApplicationRecord
  blind_index :email, legacy: true
end
```

#### Optional

To rotate to new fields that use Argon2id and a master key, generate a master key:

```ruby
BlindIndex.generate_key
```

And set `ENV["BLIND_INDEX_MASTER_KEY"]` or `BlindIndex.master_key`.

Add a new column without the `encrypted_` prefix:

```ruby
add_column :users, :email_bidx, :string
add_index :users, :email_bidx # unique: true if needed
```

And add to your model

```ruby
class User < ApplicationRecord
  blind_index :email, key: ENV["USER_EMAIL_BLIND_INDEX_KEY"], legacy: true, rotate: true
end
```

> For more sensitive fields, use `rotate: {slow: true}`

This will keep the new column synced going forward. Next, backfill the data:

```ruby
User.unscoped.where(email_bidx: nil).find_each do |user|
  user.compute_rotated_email_bidx
  user.save(validate: false)
end
```

Then update your model

```ruby
class User < ApplicationRecord
  blind_index :email
end
```

> For more sensitive fields, add `slow: true`

Finally, drop the old column.

### 0.3.0

This version introduces a breaking change to enforce secure key generation. An error is thrown if your blind index key isn’t both binary and 32 bytes.

We recommend rotating your key if it doesn’t meet this criteria. You can generate a new key in the Rails console with:

```ruby
SecureRandom.hex(32)
```

Update your model to convert the hex key to binary.

```ruby
class User < ApplicationRecord
  blind_index :email, key: [ENV["USER_EMAIL_BLIND_INDEX_KEY"]].pack("H*")
end
```

And recompute the blind index.

```ruby
User.unscoped.find_each do |user|
  user.compute_email_bidx
  user.save(validate: false)
end
```

To continue without rotating, set:

```ruby
class User < ApplicationRecord
  blind_index :email, insecure_key: true
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
