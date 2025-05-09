## 2.7.0 (2025-05-04)

- Dropped support for Ruby < 3.2 and Active Record < 7.1
- Dropped support for Mongoid < 8

## 2.6.2 (2025-02-23)

- Fixed querying with normalized attributes

## 2.6.1 (2024-11-01)

- Fixed issue with `includes` and Active Record 7

## 2.6.0 (2024-10-07)

- Removed dependency on `scrypt` gem for scrypt algorithm
- Dropped support for Active Record < 7

## 2.5.0 (2024-06-03)

- Added support for Mongoid 9
- Dropped support for Ruby < 3.1

## 2.4.0 (2023-07-02)

- Dropped support for Ruby < 3 and Rails < 6.1
- Dropped support for Mongoid < 7

## 2.3.2 (2023-04-26)

- Added `key_table` and `key_attribute` options

## 2.3.1 (2022-09-06)

- Fixed error with `backfill` when `bidx_attribute` is a symbol

## 2.3.0 (2022-01-16)

- Added blind indexes to `filter_attributes`
- Dropped support for Ruby < 2.6 and Rails < 5.2

## 2.2.0 (2020-09-07)

- Added support for `where` with table in Active Record 5.2+

## 2.1.1 (2020-08-14)

- Fixed `version` option

## 2.1.0 (2020-07-06)

- Improved performance of uniqueness validations
- Fixed deprecation warnings in Ruby 2.7 with Mongoid

## 2.0.2 (2020-06-01)

- Improved error message for bad key length
- Fixed `backfill` method with relations for Mongoid

## 2.0.1 (2020-02-14)

- Added `BlindIndex.backfill` method

## 2.0.0 (2020-02-10)

- Blind indexes are updated immediately instead of in a `before_validation` callback
- Better Lockbox integration - no need to generate a separate key
- The `argon2` gem has been replaced with `argon2-kdf` for less dependencies and Windows support
- Removed deprecated `compute_email_bidx`

## 1.0.2 (2019-12-26)

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
- Fixed Active Record callback issues introduced in 0.3.3

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

- Added support for Active Record 4.2
- Improved validation support when multiple blind indexes
- Fixed `nil` handling

## 0.1.1 (2018-04-09)

- Added support for Active Record 5.2
- Added `callback` option
- Added support for `key` proc
- Fixed error inheritance

## 0.1.0 (2017-12-17)

- First release
