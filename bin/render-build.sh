#!/usr/bin/env bash
set -o errexit

echo "==> Removing stale Gemfile.lock..."
rm -f Gemfile.lock

echo "==> Installing gems..."
bundle install

echo "==> Building Tailwind CSS..."
bundle exec rails tailwindcss:build

echo "==> Precompiling assets..."
bundle exec rails assets:precompile

echo "==> Running migrations..."
bundle exec rails db:migrate

echo "==> Seeding database..."
bundle exec rails db:seed

echo "==> Build complete!"
