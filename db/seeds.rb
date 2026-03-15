puts "=== Seeding WriteAlpha V2 ==="

# ===== TAXONOMY =====
puts "Seeding taxonomies..."

colors_data = [
  {name:"Pink",hex:"#FF69B4"},{name:"Blue",hex:"#4169E1"},{name:"Red",hex:"#DC143C"},
  {name:"Green",hex:"#228B22"},{name:"Purple",hex:"#8B008B"},{name:"Black",hex:"#1a1a1a"},
  {name:"White",hex:"#F5F5F5"},{name:"Yellow",hex:"#FFD700"},{name:"Orange",hex:"#FF8C00"},
  {name:"Brown",hex:"#8B4513"},{name:"Gray",hex:"#808080"},{name:"Multicolor",hex:nil},
  {name:"Colorless",hex:nil},{name:"Gold",hex:"#DAA520"}
]
colors_data.each { |c| Color.find_or_create_by!(name: c[:name]) { |r| r.slug = c[:name].parameterize; r.hex_code = c[:hex] } }

%w[Opaque Translucent Transparent].each { |n| Transparency.find_or_create_by!(name: n) { |r| r.slug = n.parameterize } }
%w[Round Heart Square Triangle Pear Oval Marquise Cushion Freeform Cabochon].each { |n| Shape.find_or_create_by!(name: n) { |r| r.slug = n.parameterize } }
["Round Brilliant","Asscher","Baguette","Briolette","Cabochon","Cushion","Emerald","Marquise","Octagon","Oval","Pear","Princess","Radiant","Round","Step"].each { |n| Cut.find_or_create_by!(name: n) { |r| r.slug = n.parameterize } }
["Adamantine","Vitreous","Pearly","Silky","Greasy","Resinous","Waxy","Dull","Metallic","Sub-metallic"].each { |n| Lustre.find_or_create_by!(name: n) { |r| r.slug = n.parameterize } }
["Peace & Calm","Concentration","Protection","Love","Wealth","Confidence","Creativity","Grounding","Healing","Sleep","Communication","Intuition","Transformation","Courage","Emotional Balance"].each { |n| HealingPower.find_or_create_by!(name: n) { |r| r.slug = n.parameterize } }
[["January",1],["February",2],["March",3],["April",4],["May",5],["June",6],["July",7],["August",8],["September",9],["October",10],["November",11],["December",12]].each { |n,num| BirthMonth.find_or_create_by!(month_number: num) { |r| r.name = n } }

zodiac = [
  ["Aries","♈","Mar 21 - Apr 19","Fire"],["Taurus","♉","Apr 20 - May 20","Earth"],
  ["Gemini","♊","May 21 - Jun 20","Air"],["Cancer","♋","Jun 21 - Jul 22","Water"],
  ["Leo","♌","Jul 23 - Aug 22","Fire"],["Virgo","♍","Aug 23 - Sep 22","Earth"],
  ["Libra","♎","Sep 23 - Oct 22","Air"],["Scorpio","♏","Oct 23 - Nov 21","Water"],
  ["Sagittarius","♐","Nov 22 - Dec 21","Fire"],["Capricorn","♑","Dec 22 - Jan 19","Earth"],
  ["Aquarius","♒","Jan 20 - Feb 18","Air"],["Pisces","♓","Feb 19 - Mar 20","Water"]
]
zodiac.each { |n,s,d,e| ZodiacSign.find_or_create_by!(name: n) { |r| r.slug = n.parameterize; r.symbol = s; r.date_range = d; r.element = e } }

puts "  Taxonomies: #{Color.count} colors, #{Transparency.count} transparencies, #{Shape.count} shapes, #{Cut.count} cuts, #{Lustre.count} lustres, #{HealingPower.count} healing powers, #{BirthMonth.count} months, #{ZodiacSign.count} zodiac signs"

# ===== GEMSTONES =====
puts "Seeding gemstones..."

o = Transparency.find_by(name: "Opaque"); tl = Transparency.find_by(name: "Translucent"); tp = Transparency.find_by(name: "Transparent")
vi = Lustre.find_by(name: "Vitreous"); ad = Lustre.find_by(name: "Adamantine"); wx = Lustre.find_by(name: "Waxy")
pl = Lustre.find_by(name: "Pearly"); mt = Lustre.find_by(name: "Metallic"); sl = Lustre.find_by(name: "Silky")
gr = Lustre.find_by(name: "Greasy"); dl = Lustre.find_by(name: "Dull"); rs = Lustre.find_by(name: "Resinous")

gems = [
  {n:"Amethyst",s:"The Stone of Spiritual Growth",m:7,t:tp,l:vi,bm:2,c:["Purple"],h:["Peace & Calm","Intuition","Sleep"],el:"Air",pl:"Jupiter",z:["Pisces","Aquarius"],
   d:"Amethyst is a violet variety of quartz prized for centuries as a stone of royalty and spirituality. It promotes peace, balance, and inner strength."},
  {n:"Rose Quartz",s:"The Stone of Unconditional Love",m:7,t:tl,l:vi,bm:nil,c:["Pink"],h:["Love","Emotional Balance","Peace & Calm"],el:"Water",pl:"Venus",z:["Taurus","Libra"],
   d:"Rose quartz is the stone of universal love. It restores trust and harmony in relationships."},
  {n:"Jade",s:"The Stone of Harmony & Prosperity",m:6.5,t:tl,l:wx,bm:nil,c:["Green"],h:["Wealth","Protection","Emotional Balance"],el:"Earth",pl:"Venus",z:["Taurus","Libra"],
   d:"Jade has been treasured for thousands of years. It symbolizes purity, harmony, and prosperity."},
  {n:"Pyrite",s:"Fool's Gold — The Stone of Abundance",m:6.5,t:o,l:mt,bm:nil,c:["Gold"],h:["Wealth","Confidence","Protection"],el:"Fire",pl:"Mars",z:["Leo","Aries"],
   d:"Pyrite, known as fool's gold, is a powerful stone for manifesting abundance and wealth."},
  {n:"Tiger Eye",s:"The Stone of Courage",m:7,t:o,l:sl,bm:nil,c:["Brown","Gold","Yellow"],h:["Courage","Confidence","Grounding"],el:"Fire",pl:"Sun",z:["Leo","Capricorn"],
   d:"Tiger eye displays a striking band of light. Known for promoting courage and self-confidence."},
  {n:"Black Tourmaline",s:"The Ultimate Protection Stone",m:7.5,t:o,l:vi,bm:10,c:["Black"],h:["Protection","Grounding","Peace & Calm"],el:"Earth",pl:"Saturn",z:["Capricorn","Scorpio"],
   d:"Black tourmaline is one of the most powerful protective stones, shielding against negative energy."},
  {n:"Moonstone",s:"The Stone of New Beginnings",m:6.5,t:tl,l:pl,bm:6,c:["White","Multicolor"],h:["Intuition","Emotional Balance","Creativity"],el:"Water",pl:"Moon",z:["Cancer","Libra"],
   d:"Moonstone is known for its adularescence — a soft, glowing light that moves across the surface."},
  {n:"Labradorite",s:"The Stone of Transformation",m:6.5,t:tl,l:vi,bm:nil,c:["Blue","Green","Gray","Multicolor"],h:["Transformation","Intuition","Protection"],el:"Water",pl:"Uranus",z:["Sagittarius","Scorpio"],
   d:"Labradorite is known for its remarkable play of color, called labradorescence."},
  {n:"Lapis Lazuli",s:"The Stone of Wisdom",m:5.5,t:o,l:vi,bm:9,c:["Blue"],h:["Communication","Intuition","Peace & Calm"],el:"Water",pl:"Jupiter",z:["Sagittarius","Pisces"],
   d:"Lapis lazuli has been prized since antiquity for its intense blue color."},
  {n:"Obsidian",s:"The Stone of Inner Reflection",m:5.5,t:o,l:vi,bm:nil,c:["Black"],h:["Protection","Grounding","Transformation"],el:"Fire",pl:"Pluto",z:["Scorpio","Sagittarius"],
   d:"Obsidian is a volcanic glass formed from rapidly cooling lava."},
  {n:"Citrine",s:"The Stone of Joy & Abundance",m:7,t:tp,l:vi,bm:11,c:["Yellow","Orange"],h:["Wealth","Confidence","Creativity"],el:"Fire",pl:"Sun",z:["Aries","Leo","Gemini"],
   d:"Citrine is known as the merchant's stone for attracting wealth and prosperity."},
  {n:"Garnet",s:"The Stone of Passion",m:7,t:tp,l:vi,bm:1,c:["Red"],h:["Courage","Love","Grounding"],el:"Fire",pl:"Mars",z:["Aries","Aquarius"],
   d:"Garnet is a stone of passion, energy, and vitality."},
  {n:"Turquoise",s:"The Stone of Communication",m:6,t:o,l:wx,bm:12,c:["Blue","Green"],h:["Communication","Protection","Healing"],el:"Earth",pl:"Venus",z:["Sagittarius","Pisces"],
   d:"Turquoise is one of the oldest known gemstones, valued for its striking blue-green color."},
  {n:"Aquamarine",s:"The Stone of Serenity",m:8,t:tp,l:vi,bm:3,c:["Blue"],h:["Peace & Calm","Communication","Courage"],el:"Water",pl:"Neptune",z:["Pisces","Aquarius"],
   d:"Aquamarine evokes the crystal clear waters of the sea."},
  {n:"Ruby",s:"The King of Gemstones",m:9,t:tp,l:ad,bm:7,c:["Red"],h:["Courage","Love","Confidence"],el:"Fire",pl:"Sun",z:["Aries","Leo"],
   d:"Ruby is one of the four precious gemstones, symbolizing passion, love, and vitality."},
  {n:"Sapphire",s:"The Stone of Wisdom",m:9,t:tp,l:ad,bm:9,c:["Blue"],h:["Intuition","Concentration","Communication"],el:"Water",pl:"Saturn",z:["Virgo","Libra"],
   d:"Sapphire is a precious gemstone prized for its deep blue color."},
  {n:"Diamond",s:"The Invincible Stone",m:10,t:tp,l:ad,bm:4,c:["Colorless","White"],h:["Courage","Confidence","Love"],el:"Fire",pl:"Sun",z:["Aries","Leo"],
   d:"Diamond is the hardest natural material on Earth, representing invincibility and eternal love."},
  {n:"Emerald",s:"The Stone of Successful Love",m:7.5,t:tp,l:vi,bm:5,c:["Green"],h:["Love","Healing","Intuition"],el:"Earth",pl:"Mercury",z:["Taurus","Gemini"],
   d:"Emerald is the most well-known green gemstone and one of the four precious stones."},
  {n:"Malachite",s:"The Stone of Transformation",m:4,t:o,l:sl,bm:nil,c:["Green"],h:["Transformation","Protection","Emotional Balance"],el:"Earth",pl:"Venus",z:["Capricorn","Scorpio"],
   d:"Malachite is known for its stunning banded green patterns."},
  {n:"Hematite",s:"The Stone of Grounding",m:6,t:o,l:mt,bm:nil,c:["Gray","Black"],h:["Grounding","Protection","Confidence"],el:"Earth",pl:"Mars",z:["Aries","Aquarius"],
   d:"Hematite is an iron oxide mineral known for its metallic gray luster."},
  {n:"Carnelian",s:"The Stone of Motivation",m:7,t:tl,l:vi,bm:nil,c:["Orange","Red"],h:["Creativity","Courage","Confidence"],el:"Fire",pl:"Mars",z:["Virgo","Leo"],
   d:"Carnelian is a vibrant stone that boosts creativity, motivation, and courage."},
  {n:"Selenite",s:"The Stone of Clarity",m:2,t:tl,l:pl,bm:nil,c:["White","Colorless"],h:["Peace & Calm","Intuition","Healing"],el:"Air",pl:"Moon",z:["Cancer","Taurus"],
   d:"Selenite is named after Selene, the Greek goddess of the moon."},
  {n:"Peridot",s:"The Stone of Compassion",m:6.5,t:tp,l:vi,bm:8,c:["Green"],h:["Healing","Emotional Balance","Confidence"],el:"Earth",pl:"Sun",z:["Leo","Virgo"],
   d:"Peridot is one of few gemstones that come in only one color — olive green."},
  {n:"Opal",s:"The Stone of Inspiration",m:6,t:tl,l:vi,bm:10,c:["White","Multicolor"],h:["Creativity","Intuition","Love"],el:"Water",pl:"Venus",z:["Libra","Scorpio"],
   d:"Opal is famous for its play of color — flashes of rainbow light within the stone."},
  {n:"Lava Stone",s:"The Stone of Rebirth",m:3.5,t:o,l:gr,bm:nil,c:["Black","Gray"],h:["Grounding","Courage","Emotional Balance"],el:"Fire",pl:"Mars",z:["Aries","Scorpio"],
   d:"Lava stone is formed from cooled volcanic lava, carrying the energy of fire and earth."},
  {n:"Moldavite",s:"The Stone of Rapid Transformation",m:5.5,t:tl,l:vi,bm:nil,c:["Green"],h:["Transformation","Intuition","Healing"],el:"Fire",pl:"Pluto",z:["Scorpio"],
   d:"Moldavite is a rare tektite formed from a meteorite impact 15 million years ago."},
  {n:"Aventurine",s:"The Stone of Opportunity",m:7,t:tl,l:vi,bm:nil,c:["Green"],h:["Wealth","Confidence","Healing"],el:"Earth",pl:"Venus",z:["Aries","Leo"],
   d:"Green aventurine is known as the luckiest crystal, attracting prosperity."},
  {n:"Clear Quartz",s:"The Master Healer",m:7,t:tp,l:vi,bm:4,c:["Colorless","White"],h:["Healing","Concentration","Intuition"],el:"Air",pl:"Sun",z:["Aries","Leo"],
   d:"Clear quartz is the most versatile healing crystal, amplifying energy and intention."},
  {n:"Fluorite",s:"The Genius Stone",m:4,t:tp,l:vi,bm:nil,c:["Purple","Green","Blue","Multicolor"],h:["Concentration","Intuition","Peace & Calm"],el:"Air",pl:"Mercury",z:["Pisces","Capricorn"],
   d:"Fluorite enhances mental clarity, focus, and decision-making."},
  {n:"Sodalite",s:"The Stone of Logic",m:5.5,t:tl,l:vi,bm:nil,c:["Blue","White"],h:["Communication","Concentration","Intuition"],el:"Air",pl:"Mercury",z:["Sagittarius"],
   d:"Sodalite enhances logic, rationality, and truth."},
  {n:"Amazonite",s:"The Stone of Hope",m:6.5,t:tl,l:vi,bm:nil,c:["Green","Blue"],h:["Communication","Peace & Calm","Courage"],el:"Earth",pl:"Uranus",z:["Virgo"],
   d:"Amazonite promotes truth, integrity, and hope."},
  {n:"Rhodonite",s:"The Stone of Compassion",m:6,t:tl,l:vi,bm:nil,c:["Pink","Black"],h:["Love","Emotional Balance","Healing"],el:"Earth",pl:"Venus",z:["Taurus"],
   d:"Rhodonite is the rescue stone for emotional healing and self-love."},
  {n:"Howlite",s:"The Calming Stone",m:3.5,t:o,l:dl,bm:nil,c:["White","Gray"],h:["Peace & Calm","Sleep","Concentration"],el:"Air",pl:"Moon",z:["Gemini","Virgo"],
   d:"Howlite reduces stress and anxiety with its calming energy."},
  {n:"Kyanite",s:"The Stone of Alignment",m:7,t:tl,l:vi,bm:nil,c:["Blue","Green","Black"],h:["Communication","Intuition","Peace & Calm"],el:"Air",pl:"Mercury",z:["Aries","Taurus","Libra"],
   d:"Kyanite never accumulates negative energy and never needs cleansing."},
  {n:"Smoky Quartz",s:"The Stone of Serenity",m:7,t:tl,l:vi,bm:nil,c:["Brown","Gray"],h:["Grounding","Protection","Peace & Calm"],el:"Earth",pl:"Saturn",z:["Capricorn","Sagittarius"],
   d:"Smoky quartz transmutes negative energy and promotes emotional calm."},
  {n:"Black Onyx",s:"The Stone of Inner Strength",m:7,t:o,l:vi,bm:nil,c:["Black"],h:["Protection","Grounding","Confidence"],el:"Earth",pl:"Saturn",z:["Capricorn","Leo"],
   d:"Black onyx promotes vigor, steadfastness, and inner strength."},
]

gems.each do |data|
  g = Gemstone.find_or_create_by!(name: data[:n]) do |gem|
    gem.slug = data[:n].parameterize
    gem.subtitle = data[:s]
    gem.description = data[:d]
    gem.mohs_hardness = data[:m]
    gem.transparency = data[:t]
    gem.lustre = data[:l]
    gem.birth_month = data[:bm] ? BirthMonth.find_by(month_number: data[:bm]) : nil
    gem.element = data[:el]
    gem.ruling_planet = data[:pl]
    gem.published = true
  end
  data[:c]&.each { |cn| c = Color.find_by(name: cn); GemstoneColor.find_or_create_by!(gemstone: g, color: c) if c }
  data[:h]&.each { |hn| h = HealingPower.find_by(name: hn); GemstoneHealingPower.find_or_create_by!(gemstone: g, healing_power: h) if h }
  data[:z]&.each { |zn| z = ZodiacSign.find_by(name: zn); GemstoneZodiacSign.find_or_create_by!(gemstone: g, zodiac_sign: z) if z }
end

puts "  #{Gemstone.count} gemstones seeded"

# ===== CATEGORIES =====
puts "Seeding categories..."
cats = {
  "business-names" => "Business Names",
  "instagram-names" => "Instagram Names",
  "team-names" => "Team Names",
  "group-names" => "Group Names",
  "slogans" => "Slogans & Taglines",
  "guides" => "Guides",
  "how-to-start" => "How to Start",
  "learn" => "Learn",
  "angel-numbers" => "Angel Numbers",
  "crystals-for" => "Crystals For",
  "comparisons" => "Comparisons",
  "crystal-pairs" => "Crystal Pairs",
}
cats.each { |slug, name| Category.find_or_create_by!(slug: slug) { |c| c.name = name } }
puts "  #{Category.count} categories"

# ===== ARTICLES =====
# Articles are seeded from WordPress content in db/seeds/04_wordpress_content.rb
# No dummy articles here — all content comes from the live WordPress site
puts "\n--- Loading additional seed files ---"
Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |f| load f }

puts "\n=== Seeding complete! ==="
puts "  Gemstones: #{Gemstone.count}"
puts "  Articles: #{Article.count}"
puts "  Categories: #{Category.count}"
