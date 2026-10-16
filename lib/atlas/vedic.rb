# frozen_string_literal: true

module Atlas
  # Jyotish reference tables: Navaratna, rashi lords, natural planetary
  # friendships (naisargika maitri, after Brihat Parashara Hora Shastra) and
  # Hindi / Bengali names. Shown on the site as tradition, never as fact.
  module Vedic
    module_function

    GRAHAS = {
      "surya"   => { en: "Sun",     hi: "Surya (सूर्य)",    bn: "Surya (সূর্য)",     western: "sun" },
      "chandra" => { en: "Moon",    hi: "Chandra (चंद्र)",  bn: "Chandra (চন্দ্র)",  western: "moon" },
      "mangal"  => { en: "Mars",    hi: "Mangal (मंगल)",   bn: "Mangal (মঙ্গল)",   western: "mars" },
      "budh"    => { en: "Mercury", hi: "Budh (बुध)",      bn: "Budh (বুধ)",       western: "mercury" },
      "guru"    => { en: "Jupiter", hi: "Guru (गुरु)",      bn: "Brihaspati (বৃহস্পতি)", western: "jupiter" },
      "shukra"  => { en: "Venus",   hi: "Shukra (शुक्र)",   bn: "Shukra (শুক্র)",    western: "venus" },
      "shani"   => { en: "Saturn",  hi: "Shani (शनि)",     bn: "Shani (শনি)",      western: "saturn" },
      "rahu"    => { en: "Rahu (north node)", hi: "Rahu (राहु)", bn: "Rahu (রাহু)",  western: nil },
      "ketu"    => { en: "Ketu (south node)", hi: "Ketu (केतु)", bn: "Ketu (কেতু)",  western: nil }
    }.freeze

    # Primary Navaratna stone per graha. `slug` = live hub on writeralpha.com
    # (nil when the site has no page for it yet). `substitutes` = upratna
    # commonly sold in India as affordable alternatives (slugs where live).
    NAVARATNA = {
      "surya"   => { stone: "Ruby",            hi: "Manik (माणिक)",     bn: "Chuni (চুনি)",       slug: "ruby",     substitutes: %w[garnet sunstone] },
      "chandra" => { stone: "Pearl",           hi: "Moti (मोती)",       bn: "Mukta (মুক্তা)",     slug: nil,        substitutes: %w[moonstone] },
      "mangal"  => { stone: "Red Coral",       hi: "Moonga (मूंगा)",    bn: "Probal (প্রবাল)",    slug: nil,        substitutes: %w[carnelian red-jasper] },
      "budh"    => { stone: "Emerald",         hi: "Panna (पन्ना)",     bn: "Panna (পান্না)",     slug: "emerald",  substitutes: %w[peridot jade] },
      "guru"    => { stone: "Yellow Sapphire", hi: "Pukhraj (पुखराज)",  bn: "Pokhraj (পোখরাজ)",  slug: "sapphire", substitutes: %w[citrine] },
      "shukra"  => { stone: "Diamond",         hi: "Heera (हीरा)",      bn: "Hira (হীরা)",        slug: "diamond",  substitutes: %w[opal clear-quartz] },
      "shani"   => { stone: "Blue Sapphire",   hi: "Neelam (नीलम)",     bn: "Neela (নীলা)",       slug: "sapphire", substitutes: %w[amethyst lapis-lazuli] },
      "rahu"    => { stone: "Hessonite Garnet", hi: "Gomed (गोमेद)",     bn: "Gomed (গোমেদ)",      slug: "garnet",   substitutes: [] },
      "ketu"    => { stone: "Cat's Eye (chrysoberyl)", hi: "Lehsunia (लहसुनिया)", bn: "Baidurya (বৈদূর্য)", slug: "cats-eye", substitutes: %w[tiger-eye] }
    }.freeze

    # Rashi (sidereal sign) → lord, with Hindi and Bengali names.
    RASHI = {
      "aries"       => { lord: "mangal",  hi: "Mesh (मेष)",          bn: "Mesh (মেষ)" },
      "taurus"      => { lord: "shukra",  hi: "Vrishabh (वृषभ)",     bn: "Brisha (বৃষ)" },
      "gemini"      => { lord: "budh",    hi: "Mithun (मिथुन)",      bn: "Mithun (মিথুন)" },
      "cancer"      => { lord: "chandra", hi: "Kark (कर्क)",         bn: "Karkat (কর্কট)" },
      "leo"         => { lord: "surya",   hi: "Singh (सिंह)",        bn: "Singha (সিংহ)" },
      "virgo"       => { lord: "budh",    hi: "Kanya (कन्या)",       bn: "Kanya (কন্যা)" },
      "libra"       => { lord: "shukra",  hi: "Tula (तुला)",         bn: "Tula (তুলা)" },
      "scorpio"     => { lord: "mangal",  hi: "Vrishchik (वृश्चिक)", bn: "Brishchik (বৃশ্চিক)" },
      "sagittarius" => { lord: "guru",    hi: "Dhanu (धनु)",         bn: "Dhanu (ধনু)" },
      "capricorn"   => { lord: "shani",   hi: "Makar (मकर)",         bn: "Makar (মকর)" },
      "aquarius"    => { lord: "shani",   hi: "Kumbh (कुंभ)",        bn: "Kumbha (কুম্ভ)" },
      "pisces"      => { lord: "guru",    hi: "Meen (मीन)",          bn: "Meen (মীন)" }
    }.freeze

    # Naisargika maitri: friends and enemies; anything else is neutral.
    FRIENDS = {
      "surya" => %w[chandra mangal guru], "chandra" => %w[surya budh],
      "mangal" => %w[surya chandra guru], "budh" => %w[surya shukra],
      "guru" => %w[surya chandra mangal], "shukra" => %w[budh shani],
      "shani" => %w[budh shukra], "rahu" => %w[budh shukra shani], "ketu" => %w[mangal shukra shani]
    }.freeze
    ENEMIES = {
      "surya" => %w[shukra shani], "chandra" => %w[],
      "mangal" => %w[budh], "budh" => %w[chandra],
      "guru" => %w[budh shukra], "shukra" => %w[surya chandra],
      "shani" => %w[surya chandra mangal], "rahu" => %w[surya chandra mangal], "ketu" => %w[surya chandra]
    }.freeze

    # :friend, :neutral or :enemy, from a's point of view.
    def relation(a, b)
      return :same if a == b
      return :friend if FRIENDS.fetch(a, []).include?(b)
      return :enemy if ENEMIES.fetch(a, []).include?(b)

      :neutral
    end

    # Mutual: worst of the two directions (the cautious reading most
    # practitioners give when asked "can I wear X with Y").
    def mutual(a, b)
      r = [relation(a, b), relation(b, a)]
      return :same if r.include?(:same)
      return :enemy if r.include?(:enemy)
      return :friend if r.all?(:friend)

      :neutral
    end

    def rashi_lord(sign) = RASHI.dig(sign, :lord)
    def lucky_stone_for(sign) = NAVARATNA[rashi_lord(sign)]
  end
end
