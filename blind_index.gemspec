require_relative "lib/blind_index/version"

Gem::Specification.new do |spec|
  spec.name          = "blind_index"
  spec.version       = BlindIndex::VERSION
  spec.summary       = "Securely search encrypted database fields"
  spec.homepage      = "https://github.com/ankane/blind_index"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@ankane.org"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "activesupport", ">= 7.1"
  spec.add_dependency "argon2-kdf", ">= 0.2"
end
