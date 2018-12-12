### scrypt

Add [scrypt](https://github.com/pbhogan/scrypt) to your Gemfile and use:

```ruby
class User < ApplicationRecord
  blind_index :email, algorithm: :scrypt, ...
end
```

Set the cost parameters with:

```ruby
class User < ApplicationRecord
  blind_index :email, algorithm: :scrypt, cost: {n: 4096, r: 8, p: 1}, ...
end
```
