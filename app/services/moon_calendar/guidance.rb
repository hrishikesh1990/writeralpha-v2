# frozen_string_literal: true

module MoonCalendar
  # What to do with crystals at a given lunation. The sign and element of the
  # Moon pick the stones to charge (crystal and astrological tradition, always
  # labelled as such); the water, sun and toxicity verdicts come from the Atlas
  # and are physical facts. Pure Ruby: pass any objects that respond to the
  # Atlas::Stone accessors (Atlas::Stone or AtlasEntry).
  module Guidance
    SIGN_THEMES = {
      "aries" => { keywords: "beginnings, courage and initiative",
                   intentions: %w[courage motivation energy confidence],
                   full: "Astrological tradition reads a full moon in Aries as a moment to notice where you have been holding back, and to act on something you have put off.",
                   new: "A new moon in Aries is traditionally a time to plant a bold, simple intention and take the first small step." },
      "taurus" => { keywords: "steadiness, comfort and the senses",
                    intentions: %w[grounding wealth self-love peace-calm],
                    full: "In astrological tradition a full moon in Taurus highlights what is steady, enough and worth keeping, and asks what you are holding on to out of habit.",
                    new: "A new moon in Taurus is traditionally a quiet time to set intentions around security, savings, home comforts and patience." },
      "gemini" => { keywords: "communication, curiosity and ideas",
                    intentions: %w[communication clarity concentration friendship],
                    full: "Astrologers describe a full moon in Gemini as bringing conversations, messages and loose ends to the surface, a good night to say what you have been rehearsing.",
                    new: "A new moon in Gemini is traditionally used to set intentions about learning, writing and honest conversations." },
      "cancer" => { keywords: "home, memory and feeling",
                    intentions: %w[emotional-balance peace-calm sleep self-love],
                    full: "A full moon in Cancer, the sign the Moon rules, is considered the most Moon-like of all in tradition: a night for home, family, memory and tenderness toward yourself.",
                    new: "A new moon in Cancer is traditionally a time to set intentions around home, belonging and looking after your own feelings." },
      "leo" => { keywords: "confidence, creativity and warmth",
                 intentions: %w[confidence creativity self-love courage],
                 full: "In tradition a full moon in Leo shines a light on pride, play and recognition: what you want to be seen for, and where you dim yourself.",
                 new: "A new moon in Leo is traditionally a time to set intentions about creative work, self-expression and generosity." },
      "virgo" => { keywords: "order, routine and practical care",
                   intentions: %w[clarity concentration grounding anxiety],
                   full: "Astrological tradition links a full moon in Virgo with sorting, editing and tidying up, a night to review habits and let go of clutter.",
                   new: "A new moon in Virgo is traditionally used to set intentions about routines, workspaces and small improvements that last." },
      "libra" => { keywords: "balance, partnership and fairness",
                   intentions: %w[love friendship emotional-balance peace-calm],
                   full: "A full moon in Libra is read in tradition as bringing relationships and the balance of give and take into view.",
                   new: "A new moon in Libra is traditionally a time to set intentions about harmony, partnership and fair agreements." },
      "scorpio" => { keywords: "depth, release and transformation",
                     intentions: %w[transformation protection grief healing],
                     full: "In astrological tradition a full moon in Scorpio is intense and private: a night for letting go of what has run its course.",
                     new: "A new moon in Scorpio is traditionally a time for honest, private intentions about change and what you are ready to release." },
      "sagittarius" => { keywords: "optimism, travel and big-picture truth",
                         intentions: %w[luck spiritual-growth motivation courage],
                         full: "A full moon in Sagittarius is traditionally associated with perspective, plans that need room to grow and a wider view of where you are headed.",
                         new: "A new moon in Sagittarius is traditionally a time to set intentions about learning, journeys and what you believe." },
      "capricorn" => { keywords: "discipline, structure and long goals",
                       intentions: %w[career concentration wealth grounding],
                       full: "Astrologers read a full moon in Capricorn as a checkpoint on long-term goals: what has been built, and what is no longer worth the effort.",
                       new: "A new moon in Capricorn is traditionally a time to set patient, practical intentions about work and responsibilities." },
      "aquarius" => { keywords: "community, ideas and independence",
                      intentions: %w[clarity friendship creativity communication],
                      full: "In tradition a full moon in Aquarius shines on friendships, groups and unconventional ideas, and on where you want more freedom.",
                      new: "A new moon in Aquarius is traditionally used to set intentions about community, innovation and being yourself." },
      "pisces" => { keywords: "dreams, intuition and compassion",
                    intentions: %w[intuition spiritual-growth sleep peace-calm],
                    full: "A full moon in Pisces is described in tradition as soft and dreamy: a night for rest, imagination and forgiving yourself and others.",
                    new: "A new moon in Pisces is traditionally a time to set gentle intentions about creativity, rest and spiritual practice." }
    }.freeze

    ELEMENT_NOTES = {
      "fire" => "Fire moons are traditionally paired with warm, energising stones and with work on confidence, motivation and courage.",
      "earth" => "Earth moons are traditionally paired with grounding stones and with practical goals: money, home, routines and patience.",
      "air" => "Air moons are traditionally paired with clarifying stones and with communication, ideas and friendships.",
      "water" => "Water moons are traditionally paired with calming stones and with feelings, intuition, rest and dreams."
    }.freeze

    NAME_NOTES = {
      "Wolf Moon" => "January's full moon is called the Wolf Moon in North American almanac tradition, after winter wolves heard howling in the cold.",
      "Snow Moon" => "February's full moon is the Snow Moon in almanac tradition, named for the heaviest snowfall of the northern winter.",
      "Worm Moon" => "March's full moon is the Worm Moon in almanac tradition, when thawing soil brings earthworms back to the surface.",
      "Pink Moon" => "April's full moon is the Pink Moon in almanac tradition, named for the pink wild phlox that blooms in early spring. The moon itself is not pink.",
      "Flower Moon" => "May's full moon is the Flower Moon in almanac tradition, for the flowers of late spring.",
      "Strawberry Moon" => "June's full moon is the Strawberry Moon in Algonquin tradition, marking the short strawberry harvest.",
      "Buck Moon" => "July's full moon is the Buck Moon in almanac tradition, when new antlers grow on male deer.",
      "Sturgeon Moon" => "August's full moon is the Sturgeon Moon in almanac tradition, when sturgeon were easiest to catch in the Great Lakes.",
      "Corn Moon" => "September's full moon is the Corn Moon in almanac tradition, for the corn harvest.",
      "Harvest Moon" => "The Harvest Moon is the full moon nearest the September equinox. Around it the Moon rises soon after sunset on successive evenings, which once gave farmers extra light for the harvest.",
      "Hunter's Moon" => "The Hunter's Moon follows the Harvest Moon in almanac tradition, when hunters stocked up for the winter.",
      "Beaver Moon" => "November's full moon is the Beaver Moon in almanac tradition, the season for setting beaver traps before the swamps froze.",
      "Cold Moon" => "December's full moon is the Cold Moon in almanac tradition, for the long, cold nights near the northern winter solstice."
    }.freeze
    BLUE_NOTE = "A Blue Moon is the second full moon in one calendar month, counted by the dates in the time zone shown. The Moon does not look blue, and a Blue Moon comes around roughly every two and a half years."

    # Popular stones, used to order the "do not put in water" and "fades in sun" lists.
    POPULAR = %w[selenite malachite pyrite hematite lapis-lazuli turquoise opal moonstone labradorite fluorite calcite
                 amazonite howlite kyanite celestite lepidolite apophyllite angelite amethyst rose-quartz citrine
                 kunzite aquamarine clear-quartz tigers-eye carnelian black-tourmaline obsidian].freeze
    ALWAYS = [["moonstone", "Moonstone"], ["selenite", "Selenite"]].freeze

    Pick = Struct.new(:stone, :why)
    Result = Struct.new(:event, :sign, :element, :theme, :intro, :element_note, :name, :name_note, :blue,
                        :charge, :always, :water_ok, :water_indirect, :water_no, :fade_stones, :steps,
                        :moonlight_note, :weather_note, :weather_stones, :stone_count, keyword_init: true) do
      # "Flower Moon" or, for a second full moon in the month, "Flower Moon (Blue Moon)".
      def title_name = blue ? "#{name} (Blue Moon)" : name
    end

    module_function

    def for_event(event, stones:, name: nil, name_note: nil, blue: false)
      stones = Array(stones)
      theme = SIGN_THEMES.fetch(event.sign)
      full = event.full?
      always_slugs = ALWAYS.map(&:first)

      Result.new(
        stone_count: stones.size, event: event, sign: event.sign, element: event.element, theme: theme,
        intro: event.new? ? theme[:new] : theme[:full],
        element_note: ELEMENT_NOTES.fetch(event.element),
        name: name, name_note: name_note, blue: blue,
        charge: charge_picks(event, stones.reject { |s| always_slugs.include?(s.slug) }, theme),
        always: ALWAYS.map { |slug, label| Pick.new(stones.find { |s| s.slug == slug } || label, nil) },
        water_ok: water_group(stones, "direct"),
        water_indirect: water_group(stones, "indirect"),
        water_no: water_no(stones),
        fade_stones: ordered(stones.select { |s| %w[limit avoid].include?(s.safety("sun")) }),
        weather_stones: ordered(stones.select { |s| %w[avoid brief].include?(s.safety("water")) }),
        steps: steps(full, event.new?),
        moonlight_note: "Moonlight is the one cleansing and charging method that is safe for every stone. It is reflected sunlight, hundreds of thousands of times fainter than the Sun, so it does not fade, heat or dry out anything.",
        weather_note: "Keep soft, porous or water-sensitive stones on a dry indoor windowsill or in a glass dish, not outdoors where dew, rain or humidity can reach them."
      )
    end

    def charge_picks(event, stones, theme)
      sign_ruler = Atlas::Astro::SIGN_RULER[event.sign]
      scored = stones.filter_map do |s|
        why = {}
        score = 0
        if s.zodiac.include?(event.sign)
          score += 4
          why[:zodiac] = "traditionally assigned to #{event.sign_label}"
        end
        if s.elements.include?(event.element)
          score += 2
          why[:element] = "#{Format.indefinite(event.element)}-element stone in tradition"
        end
        if s.planets.include?("moon") || s.planets.include?(sign_ruler)
          score += 2
          why[:planet] = s.planets.include?("moon") ? "a Moon stone in tradition" : "linked to #{sign_ruler.capitalize}, which rules #{event.sign_label}"
        end
        shared = s.intentions & theme[:intentions]
        if shared.any?
          score += [shared.size, 3].min
          why[:intentions] = "used for #{shared.first(2).map { |i| Atlas::INTENTION_LABELS[i].to_s.downcase }.join(' and ')}"
        end
        next if score < 3

        [score, s, why]
      end
      # The most specific reasons first (intentions, planet), so a row of stones does not repeat one phrase.
      scored.sort_by { |score, s, _| [-score, s.name] }.first(6).map do |_, s, why|
        Pick.new(s, %i[intentions planet zodiac element].filter_map { |k| why[k] }.first(2).join("; "))
      end
    end

    # water verdict "safe" and elixir "direct": fine to sit in a bowl of moon water.
    def water_group(stones, elixir)
      ordered(stones.select { |s| s.safety("water") == "safe" && s.elixir == elixir && s.toxicity != "caution" })
    end

    def water_no(stones)
      list = stones.select { |s| %w[avoid brief].include?(s.safety("water")) || s.toxicity == "caution" || s.elixir == "never" }
      ordered(list).map do |s|
        reason =
          if s.toxicity == "caution" && s.toxicity_reason.present? then "Toxic. #{s.toxicity_reason}"
          elsif s.safety("water") == "brief" then "Quick rinse only, never a soak. #{s.safety_reason('water')}"
          else s.safety_reason("water")
          end
        Pick.new(s, reason)
      end
    end

    def ordered(stones)
      stones.sort_by { |s| [POPULAR.index(s.slug) || POPULAR.size, s.name] }
    end

    def steps(full, new_moon)
      if full
        ["Clean each stone first with a soft dry cloth. Dust and oils get in the way more than a lack of moonlight.",
         "Check each stone against the lists on this page: stones that fade in sun are fine under the Moon, and soft or water-sensitive stones stay dry.",
         "Set the stones where moonlight can reach them, such as a windowsill, from dusk. Crystal tradition says clouds do not matter and that the night before or after the full moon works as well as the exact minute.",
         "Collect them before sunrise, and use the time to set one clear intention if you like. This is a ritual: there is no measured physical effect on the stone."]
      elsif new_moon
        ["Wipe each stone clean with a soft dry cloth.",
         "Cleanse them by a method that suits the stone: moonlight, sound, smoke, breath or resting on selenite.",
         "Write down one or two intentions for the coming month. Tradition treats the dark of the moon as a time to begin, not to charge.",
         "Keep the stones with the note, or carry one, as a reminder."]
      else
        ["A quarter moon is a gentle midpoint check. If you set an intention at the new moon, look at it again.",
         "Moonlight at this phase is dimmer, but it is still safe for every stone.",
         "Leave stones on a windowsill overnight if you wish, or wait for the full moon."]
      end
    end
  end
end
