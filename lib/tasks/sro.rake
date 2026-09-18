# SRO content pipeline (docs/sro/PUBLISHING-PLAN.md).
#
#   bin/rails sro:waves                 # regenerate docs/sro/waves.yml from drafts-index.csv
#   bin/rails "sro:import[wave:1]"      # import a wave (DRY_RUN=1 to preview)
#   bin/rails "sro:import[url:/learn/crystal-grids]"
#   bin/rails "sro:import[stone:pyrite]" / "sro:import[section:compare]" / "sro:import[all]"
#   bin/rails "sro:audit[wave:1]"       # every URL 200, every internal link resolves, tables kept
#
# Markdown in docs/sro/drafts/ is the source of truth; re-running an import
# rewrites content from the file and is safe.
require "csv"
require "yaml"
require "set"

namespace :sro do
  SRO_DIR = Rails.root.join("docs/sro")
  DRAFTS_DIR = SRO_DIR.join("drafts")
  INDEX_CSV = SRO_DIR.join("drafts-index.csv")
  WAVES_YML = SRO_DIR.join("waves.yml")
  BACKLOG_CSV = Rails.root.join("docs/content_backlog.csv")

  CATEGORY_BY_SECTION = {
    "learn" => "learn", "compare" => "comparisons", "angel-numbers" => "angel-numbers",
    "crystals-for" => "crystals-for", "crystals-pair" => "crystal-pairs"
  }.freeze

  # New slug => legacy slug it replaces (row is renamed so published_at and
  # the redirect in 05_redirects.rb both keep working).
  RENAMES = {
    "crystals-for-grief" => "11-best-crystals-for-grief",
    "crystals-for-connection" => "best-crystals-for-connection-with-others",
    "crystals-for-sleep" => "best-crystals-for-sleep-enhance-sleep-quality-naturally"
  }.freeze

  # Draft URL => legacy article slugs it absorbs (unpublished on import; the
  # redirect rows in 05_redirects.rb then take over).
  ABSORBS = {
    "/crystals/crystals-for-sleep" => %w[crystals-to-sleep-with-under-your-pillow],
    # aura-quartz-healing-properties merges into the already-live
    # /gemstones/angel-aura-quartz/meaning; retired with the wave-3 merges.
    "/gemstones/black-tourmaline/how-to-identify" => %w[how-to-tell-if-black-tourmaline-is-real aura-quartz-healing-properties]
  }.freeze

  # ---- helpers -----------------------------------------------------------

  def sro_index
    @sro_index ||= CSV.read(INDEX_CSV, headers: true).map(&:to_h)
  end

  def sro_draft_path(url)
    DRAFTS_DIR.join(url.delete_prefix("/").gsub("/", "__") + ".md")
  end

  # Front matter is not strict YAML (titles contain ": "), so parse it by line.
  def sro_parse(text)
    m = text.match(/\A---\n(.*?)\n---\n(.*)\z/m) or raise "no front matter"
    fm = {}
    last = nil
    m[1].each_line(chomp: true) do |line|
      if line =~ /\A(\w+):\s*(.*)\z/
        last = Regexp.last_match(1)
        fm[last] = Regexp.last_match(2).strip
        fm[last] = [] if fm[last].empty?
      elsif line =~ /\A\s+-\s+(.*)\z/ && last
        fm[last] = [] unless fm[last].is_a?(Array)
        fm[last] << Regexp.last_match(1).strip
      end
    end
    [fm, m[2]]
  end

  def sro_body_to_html(body)
    body = body.sub(/\A\s*# .*\n/, "") # templates render their own H1
    Kramdown::Document.new(body, auto_ids: false, hard_wrap: false, smart_quotes: %w[apos apos quot quot]).to_html.strip
  end

  # URLs that resolve right now (plus the ones in the current import run).
  # Links to anything else are rendered as plain text so no published page
  # links to a 404; `sro:import[published]` after a later wave restores them.
  FILTER_PATH = %r{\A/gemstones/(color|transparency|shape|cut|lustre|healing|birth-month|starting-with|zodiac|element|planet)/[^/]+\z}
  STATIC_PATHS = %w[/ /gemstones /angel-numbers /blog /about /contact /write-for-us].freeze

  def sro_live_urls(extra = [])
    live = Set.new(STATIC_PATHS + extra)
    Gemstone.published.find_each do |g|
      live << "/gemstones/#{g.slug}"
      g.available_sub_pages.each { |sp| live << "/gemstones/#{g.slug}/#{sp[:path]}" }
    end
    Article.published.includes(:category).find_each { |a| live << a.canonical_path }
    live
  end

  def sro_defer_links(html, live)
    frag = Nokogiri::HTML::DocumentFragment.parse(html)
    deferred = []
    frag.css("a[href^='/']").each do |a|
      target = a["href"].split("#").first
      next if live.include?(target) || target.match?(FILTER_PATH)
      deferred << target
      a.replace(a.inner_html)
    end
    [frag.to_html, deferred]
  end

  def sro_excerpt(body)
    para = body.sub(/\A\s*# .*\n/, "").split(/\n\s*\n/).map(&:strip).find { |p| p.present? && !p.start_with?("#") }.to_s
    para.gsub(/\[([^\]]+)\]\([^)]+\)/, '\1').gsub(/\*\*|__|\*/, "").squish
  end

  def sro_select(selector)
    kind, arg = selector.to_s.split(":", 2)
    rows = sro_index
    case kind
    when "all" then rows
    when "wave"
      urls = YAML.load_file(WAVES_YML).fetch(arg) { raise "unknown wave #{arg}" }
      rows.select { |r| urls.include?(r["url"]) }
    when "url" then rows.select { |r| r["url"] == arg }
    when "published"
      live = sro_live_urls
      rows.select { |r| live.include?(r["url"]) }
    when "stone" then rows.select { |r| r["stone"] == arg }
    when "section" then rows.select { |r| r["section"] == arg }
    else raise "selector must be all | published | wave:N | url:/path | stone:slug | section:name"
    end
  end

  def sro_category_for(url)
    key = if url.start_with?("/crystals/crystals-for-") then "crystals-for"
          elsif url.start_with?("/crystals/") then "crystals-pair"
          else url.split("/")[1]
          end
    Category.find_by!(slug: CATEGORY_BY_SECTION.fetch(key))
  end

  def sro_article_slug(url)
    section, tail = url.split("/")[1, 2]
    section == "angel-numbers" ? "#{Article::ANGEL_PREFIX}#{tail}" : tail
  end

  # ---- tasks -------------------------------------------------------------

  desc "Regenerate docs/sro/waves.yml from drafts-index.csv and content_backlog.csv"
  task waves: :environment do
    demand = CSV.read(BACKLOG_CSV, headers: true).each_with_object({}) { |r, h| h[r["stone"]] = r["stone_demand_impr_16mo"].to_i }
    rank = { "P1" => 3, "P2" => 2, "P3" => 1 }
    stones = sro_index.select { |r| r["section"] == "gemstones" }.group_by { |r| r["stone"] }
    best = stones.transform_values { |rs| rs.map { |r| r["priority"] }.max_by { |p| rank[p] } }
    by_demand = ->(list) { list.sort_by { |s| -demand.fetch(s, 0) } }
    p1 = by_demand.call(best.select { |_, p| p == "P1" }.keys)
    p2 = by_demand.call(best.select { |_, p| p == "P2" }.keys)
    p3 = best.select { |_, p| p == "P3" }.keys
    urls_for = ->(list) { list.flat_map { |s| stones[s].map { |r| r["url"] } } }
    waves = {
      "1" => sro_index.select { |r| %w[learn compare].include?(r["section"]) }.map { |r| r["url"] }.sort,
      "2" => sro_index.select { |r| r["url"].start_with?("/crystals/crystals-for-") }.map { |r| r["url"] }.sort,
      "3a" => urls_for.call(p1),
      "3b" => urls_for.call(p2),
      "4" => sro_index.select { |r| r["section"] == "crystals" && !r["url"].start_with?("/crystals/crystals-for-") }.map { |r| r["url"] }.sort,
      "5a" => urls_for.call(by_demand.call(p3.select { |s| demand.fetch(s, 0) > 100 })),
      "5b" => urls_for.call(by_demand.call(p3.select { |s| demand.fetch(s, 0).between?(1, 100) })),
      "5c" => urls_for.call(p3.select { |s| demand.fetch(s, 0).zero? }.sort),
      "6" => sro_index.select { |r| r["section"] == "angel-numbers" }.map { |r| r["url"] }.sort
    }
    total = waves.values.sum(&:size)
    raise "waves cover #{total} URLs, index has #{sro_index.size}" unless total == sro_index.size
    File.write(WAVES_YML, "# Generated by `bin/rails sro:waves` from drafts-index.csv + content_backlog.csv. Do not edit by hand.\n" + waves.to_yaml)
    waves.each { |k, v| puts "wave #{k}: #{v.size} pages" }
  end

  desc "Import drafts into the database. Selector: all | wave:N | url:/path | stone:slug | section:name. DRY_RUN=1 previews."
  task :import, [:selector] => :environment do |_, args|
    dry = ENV["DRY_RUN"].present?
    rows = sro_select(args[:selector] || "wave:1")
    raise "nothing selected" if rows.empty?
    counts = Hash.new(0)
    live = sro_live_urls(rows.map { |r| r["url"] })
    deferred_total = Hash.new(0)

    rows.each do |row|
      url = row["url"]
      fm, body = sro_parse(File.read(sro_draft_path(url)))
      raise "#{url}: front matter url mismatch (#{fm['url']})" unless fm["url"] == url
      html, deferred = sro_defer_links(sro_body_to_html(body), live)
      deferred.each { |t| deferred_total[t] += 1 }
      raise "#{url}: converted body is empty" if html.blank?

      if row["section"] == "gemstones"
        _, stone, page = url.split("/")[1, 3]
        gem = Gemstone.find_by(slug: stone) or raise "#{url}: gemstone #{stone} not in database"
        field = Gemstone::SUB_PAGE_FIELDS.fetch(page)
        meta = (gem.sub_page_meta || {}).merge(page => { "title" => fm["title"], "meta_title" => fm["meta_title"], "meta_description" => fm["meta_description"] })
        action = gem[field].present? ? (gem[field] == html && gem.sub_page_meta == meta ? "unchanged" : "update") : "create"
        unless dry || action == "unchanged"
          gem[field] = html
          gem.sub_page_meta = meta
          gem.save!
        end
      else
        slug = sro_article_slug(url)
        article = Article.find_by(slug: slug)
        if article.nil? && (legacy = RENAMES[slug]) && (article = Article.find_by(slug: legacy))
          puts "  rename #{legacy} -> #{slug}"
          article.slug = slug unless dry
        end
        article ||= Article.new(slug: slug, category: sro_category_for(url))
        action = article.new_record? ? "create" : (article.content == html && article.title == fm["title"] ? "unchanged" : "update")
        unless dry || action == "unchanged"
          article.assign_attributes(
            title: fm["title"], meta_title: fm["meta_title"], meta_description: fm["meta_description"],
            excerpt: sro_excerpt(body), content: html, published: true, published_at: article.published_at || Time.current,
            category: sro_category_for(url)
          )
          article.save!
        end
      end

      ABSORBS.fetch(url, []).each do |legacy|
        next unless (old = Article.find_by(slug: legacy, published: true))
        puts "  unpublish #{legacy} (absorbed by #{url})"
        old.update!(published: false) unless dry
      end

      counts[action] += 1
      puts "#{dry ? '[dry] ' : ''}#{action.ljust(9)} #{url}"
    end
    puts "#{dry ? 'Would import' : 'Imported'} #{rows.size} pages: #{counts.map { |k, v| "#{v} #{k}" }.join(', ')}"
    if deferred_total.any?
      puts "#{deferred_total.values.sum} links to #{deferred_total.size} not-yet-live pages rendered as text (re-run sro:import[published] after those pages ship):"
      deferred_total.sort_by { |_, n| -n }.first(12).each { |t, n| puts "  #{n.to_s.rjust(3)}  #{t}" }
    end
  end

  desc "Audit published pages: 200 status, internal links resolve, tables survive, sitemap lists them. Selector as for import."
  task :audit, [:selector] => :environment do |_, args|
    require "action_dispatch/testing/integration"
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host! ENV["CANONICAL_HOST"].presence || "localhost"
    ua = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" }
    get = ->(path) { session.get(path, headers: ua); session.response }

    rows = sro_select(args[:selector] || "wave:1")
    sitemap = get.call("/sitemap.xml").body
    link_cache = {}
    failures = []
    checked_links = 0

    rows.each do |row|
      url = row["url"]
      res = get.call(url)
      failures << "#{url}: status #{res.status}" and next unless res.status == 200
      body = res.body
      md = File.read(sro_draft_path(url))
      failures << "#{url}: table lost in render" if md.match?(/^\|.*\|\s*$/) && !body.include?("<table")
      failures << "#{url}: front matter leaked" if body.include?("intent_id:") || body.include?("evidence_basis:")
      failures << "#{url}: missing from sitemap" unless sitemap.match?(%r{#{Regexp.escape(url)}</loc>})
      doc = Nokogiri::HTML(body)
      doc.css("article a[href]").map { |a| a["href"] }.select { |h| h.start_with?("/") }.map { |h| h.split("#").first }.uniq.each do |href|
        status = link_cache[href] ||= get.call(href).status
        checked_links += 1
        failures << "#{url}: link #{href} -> #{status}" unless [200, 301, 302].include?(status)
      end
    end

    RENAMES.each_value do |legacy|
      next unless rows.any? { |r| r["url"].end_with?("/#{RENAMES.key(legacy)}") }
      status = get.call("/crystals/#{legacy}").status
      failures << "/crystals/#{legacy}: expected 301, got #{status}" unless status == 301
    end

    puts "Audited #{rows.size} pages, #{checked_links} link checks (#{link_cache.size} unique targets)."
    if failures.empty?
      puts "PASS"
    else
      puts "FAIL"
      failures.each { |f| puts "  #{f}" }
      exit 1
    end
  end
end
