require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: :test

task :benchmark do
  require "securerandom"
  require "benchmark/ips"
  require "blind_index"
  require "scrypt"
  require "argon2"

  key = SecureRandom.random_bytes(32)
  value = "secret"

  Benchmark.ips do |x|
    x.report("pbkdf2_hmac") { BlindIndex.generate_bidx(value, key: key, algorithm: :pbkdf2_hmac) }
    x.report("scrypt") { BlindIndex.generate_bidx(value, key: key, algorithm: :scrypt) }
    x.report("argon2") { BlindIndex.generate_bidx(value, key: key, algorithm: :argon2) }
  end
end
