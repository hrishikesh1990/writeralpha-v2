# Writer Alpha V2 — Gemstone & Business Naming Platform

Rails 8.1 application with 17 database tables, 11 filter dimensions, 9 gemstone sub-page types, and full admin panel.

## Quick Start (1 command)

```bash
bin/setup && bin/dev
```

Then visit:
- **Site**: http://localhost:3000
- **Admin**: http://localhost:3000/admin (admin/changeme in dev)

## Manual Setup

```bash
bundle install
rails db:create db:migrate db:seed
bin/dev
```

## What's Included

### Gemstones Section (36 gemstones seeded)
- **Hub pages** with 9 sub-page types per gemstone
- **11 filter dimensions**: color, transparency, shape, cut, lustre, healing power, birth month, A-Z, zodiac, element, planet
- **Sub-pages**: meaning, who-should-not-wear, can-go-in-water, how-to-identify, sleeping-with, how-to-cleanse, combinations, affirmations, price-guide

### Naming Section
- Business names by industry
- Team names (sports, work, gaming)
- Instagram/social media usernames
- Angel numbers

### Admin Panel
- Full CRUD for gemstones (all 9 content fields + multi-select associations)
- Articles, categories, redirects management
- All taxonomy management (colors, shapes, cuts, etc.)

### SEO
- Dynamic meta tags on every page
- XML sitemap at /sitemap.xml
- Canonical URLs, Open Graph tags
- 301 redirect system (via redirects table)

## Tech Stack
- Ruby 3.4 / Rails 8.1
- SQLite (development)
- Tailwind CSS v4
- Hotwire (Turbo + Stimulus)

## URL Structure

```
/gemstones                      → Directory with 11 filters
/gemstones/:slug                → Gemstone hub page
/gemstones/:slug/meaning        → Sub-page (9 types)
/gemstones/color/:slug          → Filter page (11 types)
/business-names                 → Business naming directory
/team-names                     → Team names directory
/instagram-names                → Instagram usernames
/angel-numbers                  → Angel numbers
/admin                          → Admin panel
/sitemap.xml                    → Dynamic sitemap
```
