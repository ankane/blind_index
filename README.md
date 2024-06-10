# Blind Index

Securely search encrypted database fields

Works with [Lockbox](https://github.com/ankane/lockbox) ([full example](https://ankane.org/securing-user-emails-lockbox)) and [attr_encrypted](https://github.com/attr-encrypted/attr_encrypted) ([full example](https://ankane.org/securing-user-emails-in-rails))

Learn more about [securing sensitive data in Rails](https://ankane.org/sensitive-data-rails)

[![Build Status](https://github.com/ankane/blind_index/actions/workflows/build.yml/badge.svg)](https://github.com/ankane/blind_index/actions)

## How It Works

We use [this approach](https://paragonie.com/blog/2017/05/building-searchable-encrypted-databases-with-php-and-sql) by Scott Arciszewski. To summarize, we compute a keyed hash of the sensitive data and store it in a column. To query, we apply the keyed hash function to the value we’re searching and then perform a database search. This results in performant queries for exact matches. Efficient `LIKE` queries are [not possible](#like-ilike-and-full-text-searching), but you can index expressions.

## Leakage

An important consideration in searchable encryption is leakage, which is information an attacker can gain. Blind indexing leaks that rows have the same value. If you use this for a field like last name, an attacker can use frequency analysis to predict the values. In an active attack where an attacker can control the input values, they can learn which other values in the database match.

Here’s a [great article](https://blog.cryptographyengineering.com/2019/02/11/attack-of-the-week-searchable-encryption-and-the-ever-expanding-leakage-function/) on leakage in searchable encryption. Blind indexing has the same leakage as [deterministic encryption](#alternatives).

## Installation

Add this line to your application’s Gemfile:

```ruby
gem "blind_index"
```

## Prep

Your model should already be set up with Lockbox or attr_encrypted. The examples are for a `User` model with `has_encrypted :email` or `attr_encrypted :email`. See the full examples for [Lockbox](https://ankane.org/securing-user-emails-lockbox) and [attr_encrypted](https://ankane.org/securing-user-emails-in-rails) if needed.

Also, if you use attr_encrypted, [generate a key](#key-generation).

## Getting Started

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
BlindIndex.backfill(User)
```

And query away

```ruby
User.where(email: "test@example.org")
```

## Expressions

You can apply expressions to attributes before indexing and searching. This gives you the the ability to perform case-insensitive searches and more.

```ruby
class User < ApplicationRecord
  blind_index :email, expression: ->(v) { v.downcase }
end
```

## Validations

You can use blind indexes for uniqueness validations.

```ruby
class User < ApplicationRecord
  validates :email, uniqueness: true
end
```

We recommend adding a unique index to the blind index column through a database migration.

```ruby
add_index :users, :email_bidx, unique: true
```

For `allow_blank: true`, use:

```ruby
class User < ApplicationRecord
  blind_index :email, expression: ->(v) { v.presence }
  validates :email, uniqueness: {allow_blank: true}
end
```

For `case_sensitive: false`, use:

```ruby
class User < ApplicationRecord
  blind_index :email, expression: ->(v) { v.downcase }
  validates :email, uniqueness: true # for best performance, leave out {case_sensitive: false}
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
BlindIndex.backfill(User, columns: [:email_ci_bidx])
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
  blind_index :initials

  before_validation :set_initials, if: -> { changes.key?(:first_name) || changes.key?(:last_name) }

  def set_initials
    self.initials = "#{first_name[0]}#{last_name[0]}"
  end
end
```

## Migrating Data

If you’re encrypting a column and adding a blind index at the same time, use the `migrating` option.

```ruby
class User < ApplicationRecord
  blind_index :email, migrating: true
end
```

This allows you to backfill records while still querying the unencrypted field.

```ruby
BlindIndex.backfill(User)
```

Once that completes, you can remove the `migrating` option.

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
BlindIndex.backfill(User, columns: [:email_bidx_v2])
```

Then update your model

```ruby
class User < ApplicationRecord
  blind_index :email, version: 2, master_key: ENV["BLIND_INDEX_MASTER_KEY_V2"]
end
```

Finally, drop the old column.

## Key Separation

The master key is used to generate unique keys for each blind index. This technique comes from [CipherSweet](https://ciphersweet.paragonie.com/internals/key-hierarchy). The table name and blind index column name are both used in this process.

You can get an individual key with:

```ruby
BlindIndex.index_key(table: "users", bidx_attribute: "email_bidx")
```

To rename a table with blind indexes, use:

```ruby
class User < ApplicationRecord
  blind_index :email, key_table: "original_table"
end
```

To rename a blind index column, use:

```ruby
class User < ApplicationRecord
  blind_index :email, key_attribute: "original_column"
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

## Mongoid

For Mongoid, use:

```ruby
class User
  field :email_bidx, type: String
  index({email_bidx: 1})
end
```

## Key Generation

This is optional for Lockbox, as its master key is used by default.

Generate a key with:

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

## LIKE, ILIKE, and Full-Text Searching

Unfortunately, blind indexes can’t be used for `LIKE`, `ILIKE`, or full-text searching. Instead, records must be loaded, decrypted, and searched in memory.

For `LIKE`, use:

```ruby
User.select { |u| u.email.include?("value") }
```

For `ILIKE`, use:

```ruby
User.select { |u| u.email =~ /value/i }
```

For full-text or fuzzy searching, use a gem like [FuzzyMatch](https://github.com/seamusabshere/fuzzy_match):

```ruby
FuzzyMatch.new(User.all, read: :email).find("value")
```

If the number of records is large, try to find a way to narrow it down. An [expression index](#expressions) is one way to do this, but leaks which records have the same value of the expression, so use it carefully.

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

## Compatibility

You can generate blind indexes from other languages as well. For Python, you can use [argon2-cffi](https://github.com/hynek/argon2-cffi).

```python
from argon2.low_level import Type, hash_secret_raw
from base64 import b64encode

key = '289737bab72fa97b1f4b081cef00d7b7d75034bcf3183c363feaf3e6441777bc'
value = 'test@example.org'

bidx = b64encode(hash_secret_raw(
    secret=value.encode(),
    salt=bytes.fromhex(key),
    time_cost=3,
    memory_cost=2**12,
    parallelism=1,
    hash_len=32,
    type=Type.ID
))
```

## Alternatives

One alternative to blind indexing is to use a deterministic encryption scheme, like [AES-SIV](https://github.com/miscreant/miscreant). In this approach, the encrypted data will be the same for matches. We recommend blind indexing over deterministic encryption because:

1. You can keep encryption consistent for all fields (both searchable and non-searchable)
2. Blind indexing supports expressions

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
bundle exec rake test
```

For security issues, send an email to the address on [this page](https://github.com/ankane).
