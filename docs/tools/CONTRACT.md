# Tools build contract (October 2026)

Seven Atlas-powered tools are being built in parallel, one git worktree and branch per tool.
This file is the shared contract. Read it fully before writing code.

## What the site is

writeralpha.com is a gemstone and crystal guide: 85 stone hubs (`/gemstones/<slug>`), up to 9 guides per
stone (`/gemstones/<slug>/<guide>`), learn and compare articles, filter pages (`/gemstones/zodiac/aries`,
`/gemstones/birth-month/february`, `/gemstones/healing/protection`). Rails 8.1, Turbo + Stimulus via
importmap, Tailwind v4, Postgres in prod, SQLite locally. Real search demand is dominated by
"who should not wear <stone>", "can <sign> wear <stone>", "can <stone> go in water", with strong Hindi and
Bengali queries from India and growing US demand.

## The Atlas (your data)

- `data/atlas/stones/<slug>.yml`, one per stone, schema in `data/atlas/SCHEMA.md`. Curators are still writing
  files while you build: **at any moment only some stones have files.** Your code must work with 3 files or 85.
  In your worktree, set `ATLAS_DIR=/agent/workspace/writeralpha-v2/data/atlas/stones` to see files as they land.
- Ruby API (`lib/atlas.rb`, `lib/atlas/stone.rb`): `Atlas[slug]`, `Atlas.stones`, `Atlas.where { }`,
  `stone.safety("water")` → safe/brief/avoid, `stone.safety_reason`, `stone.toxicity`, `stone.elixir`,
  `stone.mohs_min/max/label`, `stone.chakras`, `stone.elements`, `stone.planets`, `stone.vedic_planet`,
  `stone.zodiac`, `stone.intentions`, `stone.energy`, `stone.birth_months`, `stone.cautions`,
  `stone.zodiac_cautions`, `stone.tests`, `stone.common_fakes`, `stone.pairs_good/avoid`, `stone.price_tier`,
  `stone.names` (hi/bn/es...), `stone.safe_cleanse_methods`, `stone.sources`. Vocabularies are constants on
  `Atlas` (`Atlas::INTENTIONS`, `Atlas::INTENTION_LABELS`, `Atlas::CHAKRA_LABELS`, `Atlas::ZODIAC`, ...).
- `AtlasEntry` (app/models/atlas_entry.rb) joins an Atlas stone to its published `Gemstone`: `AtlasEntry.all`
  (one lean query), `AtlasEntry.find(slug)`, `e.path`, `e.image_url`, `e.guide?("can-go-in-water")`,
  `e.guide_path("how-to-identify")`, and every `Atlas::Stone` method by delegation. Call `AtlasEntry.all` once
  per request and reuse it. **Only link to guides where `e.guide?` is true** (the site never links to
  unwritten pages).
- `Atlas::Astro` (sun longitude, tropical and sidereal Sun sign with cusp flag), `Atlas::Vedic` (Navaratna,
  rashi lords, Hindi/Bengali names, planetary friendship `Vedic.mutual(a, b)`).

## Files you own

Only create or edit files for your tool:
- `app/controllers/tools/<tool>_controller.rb` (class `Tools::<Tool>Controller < ApplicationController`)
- `app/views/tools/<tool>/**` including the embed partials named for you below
- Engine/logic: `app/services/<tool_engine>.rb` (+ subfolder). Pure Ruby, no view code, unit-testable.
- `app/javascript/controllers/<tool>_*_controller.js` (Stimulus, auto-registered by importmap)
- Tests: `test/services/<tool_engine>_test.rb` (Minitest; create `test/test_helper.rb` only if missing — it is
  safe to create a minimal one: `ENV["RAILS_ENV"] ||= "test"; require_relative "../config/environment"; require "rails/test_help"`).
  Run with `bin/rails test test/services/<file>`.

**Do not edit** routes.rb, the layout, `tools_helper.rb`, `lib/atlas*`, the Atlas YAML, other tools' files,
or existing gemstone/article views. Routes and embed hooks already exist. If you need a shared change, make
the smallest possible workaround in your own files and describe the shared change in your report.

## Routes (already defined)

```
/tools                                  tools#index (done)
/tools/stone-finder                     tools/stone_finder#show
/tools/crystal-safety                   tools/safety#show
/tools/compatibility                    tools/compatibility#show
/tools/real-or-fake                     tools/real_or_fake#show
POST /tools/real-or-fake/photo          tools/real_or_fake#photo
/tools/birthstone-calculator            tools/birthstone#show
/tools/moon-calendar                    tools/moon#show
/tools/moon-calendar/feed.ics           tools/moon#feed   (register Mime "text/calendar", :ics in your controller file if needed)
/tools/moon-calendar/:month (YYYY-MM)   tools/moon#month
/developers                             developers#show
/api/v1/stones, /api/v1/stones/:slug    api/v1/stones#index/show (JSON)
```
Route helpers: `tools_stone_finder_path`, `tools_safety_path`, `tools_compatibility_path`,
`tools_real_or_fake_path`, `tools_real_or_fake_photo_path`, `tools_birthstone_path`, `tools_moon_path`,
`tools_moon_feed_path`, `tools_moon_month_path(month:)`, `developers_path`, `api_v1_stones_path`, `api_v1_stone_path(slug:)`.

## Embeds (already hooked into content pages)

`ToolsHelper::TOOL_EMBEDS` renders partials into existing pages if the partial exists. Create the ones listed
for your tool. Locals: hub/sub_page → `gemstone:` (Gemstone), `entry:` (AtlasEntry or **nil** if no Atlas
file yet: render nothing then), `guide:`; article → `article:` (+ `focus:` where noted); filter →
`filter_type:`, `value:` (slug, e.g. "aries", "protection", "february"). An embed sits inside the article column
(max ~760px) below the article body. Keep each embed compact: a card that answers the page's question
interactively and links to the full tool. Embeds must never raise: guard nil and missing data.

## Shared UI (use these, do not reinvent)

- `tool_header(title:, lede:, eyebrow:)` — standard tool page header with breadcrumb.
- `verdict_badge("safe")` / `verdict_badge(nil, label: "Good match", tone: :good|:warn|:bad|:info)`.
- `tradition_note` — required under any chakra/zodiac/planet/Vedic result.
- `noindex_when_params!(:keys...)` — call in the view when a tool shows a result for query params, so only the
  clean tool URL is indexed. `tool_jsonld(name:, description:)` on each tool page.
- Design system "Aura": read `app/assets/tailwind/application.css` and `app/views/gemstones/show.html.erb`.
  Cards: `rounded-[18px] border border-violet/10 bg-white/80 px-[22px] py-5`. Eyebrows:
  `font-mono text-[10px] uppercase tracking-[0.18em] text-faint`. Dark panel: `bg-ink/97` with
  `text-lavender` eyebrow. Ink headings `text-ink`, body `text-ui`, muted `text-muted`/`text-faint`, accent
  `text-violet-deep`. Font Sora; mono JetBrains Mono. Rounded pills. Generous whitespace. It must feel like
  one product with the rest of the site, and like the best-designed tool of its kind on the web.
- Set `@meta = { title:, description: }` in the controller (layout uses it).

## Engineering rules

- **Server-rendered first.** Inputs are a GET form; results render from query params so every result is a
  shareable URL and works without JavaScript. Use a Turbo Frame (`turbo_frame_tag`, form `data-turbo-frame`)
  so results update in place, and Stimulus only for enhancement (instant filtering, auto-submit on change,
  copy-link). No new gems, no npm packages, no external JS/CSS CDNs.
- Validate and clamp every param; unknown slugs are ignored, never 500. Dates: accept `YYYY-MM-DD`, reject
  nonsense with a friendly message.
- Copy: plain, specific, warm, no hype, no exclamation marks, no fake urgency. Tradition is always labelled as
  tradition ("in Vedic astrology", "crystal tradition says"). **No medical claims.** Physical safety facts
  come only from the Atlas.
- Performance: one `AtlasEntry.all` per request; no N+1; pages under ~150 KB HTML.
- Accessibility: labelled inputs, buttons not divs, colour is never the only signal (badges have text).

## Running it

```
export PATH=$HOME/.rubies/3.4.6/bin:$PATH
export ATLAS_DIR=/agent/workspace/writeralpha-v2/data/atlas/stones
cd <your worktree>
bin/rails tailwindcss:build            # after adding new Tailwind classes
bin/rails s -p <your port> -d          # stop with: kill $(cat tmp/pids/server.pid)
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:<port>/tools/...
```
The worktree has its own SQLite DB (seeded, same content as production). Check `log/development.log` for
errors. Before you finish: every route and every embed host page returns 200 with no errors in the log, with
no params, with good params, with garbage params, and with a stone that has no Atlas file.

## Finish

Commit on your branch (`git add -A && git commit -m "..."`, ending the message with
`Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`). Do not push, merge or rebase.
Then report: what you built (routes, embeds, files), design decisions, test results, any shared change you
need, and anything you could not finish.
