## 0.3.5 [unreleased]

- Added support for hex keys
- Added `generate_key` method
- Fixed querying with array values

## 0.3.4

- Added `size` option
- Added sanity checks for Argon2 cost parameters
- Fixed ActiveRecord callback issues introduced in 0.3.3

## 0.3.3

- Added support for string keys in finders

## 0.3.2

- Added support for dynamic finders
- Added support for inherited models

## 0.3.1

- Added scrypt and Argon2 algorithms
- Added `cost` option

## 0.3.0

- Enforce secure key generation
- Added `encode` option
- Added `default_options` method

## 0.2.1

- Added class method to compute blind index
- Fixed issue with cached statements

## 0.2.0

- Added support for ActiveRecord 4.2
- Improved validation support when multiple blind indexes
- Fixed `nil` handling

## 0.1.1

- Added support for ActiveRecord 5.2
- Added `callback` option
- Added support for `key` proc
- Fixed error inheritance

## 0.1.0

- First release
