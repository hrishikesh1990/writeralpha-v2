# WriterAlpha topical map (SRO pass, September 2026)

## In a nutshell

1. WriterAlpha is one coherent subject, crystals and gemstones, built around 85 stone hubs. The map keeps that spine and organises everything else as either a stone-specific task (the 9 sub-page types) or a cross-stone question (purpose, care, science, comparison, pairing).
2. Six expertise areas (Macros): M1 Stone Atlas, M2 Crystals by Purpose, M3 Care and Practice, M4 Science, Identification and Buying, M5 Crystal Combinations, M6 Angel Numbers (outer). Angel numbers stay because they were already planned, but they are explicitly outer and bridged back to the core through meditation and journaling pages.
3. Demand evidence comes from Google Search Console (16 months, per stone and per intent), not from generated keyword lists. Pyrite alone carries 48,102 stone impressions; the top 6 stones carry 102,000 of the 150,000 total. Sub-page drafting is ordered by that demand.
4. Scope of this pass: 776 drafts. 636 gemstone sub-pages that are gaps today (83 stones plus 6 tortoise-ring pages), and 140 articles (25 purpose guides, 50 pairings, 20 learn, 10 comparisons, 30 angel numbers, 4 live care pages rewritten). Hub body copy is out of scope. Nothing is published; every draft is a Google Doc in the review folder.
5. Decisions that change the existing plan: 1 page dropped as a duplicate, 1 retained untouched, 10 pages deferred as no-value permutations, 8 legacy URLs consolidated into 6 new owners with redirects, 1 planned slug corrected to keep a live URL.
6. Every page has one owned question, one answer frame (explanation, instruction, evaluation or comparison), and a link plan of 3,700+ passage-level links with a stated reason each. Metaphysical claims are written as tradition, physical facts are checked, and no page pretends to hands-on testing. The site has no monetization yet, so no page carries a commercial role.

## What is the site actually about, and where does it stop?

WriterAlpha started life as a naming-plus-gemstones WordPress site. The naming half was retired in August 2026 (410s in routes). What remains is a gemstone atlas: 85 published stone hubs, each with up to 9 sub-page types (meaning, who-should-not-wear, can-go-in-water, how-to-identify, sleeping-with, how-to-cleanse, combinations, affirmations, price-guide), 11 taxonomy filters (colour, zodiac, healing power, birth month, and so on), and 23 legacy articles.

So the subject boundary is: any question a reader has about a specific stone, plus the cross-stone questions that a stone page cannot answer alone (which stones for X, how to care for stones in general, how gemstones form, how to tell real from fake, what pairs with what). Angel numbers sit outside that boundary. They are kept because the existing plan includes them and they share the audience, but they are labelled outer and never linked from core stone pages; only the reverse.

## How is the map structured?

The SRO framework uses three planning levels: Macro (expertise area), Seed (cluster of related needs), Node (one focused answer). They are planning concepts, not URL levels. The URL structure already exists and is preserved.

| Macro | Seeds | Nodes in this pass | URL pattern |
|---|---|---|---|
| M1 Stone Atlas | 9 task seeds: meaning, cautions, water, identify, sleep, cleanse, combinations, affirmations, price | 636 sub-pages (gaps only; 155 sub-pages already live are not redrafted) | /gemstones/:stone/:task |
| M2 Crystals by Purpose | S2.1 emotional wellbeing, S2.2 relationships, S2.3 protection and grounding, S2.4 confidence, focus and success, S2.5 practice and spirituality | 25 purpose guides | /crystals/crystals-for-:purpose |
| M3 Care and Practice | S3.1 cleansing, charging and safety; S3.2 practices (grids, pendulums, meditation, journaling, storage, programming, sprays) | 15 learn articles | /learn/:slug |
| M4 Science, Identification and Buying | S4.1 comparisons; S4.2 identification and buying (real vs fake, ethical sourcing, lab-grown, chakra bracelets); S4.3 gemstone science (formation, Mohs, cuts, lustre, definitions, healing evidence) | 10 compare + 10 learn | /compare/:a-vs-:b, /learn/:slug |
| M5 Crystal Combinations | one seed per anchor stone (amethyst, rose quartz, citrine, black tourmaline, moldavite and others) | 50 pairing articles | /crystals/:a-and-:b-together |
| M6 Angel Numbers (outer) | S6.1 repeating numbers, S6.2 mixed sequences | 30 pages | /angel-numbers/:n |

How the levels connect in practice: a stone hub (Node of M1, but acting as the parent for its 9 sub-pages) links down to each task page; each task page links up to its hub, sideways to one or two sibling tasks where the reader plausibly needs them (water safety to cleansing, identification to price), and up to the site-wide guide it specialises (every "can X go in water" page points to the general water-safe crystals guide). Purpose guides link to stone hubs, and stone hubs will link back to the purpose guides their healing-power tags match (that reverse link is a template change, noted below).

## What did the demand data say, and how did it change the order of work?

The repo's content_backlog.csv scores 646 sub-page gaps by GSC impressions per stone (16 months) and per intent. Two things stand out.

Demand is concentrated in a few stones. Pyrite has 48,102 impressions, amethyst 12,883, jade 11,675, tortoise ring 11,661, tiger's eye 10,026, rose quartz 7,431. Together that is 102,000 of the 149,835 unique stone impressions (68%). Only 30 gaps are P1 and 70 are P2; 546 are P3 with little or no measured demand.

Demand also concentrates in a few intents. Summed intent impressions: meaning 4,200, how-to-cleanse 2,430, can-go-in-water 320, price-guide 300, how-to-identify 241, who-should-not-wear 143. Affirmations, combinations and sleeping-with show 0 measured impressions for the gap pages. That does not prove nobody wants them; it does mean they are editorial bets, not evidenced demand, and they are drafted last.

So the drafting order is: pyrite first, then the P1 and P2 stones by impressions, then P3 stones. Within each stone, all its gap pages are drafted together by one writer so the physical facts (hardness, chemistry, treatments) are researched once and stay consistent across the 6 to 8 pages.

One reversal worth noting: tortoise ring is not a mineral, and the first pass deferred it as a product permutation. GSC disagrees (11,661 impressions, the fourth-highest stone). It is back in for the 6 pages that have a plausible question (meaning, cleanse, water, identify, price, combinations) and stays deferred for the 2 that do not (sleeping-with, affirmations). Hematite rings, the other product page, has 0 impressions and stays deferred.

## Which planned pages were dropped, merged, corrected or deferred?

The existing 850-row map was mostly kept. These are the changes, with the reason for each.

| Change | Pages | Why |
|---|---|---|
| Drop | /learn/lab-grown-vs-natural | Same question as /compare/lab-created-vs-natural-gemstones. One owner. |
| Retain untouched | /learn/how-to-identify-kimberlite | Accurate, useful, low demand. Old is not a reason to rewrite. |
| Defer | /gemstones/hematite-rings/* (8), /gemstones/tortoise-ring/sleeping-with and /affirmations | Product pages; the task has no plausible reader question. Permutations add no distinct value. |
| Consolidate + redirect | /crystals/best-crystals-for-sleep-enhance-sleep-quality-naturally and /learn/crystals-to-sleep-with-under-your-pillow → /crystals/crystals-for-sleep | Two legacy pages own one intent. The new page covers both (which stones; how to use them at night) in labelled sections. |
| Rename + redirect | /crystals/11-best-crystals-for-grief → /crystals/crystals-for-grief; /crystals/best-crystals-for-connection-with-others → /crystals/crystals-for-connection | Same intent, slug brought in line with the pattern. |
| Merge into stone page + redirect | /learn/how-to-tell-if-black-tourmaline-is-real → /gemstones/black-tourmaline/how-to-identify; /learn/aura-quartz-healing-properties → /gemstones/angel-aura-quartz/meaning (already live) | Stone-specific questions belong on the stone's task page. |
| Keep live slug | planned /compare/amethyst-vs-purple-quartz → existing /compare/purple-quartz-vs-amethyst | A live URL with history beats a tidier slug. |
| Add to map | /learn/what-crystals-can-go-in-water, /learn/how-to-cleanse-crystals, /learn/how-to-charge-crystals, /learn/how-to-know-if-a-chakra-bracelet-is-real | Live pages missing from the map; the first three are the Seed parents for 300+ stone sub-pages, so they are rewritten to that role. |
| Keep both, define frames | /crystals/crystals-for-meditation (which stones: evaluation) and /learn/crystal-meditation (how to practise: instruction) | Different tasks. Each links to the other at the hand-off point. |

Two planned pages are kept with a caveat. /crystals/crystals-for-healing is the weakest intent on the map (healing what?); it is framed as a beginner's general-wellbeing set that also explains what crystal healing is and links to the evidence article, rather than another list. The 30 angel-number pages are outer content; each one carries a bridge section on stones people use while reflecting on the number, which is the only reason they belong on this domain at all.

## How is each page kept honest?

The niche-sro skill set has one rule that matters more than the rest for this niche: distinguish what is observed from what is believed. Crystal content fails that rule constantly, so the writing contract makes it mechanical.

- Physical facts (Mohs hardness, chemistry, cleavage, solubility, toxicity, colour cause, treatments) must be right and are checked against mineralogical references (Mindat, GIA, Gemdat, USGS). These are the facts that make water, sun, salt and cleaning advice correct, and they are also where competitors are most often wrong.
- Metaphysical, healing and astrological associations are written as tradition: "is traditionally associated with", "practitioners use it for", "in Vedic astrology it is linked to". Never as outcomes. "Reduces anxiety" is not allowed; "is used by people seeking calm" is.
- No hands-on testing exists, so none is implied. No invented search volumes, quotes, reviews or percentages. Price guides give ranges only where current retail evidence was found, with unit, date and the caveat that grade and seller move the price; otherwise they explain price drivers and say the range could not be verified.
- Pages that touch sleep, anxiety, grief, pregnancy or healthcare workers carry one plain sentence that crystals are a complementary practice, not treatment.
- Every H2 section has to survive being read alone: subject named, answer first, conditions attached. A mechanical checker enforces front matter, one H1, an opening answer under 75 words, no banned phrases (we tested, proven, cures, Key Takeaways, journey, unlock), link resolution against the site URL inventory, and no FAQ dumps.

## What does the link plan look like?

3,700+ proposed links, each with a source page, destination, relationship and reason. The patterns:

| Relationship | Example | Reason |
|---|---|---|
| Parent | /gemstones/pyrite/how-to-cleanse → /gemstones/pyrite | Full profile and properties |
| Seed parent | /gemstones/pyrite/how-to-cleanse → /learn/how-to-cleanse-crystals | The general method page this one specialises |
| Sibling (only where the reader needs it) | how-to-cleanse ↔ can-go-in-water; how-to-identify ↔ price-guide; meaning → combinations, affirmations | Water is one cleansing method; price is an identification signal |
| Lateral | /gemstones/citrine/meaning → /crystals/crystals-for-money | Stone appears in that purpose guide (from its healing-power tags) |
| Next step | how-to-cleanse → /learn/how-to-charge-crystals | Charging follows cleansing |
| Bridge (outer to core) | /angel-numbers/444 → /crystals/crystals-for-meditation | The only link direction allowed for angel numbers |

Siblings are not linked mechanically. A price guide does not link to affirmations. Anchors are descriptive of the destination and chosen by the writer in the passage where the need arises; there is no related-posts block.

Two template-level link changes are recommended but not part of the drafting: stone hubs should list their live sub-pages as a task menu (they already do), and hubs should link to the purpose guides matching their healing-power tags once those guides exist. Both are code changes in the Rails views, not content.

## What is deliberately not in this pass?

- Hub body copy for the 85 stones. Most hubs are thin (one or two sentences from the seed file). They are the parents of everything and should be the next pass, written after the sub-pages exist so the hub can summarise and route rather than repeat.
- Taxonomy filter page copy (colour, zodiac, healing power intros). Generated by the app; an intro paragraph per filter is a small later job.
- The 155 live sub-pages. They are legacy WordPress text with tables of contents and padding. They should be rewritten to the same contract, but they are not gaps, so they wait.
- Redirect and 410 implementation for the consolidations above. Listed in the ledger; needs a code change in db/seeds/05_redirects.rb.
- Measurement. There is no baseline beyond GSC impressions. Before publishing, record current clicks and impressions per stone so the effect of the sub-pages can be seen. The measurement skill in the package covers the observation format.

## Honest verdict

The map is sound because it did not start from scratch: the URL structure, the 85 stones and the 9 task types were already the right shape, and GSC shows real demand concentrated in exactly the pages that were missing (pyrite, amethyst, jade, tiger's eye meaning and cleanse pages). Drafting those first is the evidence-backed part.

The rest is a bet. 546 of the 636 sub-pages have no measured demand, and three task types (affirmations, combinations, sleeping-with) show zero intent impressions across the gaps. They were drafted because the brief was to write everything, and because a complete task grid per stone is what makes a hub feel authoritative. But if the first measurement window shows those pages doing nothing, the maintenance decision should be to stop extending them to new stones, not to write more.

The pages most likely to disappoint are the price guides. Retail prices for tumbled stones and beads are inconsistent and undated across the web; several drafts will say "we could not verify a range" and explain drivers instead. That is the correct outcome under the evidence rules, and a reason to consider a single well-maintained price reference page later rather than 85 thin ones.

Ledgers (inventory, network, links, site context) accompany this document in the same folder and in the repo under docs/sro/.
