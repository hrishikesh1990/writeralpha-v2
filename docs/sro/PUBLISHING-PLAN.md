# WriterAlpha publishing plan (SRO drafts, September 2026)

Written 2026-09-19; wave 0 and wave 1 done the same day (see the log at the end). Companion to `TOPICAL-MAP.md`, `WRITING-CONTRACT.md` and the ledgers in this folder (branch `sro-topical-map-2026-09` until merged). Google Doc copies of every draft live in the Drive folder "WriterAlpha SRO Drafts 2026-09"; the drafts index sheet maps each URL to its doc.

## In a nutshell

1. There are 776 reviewed drafts and none is published: 636 gemstone sub-pages across 84 stones and 140 articles (25 purpose guides, 50 pairings, 25 learn, 10 comparisons, 30 angel numbers). All 776 pass `check_draft.py`, including link resolution once `data/known_urls.json` is rebuilt from `inventory.csv` plus the draft URLs. No draft overwrites a sub-page that already has content.
2. Publishing order is forced by links, not taste. The sub-pages carry about 2,300 links into the 140 articles, and the articles link only to hubs that already exist. So: learn and compare first, then purpose guides, then sub-pages by demand, then pairings, then the P3 long tail, angel numbers last.
3. Six code changes must land before anything goes live. The sanitizer strips `<table>` (321 drafts use tables); the markdown converter cannot handle tables, bold or inline links; the article canonical rule sends pairing and angel-number slugs to `/learn/`; article routes never consult the redirects table; the articles table requires a category; and there is no place to store a sub-page's own title and meta description.
4. Source of truth for import is the markdown in `docs/sro/drafts/`, not the Google Docs. Reviewers comment in Docs; accepted edits are ported to the markdown before that wave imports. A pre-import check lists any Doc modified after the markdown commit.
5. The live site has 268 sitemap URLs (85 hubs, 119 sub-pages, 36 filter pages, 23 articles, the gemstone directory and 4 static pages). After all waves it will have about 1,040. The local dev database is stale (it still holds 60 published naming articles that prod no longer serves), so prod is the reference for "what exists", and every wave is rehearsed locally on port 3010 before it runs on Fly.
6. Measurement starts before wave 1 with a per-URL Google Search Console export, and each wave is checked at 14 and 28 days. Two pre-agreed stop rules cover the pages the topical map called bets (affirmations, combinations, sleeping-with; price guides).

## Where things stand

| Item | State (2026-09-19) |
|---|---|
| Drafts | 776 markdown files in `docs/sro/drafts/` (branch `sro-topical-map-2026-09`), one Google Doc each in Drive, index in `drafts-index.csv` (doc_id, doc_link, status, priority, words, open_evidence_gaps) |
| Checker | 776 PASS, 0 FAIL, with `data/known_urls.json` rebuilt (inventory 227 live URLs + 776 draft URLs + zodiac and birth-month filter pages). The file is not in the branch; regenerate it before each run |
| Collisions | 0 gemstone drafts target a field that already has content locally; 16 article drafts overwrite an existing slug in place (status `rewrite`); 3 are renames or consolidations of legacy slugs; 1 sub-page absorbs a legacy article |
| Google Docs edits | In the folders sampled, every doc's modifiedTime equals its createdTime, so no reviewer edits exist yet |
| Live site | 268 URLs in sitemap; 119 legacy sub-pages live (meaning 57, water 39, who-should-not-wear 17, sleeping-with 6); angel numbers and pairings 404 |
| Local DB | `storage/development.sqlite3` last touched 2026-09-02; 85 published gemstones match prod; articles do not (98 published locally vs 23 on prod) |
| Evidence gaps | 558 drafts record an open gap in `evidence-gaps.csv`: all 30 angel numbers (tradition, no empirical basis), 83 price guides (unverified retail ranges), the rest mostly pairings and identification pages |

## What has to be true before the first page goes live

These are code changes in the Rails app. All of them are small; together they are the whole of wave 0.

1. **Markdown to HTML.** `lib/tasks/convert_content.rake` handles headings, bullets and paragraphs only. Drafts use tables (321), bold (629), ordered lists (222), H3 (250), inline links (all) and italics. Add a real converter (`commonmarker` with GFM tables, or `kramdown`) and a new task `sro:import` that reads a draft, parses the front matter, converts the body, drops the H1 (both templates render their own), and upserts the record.
2. **Sanitizer.** `ApplicationHelper::ALLOWED_TAGS` has no `table thead tbody tr th td`. Add them and give `.article table` styles in the Tailwind layer. Without this every comparison table renders as one run-on paragraph.
3. **Canonical URLs for two slug shapes.** `Article#canonical_section` returns `crystals` for `crystals-for-*`, `compare` for `*-vs-*`, else `learn`. A pairing slug like `rose-quartz-and-amethyst-together` therefore canonicalises to `/learn/...`, and `CrystalsController#pair` would 301 every pairing away from `/crystals/`. Angel numbers use slug `angel-number-444` and would be listed in the sitemap at `/learn/angel-number-444` while also rendering at `/angel-numbers/444`. Fix: `-and-` + `-together` → `crystals`; `angel-number-` → path `/angel-numbers/<n>`.
4. **Redirects on article routes.** `render_article_or_redirect` 404s when the slug is not found; only `GemstonesController#load_gemstone` and the catch-all consult the redirects table. Six legacy article URLs are being consolidated (see the redirect table below) and their routes match `crystals#pair` or `learn#show` before the catch-all, so the redirect rows would never fire. Fix: look up `Redirect` before `render_not_found` in that method.
5. **Category.** `articles.category_id` is NOT NULL. Map section → category: `/crystals/crystals-for-*` → `crystals-for` (id 10), pairings → `crystal-pairs` (12), `/learn/` → `learn` (8), `/compare/` → `comparisons` (11), `/angel-numbers/` → `angel-numbers` (9).
6. **Sub-page title and meta.** The sub-page template builds its H1 from `Gemstone::SUB_PAGES` (`Pyrite Meaning, Properties & Benefits`) and derives the meta description from the first 155 characters of content. Drafts carry a better-targeted title and a written meta description, but gemstones have no per-sub-page columns. Recommended: add a `sub_page_meta` JSON column (`{ "meaning": { "title", "meta_title", "meta_description" }, ... }`) and let the controller prefer it. If skipped, the template titles apply and the drafts' titles are discarded; the pages still work.
7. **Angel numbers in nav and sitemap.** They are deliberately hidden until real guides exist (`AngelNumbersController` comment, sitemap). Wave 6 turns them on: sitemap entries, a nav or footer link, and the index page listing the 30.
8. **Hub → purpose-guide links.** The topical map asks hubs to link to the purpose guides matching their healing-power tags. Add a small map in the hub view once wave 2 is live: Concentration → `/crystals/crystals-for-concentration`, Protection → `-protection`, Love → `-love`, Wealth → `-money`, Confidence → `-confidence`, Creativity → `-creativity`, Grounding → `-grounding`, Healing → `-healing`, Sleep → `-sleep`, Peace & Calm → `-anxiety`. The other five powers have no guide and stay as filter links.
9. **Baseline.** Export GSC Performance → Pages for the last 16 months and the last 28 days (clicks, impressions, position) and save as `docs/sro/baseline/gsc-pages-<date>.csv`. `content_backlog.csv` has impressions per stone but not per URL or clicks, so it is not a baseline on its own.

Legacy URLs to redirect (add to `db/seeds/05_redirects.rb` with the existing `redirect!` helper, and unpublish the old article rows in the same wave):

| Old URL | New URL | Wave |
|---|---|---|
| /crystals/11-best-crystals-for-grief | /crystals/crystals-for-grief | 2 |
| /crystals/best-crystals-for-connection-with-others | /crystals/crystals-for-connection | 2 |
| /crystals/best-crystals-for-sleep-enhance-sleep-quality-naturally | /crystals/crystals-for-sleep | 2 |
| /learn/crystals-to-sleep-with-under-your-pillow | /crystals/crystals-for-sleep | 2 |
| /learn/how-to-tell-if-black-tourmaline-is-real | /gemstones/black-tourmaline/how-to-identify | 3 |
| /learn/aura-quartz-healing-properties | /gemstones/angel-aura-quartz/meaning (already live) | 3 |

For the three renames the cleanest path is to change the legacy row's slug and replace its content, which keeps the original `published_at` and category. `/learn/how-to-identify-kimberlite` is retained as is.

## Publishing order

The rule: never publish a page whose internal links 404. Every draft links only to live pages or to other drafts, so the order below makes each wave's links resolve by the time it ships. Whole stones ship together so the hub's guide grid and the "More X guides" sidebar fill in one go.

| Wave | Content | Pages | Target week | Depends on |
|---|---|---|---|---|
| 0 | Code prerequisites 1–9, local rehearsal of the full import, link audit, baseline export | 0 | 21–25 Sep | branch merged to main |
| 1 | Learn (25) and compare (10). Includes 11 rewrites of live URLs. These are the seed parents the sub-pages link to most: crystal-grids (133 inbound), mohs-hardness-scale (93), ethical-crystal-sourcing (83), are-online-crystals-real (83), how-to-program-crystals (83), lab-created-vs-natural (83) | 35 | 28 Sep–2 Oct | wave 0 |
| 2 | Purpose guides (25): 7 rewrites in place, 3 renames or consolidations with redirects, 15 new. Ship the hub → purpose-guide template link in the same deploy | 25 | 28 Sep–2 Oct | wave 1, redirect fix |
| 3a | P1 stones, all their gap pages: pyrite 7, amethyst 5, jade 6, tortoise-ring 6, tiger-eye 5, rose-quartz 5 | 34 | 5–9 Oct | waves 1–2 |
| 3b | P2 stones by demand: lava-stone 7, lapis-lazuli 7, garnet 7, black-onyx 6, aquamarine 7, black-tourmaline 6, peridot 8, turquoise 8, larvikite 8, aventurine 6, moldavite 6, obsidian 8, black-obsidian 8 | 92 | 5–9 Oct | 3a checked |
| 4 | Pairings (50) | 50 | 12–16 Oct | canonical fix, wave 2 |
| 5a | P3 stones with over 100 impressions in 16 months (23 stones: labradorite, cats-eye, citrine, opal, moss-agate, opalite, moonstone, indian-agate, malachite, hematite, hematoid-quartz, enhydro-agate, selenite, crazy-lace-agate, green-opal, lepidolite, howlite, amazonite, diamond, fluorite, blue-tigers-eye, blue-lace-agate, pink-agate) | 176 | 12–16 Oct | wave 3 |
| 5b | P3 stones with 1–99 impressions (8 stones: green-goldstone, calcite, black-agate, botswana-agate, yellow-calcite, clear-quartz, carnelian, larimar) | 63 | 19–23 Oct | 5a |
| 5c | P3 stones with no measured impressions (34 stones, agate through white-quartz) | 271 | 19–30 Oct | 5b |
| 6 | Angel numbers (30), plus nav, index and sitemap inclusion | 30 | 26–30 Oct | canonical fix |

Total 776. Waves 5b, 5c and 6 are the "bets" from the topical map's verdict; they are last so the measurement window on waves 3 and 5a can inform whether to hold them. Holding them costs nothing (the drafts exist); shipping them without a signal is the default because the pages are written and a complete task grid is what makes a hub read as authoritative.

## Per-wave runbook

Same steps every wave; nothing is done by hand in the admin panel.

1. **Sync review edits.** Run the Drive check (list docs whose modifiedTime is later than the last `docs/sro` commit). Port accepted edits into the markdown, re-run `python3 docs/sro/check_draft.py` on the wave's files, commit.
2. **Import locally.** `bin/rails "sro:import[wave:N]"` against the dev database (the task reads `docs/sro/waves.yml`, generated by `sro:waves` from `drafts-index.csv`, and is idempotent: re-running rewrites content from markdown and touches `updated_at`). Use `DRY_RUN=1` first; it prints creates, updates and skips. Links whose target is not yet live are rendered as plain text and listed at the end of the run; after the wave that ships those targets, run `bin/rails "sro:import[published]"` to restore them on every already-published page.
3. **Audit locally.** `bin/rails sro:audit[wave:N]` on port 3010: every wave URL returns 200; every internal href on those pages returns 200 or 301; tables survived the sanitizer; no `Draft metadata` or front-matter text leaked; sitemap lists the new URLs; renamed legacy URLs 301. Open five pages per template in the browser.
4. **Deploy code if anything under `app/`, `lib/` or `db/` changed.** `bin/rails zeitwerk:check`, then `bin/fly deploy`. `docs/` is not dockerignored, so the drafts ship inside the image.
5. **Import on prod.** Wake the machine (`curl https://writeralpha.com/up`), dry-run first (`bin/fly ssh console -C "/rails/bin/rails sro:import[wave:N] DRY_RUN=1"`, the counts must match the local run), then the same command without `DRY_RUN`. Never run `db:seed` on prod (see the prod-content-sync note: it clobbers HTML content with plain text).
6. **Verify on prod.** Same audit against https://writeralpha.com. Spot-check one URL per template with a real browser and with `curl -I`.
7. **Search Console.** Resubmit the sitemap; request indexing for the wave's ten highest-demand URLs.
8. **Record.** Append rows to `docs/sro/observations.csv` (url, wave, published_on) and set `status=published` for those rows in `drafts-index.csv` and in the Drive index sheet. Commit.

Rollback for a wave is the reverse: articles set `published=false`; sub-pages have the content column nulled, which returns them to 404 and drops them from the sitemap. Neither loses the draft, which stays in git.

## What to measure and the stop rules

Record per URL at 14 and 28 days after each wave, from GSC: indexed (yes/no), impressions, clicks, average position. Aggregate per stone (hub plus its sub-pages) and per task type.

- **Indexing.** If fewer than 70% of a wave's URLs are indexed at 28 days, pause the next wave and look at crawl stats and internal link depth before adding more.
- **Bet types.** At 8 weeks after wave 3, compare affirmations, combinations and sleeping-with pages of the 19 P1/P2 stones with the same stones' cleanse, identify and price pages. If the bet types average under a tenth of the impressions of the others, stop extending them to any future stones and do not rewrite the legacy ones; already-published pages stay.
- **Price guides.** 83 of 84 record an unverified retail range. At 8 weeks, if they draw no clicks, plan one maintained price reference page and let the per-stone pages route to it rather than writing 84 updates.
- **Rewrites.** For the 19 rewritten live URLs, compare 28-day clicks before and after; a drop of more than a third on any one page is a review trigger, not an automatic revert.

## Decisions taken in this plan (change them here if you disagree)

- Markdown in the repo is the import source; Google Docs are for review only.
- An article's section comes from its category first (`Article::SECTION_BY_CATEGORY`), with the slug shape as the fallback for legacy rows. The import sets the category on every row it touches. This is what keeps `/learn/gemstone-vs-crystal-vs-mineral` out of `/compare/`.
- Cross-wave links are deferred, not published broken. The earlier claim that articles link only to live hubs was wrong: wave 1 had 24 links into wave 2 and wave 3 pages.
- Whole stones ship together; the order inside a wave is by 16-month impressions.
- Sub-page H1s come from the drafts if the `sub_page_meta` column is added in wave 0; otherwise from the existing template.
- Em dashes (present in 773 drafts) are left as written. If house style changes, replace them at import time, not in the drafts.
- New articles ship without a featured image; the Open Graph image falls back to the site default. Images are a later pass.
- The 119 legacy sub-pages and the 85 thin hub bodies are not touched by this plan; they are the next content pass, after wave 5a has 28 days of data.

## Log

- **2026-09-19, wave 0.** Branch merged to main. Added kramdown, `sro:import` / `sro:audit` / `sro:waves`, table tags in the sanitizer and `.article table` styles, category-first canonical section, redirect lookup on article routes, `gemstones.sub_page_meta`, the six redirect rows (inert until wave 2/3), `docs/sro/waves.yml`. All 776 drafts parse and convert in a dry run. Baseline GSC export still to do; Search Console keeps 16 months of history, so the pre-publish range can be exported later.
- **2026-09-19, wave 1.** 35 pages live on prod (24 new, 11 rewrites). Prod audit: 35 pages, 427 link checks, PASS. Sitemap grew from 268 to 292 URLs. 24 links to 21 wave 2 and wave 3 pages are deferred as text. Incident: the first deploy stored `sub_page_meta` as a Postgres `json` column, which has no equality operator, so `/gemstones` and the filter pages returned 500 for about 20 minutes until the column was changed to JSON text. Lesson: Postgres-only behaviour does not show up on the SQLite dev database; the prod audit caught it.
