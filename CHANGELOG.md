## 1.0.2 (unreleased)

- Fixed `OpenSSL::KDF` error on some platforms
- Fixed deprecation warnings in Ruby 2.7

## 1.0.1 (2019-08-16)

- Added support for Mongoid

## 1.0.0 (2019-07-08)

- Added support for master key
- Added support for Argon2id
- Fixed `generate_key` for JRuby
- Dropped support for Rails 4.2

Breaking changes

- Made Argon2id the default algorithm
- Removed `encrypted_` prefix from columns
- Changed default encoding to Base64 strict

## 0.3.5 (2019-05-28)

- Added support for hex keys
- Added `generate_key` method
- Fixed querying with array values

## 0.3.4 (2018-12-16)

- Added `size` option
- Added sanity checks for Argon2 cost parameters
- Fixed ActiveRecord callback issues introduced in 0.3.3

## 0.3.3 (2018-11-12)

- Added support for string keys in finders

## 0.3.2 (2018-06-18)

- Added support for dynamic finders
- Added support for inherited models

## 0.3.1 (2018-06-04)

- Added scrypt and Argon2 algorithms
- Added `cost` option

## 0.3.0 (2018-06-03)

- Enforce secure key generation
- Added `encode` option
- Added `default_options` method

## 0.2.1 (2018-05-26)

- Added class method to compute blind index
- Fixed issue with cached statements

## 0.2.0 (2018-05-11)

- Added support for ActiveRecord 4.2
- Improved validation support when multiple blind indexes
- Fixed `nil` handling

## 0.1.1 (2018-04-09)

- Added support for ActiveRecord 5.2
- Added `callback` option
- Added support for `key` proc
- Fixed error inheritance

## 0.1.0 (2017-12-17)

- First release
