require_relative "lib/blind_index/version"

Gem::Specification.new do |spec|
  spec.name          = "blind_index"
  spec.version       = BlindIndex::VERSION
  spec.summary       = "Securely search encrypted database fields"
  spec.homepage      = "https://github.com/ankane/blind_index"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@chartkick.com"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.4"

  spec.add_dependency "activesupport", ">= 5"
  spec.add_dependency "argon2-kdf", ">= 0.1.1"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "attr_encrypted"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "scrypt"
  spec.add_development_dependency "benchmark-ips"
  spec.add_development_dependency "lockbox", ">= 0.2"
end
