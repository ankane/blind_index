require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
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

    ActiveRecord::Migration.create_table :users do
    end

    ActiveRecord::Migration.create_table :cities do
    end

    class User < ActiveRecord::Base
      blind_index :email
    end

    class City < ActiveRecord::Base
    end

    Benchmark.ips do |x|
      x.report("no index") { City.where(id: 1).first }
      x.report("index") { User.where(id: 1).first }
    end
  end
end
