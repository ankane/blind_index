# Blind Index

Securely search encrypted database fields

Designed for use with [attr_encrypted](https://github.com/attr-encrypted/attr_encrypted)

[![Build Status](https://travis-ci.org/ankane/blind_index.svg?branch=master)](https://travis-ci.org/ankane/blind_index)

## How It Works

We use [this approach](https://www.sitepoint.com/how-to-search-on-securely-encrypted-database-fields/) by Scott Arciszewski. To summarize, we compute a keyed hash of the sensitive data and store it in a column. To query, we apply the keyed hash function (PBKDF2-HMAC-SHA256) to the value we’re searching and then perform a database search. This results in performant queries for equality operations, while keeping the data secure from those without the key.

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

# blind index
add_column :users, :encrypted_email_bidx, :string
add_index :users, :encrypted_email_bidx
```

And add to your model

```ruby
class User < ApplicationRecord
  attr_encrypted :email, key: ENV["EMAIL_ENCRYPTION_KEY"]
  blind_index :email, key: ENV["EMAIL_BLIND_INDEX_KEY"]
end
```

We use environment variables to store the keys ([dotenv](https://github.com/bkeepers/dotenv) is great for this). *Do not commit them to source control.* Generate one key for encryption and one key for hashing. For development, you can use these:

```sh
EMAIL_ENCRYPTION_KEY=00000000000000000000000000000000
EMAIL_BLIND_INDEX_KEY=99999999999999999999999999999999
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

## Key Stretching

Key stretching increases the amount of time required to compute hashes, which slows down brute-force attacks. You can set the number of iterations with:

```ruby
class User < ApplicationRecord
  blind_index :email, iterations: 1000000, ...
end
```

The default is `10000`. Changing this value requires you to recompute the blind index.

## Index Only

If you don’t need to store the original value (for instance, when just checking duplicates), use a virtual attribute:

```ruby
class User < ApplicationRecord
  attribute :email
  blind_index :email, ...
end
```

## Fixtures

You can use blind indexes in fixtures with:

```yml
test_user:
  encrypted_email_bidx: <%= User.compute_email_bidx("test@example.org").inspect %>
```

## Algorithms [master, not production-ready]

The default hashing algorithm is PBKDF2-HMAC-SHA256, but a number of others are available.

### scrypt

Add [scrypt](https://github.com/pbhogan/scrypt) to your Gemfile and use:

```ruby
class User < ApplicationRecord
  blind_index :email, algorithm: :scrypt, ...
end
```

### Argon2

Add [argon2](https://github.com/technion/ruby-argon2) to your Gemfile and use:

```ruby
class User < ApplicationRecord
  blind_index :email, algorithm: :argon2, ...
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
