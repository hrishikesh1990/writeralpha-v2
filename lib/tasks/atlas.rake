# frozen_string_literal: true

namespace :atlas do
  desc "Validate every Atlas stone file (same as bin/atlas-validate)"
  task validate: :environment do
    live = File.readlines(Rails.root.join("data/atlas/live_slugs.txt"), chomp: true).reject(&:empty?)
    bad = Dir.glob(File.join(Atlas.dir, "*.yml")).sum do |f|
      errors, = Atlas::Validator.validate(YAML.safe_load_file(f), known_slugs: live)
      errors.each { |e| puts "#{File.basename(f)}: #{e}" }
      errors.any? ? 1 : 0
    end
    abort "#{bad} invalid Atlas files" if bad.positive?
    puts "Atlas OK: #{Atlas.stones.size} stones"
  end

  # The Atlas is the source of truth for a stone's taxonomy. This copies it
  # into the columns and join tables the directory and filter pages read, so
  # /gemstones/zodiac/leo and the tools never disagree. Idempotent; runs on
  # every deploy (fly.toml release_command). DRY_RUN=1 prints the diff only.
  desc "Sync Atlas taxonomy (zodiac, healing powers, element, planet, Mohs, birth month) into gemstones"
  task sync: :environment do
    dry = ENV["DRY_RUN"].present?
    signs = ZodiacSign.all.index_by(&:slug)
    powers = HealingPower.all.index_by(&:slug)
    months = BirthMonth.all.index_by { |m| m.name.downcase }
    changed = 0

    Gemstone.includes(:zodiac_signs, :healing_powers, :birth_month).find_each do |g|
      s = Atlas[g.slug] or next

      want = {
        mohs_hardness: s.mohs_max,
        element: s.elements.first&.capitalize || g.element,
        ruling_planet: s.planets.first&.capitalize || g.ruling_planet,
        birth_month: months[(s.modern_birthstone_for + s.traditional_birthstone_for).first]
      }
      want_signs = s.zodiac.filter_map { |z| signs[z] }
      want_powers = s.intentions.filter_map { |i| powers[i] }
      want_powers = g.healing_powers.to_a if want_powers.empty? # keep filter pages populated

      diff = []
      diff << "mohs #{g.mohs_hardness}→#{want[:mohs_hardness]}" if g.mohs_hardness.to_f != want[:mohs_hardness].to_f
      diff << "element #{g.element}→#{want[:element]}" if g.element != want[:element]
      diff << "planet #{g.ruling_planet}→#{want[:ruling_planet]}" if g.ruling_planet != want[:ruling_planet]
      diff << "birth_month #{g.birth_month&.name}→#{want[:birth_month]&.name}" if g.birth_month_id != want[:birth_month]&.id
      cur_signs = g.zodiac_signs.map(&:slug).sort
      diff << "zodiac #{cur_signs.join(',')}→#{want_signs.map(&:slug).sort.join(',')}" if cur_signs != want_signs.map(&:slug).sort
      cur_powers = g.healing_powers.map(&:slug).sort
      diff << "healing #{cur_powers.join(',')}→#{want_powers.map(&:slug).sort.join(',')}" if cur_powers != want_powers.map(&:slug).sort
      next if diff.empty?

      changed += 1
      puts "#{g.slug}: #{diff.join('; ')}"
      next if dry

      Gemstone.transaction do
        g.update!(mohs_hardness: want[:mohs_hardness], element: want[:element],
                  ruling_planet: want[:ruling_planet], birth_month: want[:birth_month])
        g.zodiac_signs = want_signs
        g.healing_powers = want_powers
      end
    end
    puts "#{dry ? 'Would change' : 'Changed'} #{changed} gemstones (Atlas has #{Atlas.stones.size})"
  end
end
