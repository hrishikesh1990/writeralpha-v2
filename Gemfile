source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "propshaft"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Database
gem "sqlite3", ">= 2.1", group: [:development, :test]
gem "pg", "~> 1.5", group: :production

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
end

group :development do
  gem "web-console"
end

gem "dockerfile-rails", ">= 1.7", group: :development
