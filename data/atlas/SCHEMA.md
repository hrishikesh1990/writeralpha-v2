# Atlas stone schema

One YAML file per live stone: `data/atlas/stones/<slug>.yml`, slug from `data/atlas/live_slugs.txt`.
Validate with `bin/atlas-validate [files]` (no Rails needed). Gold examples: `amethyst.yml` (easy quartz),
`malachite.yml` (toxic, soft), `selenite.yml` (water-soluble). Match their depth, tone and honesty.

The Atlas powers safety checkers, a stone finder, a compatibility checker, real-or-fake tests and
birthstone calculators that real people act on. **A wrong "safe in water" or a missing toxicity warning
damages someone's stone or health.** Physical facts must be verifiable; tradition must be labelled as tradition.

## Fields

| Key | Type | Notes |
|---|---|---|
| slug, name | string | slug = filename |
| aka | list | other names people search, e.g. `[purple quartz]` |
| kind | enum | `mineral` (a species), `variety` (of a species, e.g. amethyst of quartz), `rock` (lava, jasper, larvikite), `mineraloid` (opal, obsidian, moldavite), `organic`, `glass` (opalite, goldstone, cherry quartz), `synthetic`, `treated` (coated/dyed/heat-crackled as the defining feature: angel aura, crackle quartz, rainbow hematite), `jewellery` (an object, e.g. tortoise ring) |
| species, family, formula, crystal_system | string | mineralogy; `null` when not applicable (glass, rock) |
| mohs | `[min, max]` | numbers 1–10; for jewellery use the usual metal/material |
| colors, origins | list | lower-case colours; main producing countries |
| summary | 40–400 chars | what it is, plus the one care fact that matters most |
| safety.water / salt / sun / sleep / wear | `{verdict, reason}` | verdicts below; reason 15–300 chars, concrete and physical |
| safety.toxicity | `{level, reason}` | `none`, `low` (handle normally, no elixirs), `caution` (toxic dust or leaching: copper, lead, arsenic, aluminium-fluoride, asbestos-like fibres) |
| safety.elixir | enum | `direct` (only inert, non-porous, non-toxic, Mohs ≥ 6), `indirect` (stone in a sealed glass inside the water), `never` (toxic or soluble) |
| tradition.chakras | 1–4 | root sacral solar_plexus heart throat third_eye crown |
| tradition.elements | 1–2 | fire earth air water |
| tradition.planets | 0–3 | western: sun moon mercury venus mars jupiter saturn uranus neptune pluto |
| tradition.vedic_planet | enum or null | surya chandra mangal budh guru shukra shani rahu ketu. Only for Navaratna stones and their recognised substitutes (upratna); otherwise `null` |
| tradition.zodiac | 1–5 | the signs the stone is most commonly assigned to |
| tradition.intentions | 3–8 | from: peace-calm concentration protection love wealth confidence creativity grounding healing sleep communication intuition transformation courage emotional-balance anxiety self-love grief luck energy clarity motivation spiritual-growth career friendship |
| tradition.energy | enum | calming energizing grounding balancing |
| tradition.birth_months | map | `modern` = AGTA/Jewelers of America list; `traditional` = pre-1912 lists; `other` = widely cited alternates. `{}` if none |
| cautions | 2–8 | `{who, why, basis}`, basis `physical` or `tradition`. This feeds "who should not wear X" — the site's biggest search demand. Lead with physical cautions. Tradition entries must say "tradition says", "in Vedic astrology", etc. **No medical claims** (no "lowers blood pressure"); you may report that a tradition *advises against* something |
| zodiac_cautions | 0–4 | `{sign, why}` signs traditionally told to avoid it; must not overlap tradition.zodiac. Only when a real tradition says so (mostly Vedic planetary enmity). Empty is fine |
| identify.common_fakes | 1–6 | what is actually sold as this stone |
| identify.tests | 4–8 | `{id, weight 1–3, how, real, fake}`. ids: hardness streak bubbles temperature weight magnification uv price color inclusions light magnet scratch acetone water_dissolve flame shape seller certificate refractive. weight 3 = near-conclusive, 1 = weak hint. Flag destructive tests in `how` |
| pairs.good | 3–8 | `{slug, why}` slugs from live_slugs.txt where possible |
| pairs.avoid | 0–4 | only with a stated reason (opposed energy in tradition, Vedic enmity, or physical: one scratches the other, one can't share a cleansing method) |
| price | `{tier, note}` | tier budget mid premium luxury; note gives realistic ranges without inventing precise figures |
| names | map | optional local names: hi bn es ta te mr. Only when you are confident; include script, e.g. `Jamunia (जमुनिया)` |
| sources | 2–8 https URLs | mineralogy (mindat.org, minerals.net, geology.com, gia.edu, gemsociety.org) plus tradition sources where used. Every URL must resolve |

## Verdicts

- water: `safe` (non-porous, insoluble, Mohs ≥ ~5.5, no toxic content) · `brief` (quick rinse OK, never soak: porous, glued, or soft-ish) · `avoid`
- salt: `safe` · `avoid` (porous, soft < 5, metallic/iron-bearing that rusts, glued/coated/treated, or anything water-`avoid`)
- sun: `safe` · `limit` (fades, heat-sensitive, or contains water) · `avoid` (fades fast: e.g. rose quartz, kunzite, fluorite, many dyed stones)
- sleep: `ok` · `caution` (toxic, sharp, very fragile, or strongly "energizing" in tradition)
- wear: `daily` · `care` (scratches, porous, reacts to chemicals) · `special` (too soft or fragile to wear regularly)

Iron-bearing stones (hematite, pyrite, magnetite, many "magnetic hematite" rings) rust: water `brief` or `avoid`, salt `avoid`.
Pyrite in damp conditions can oxidise and release sulfuric acid; say so.
