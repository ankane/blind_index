require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false # for attr_encrypted
end

task default: :test

namespace :benchmark do
  task :algorithms do
    require "benchmark/ips"
    require "blind_index"
    require "scrypt"
    require "argon2"

    key = BlindIndex.generate_key
    value = "secret"

    Benchmark.ips do |x|
      x.report("pbkdf2_sha256") { BlindIndex.generate_bidx(value, key: key, algorithm: :pbkdf2_sha256) }
      x.report("pbkdf2_sha256 slow") { BlindIndex.generate_bidx(value, key: key, algorithm: :pbkdf2_sha256, slow: true) }
      x.report("argon2id") { BlindIndex.generate_bidx(value, key: key, algorithm: :argon2id) }
      x.report("argon2id slow") { BlindIndex.generate_bidx(value, key: key, algorithm: :argon2id, slow: true) }
      # x.report("argon2i") { BlindIndex.generate_bidx(value, key: key, algorithm: :argon2i) }
      # x.report("scrypt") { BlindIndex.generate_bidx(value, key: key, algorithm: :scrypt) }
    end
  end

  task :queries do
    require "benchmark/ips"
    require "active_record"
    require "blind_index"

    ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

    ActiveRecord::Migration.create_table :users do |t|
      t.string :email_bidx
    end

    class User < ActiveRecord::Base
      blind_index :email, key: BlindIndex.generate_key, slow: true
    end

    Benchmark.ips do |x|
      x.report("no index") { User.find_by(id: 1) }
      x.report("index") { User.find_by(email: "test@example.org") }
    end
  end
end
