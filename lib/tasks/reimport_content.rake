require "net/http"
require "json"
require "uri"

namespace :content do
  desc "Re-import article content as HTML from WordPress REST API"
  task reimport: :environment do
    base_url = "https://writeralpha.com/wp-json/wp/v2/posts"
    page = 1
    per_page = 50
    updated = 0
    skipped = 0

    # Allowed HTML tags to keep (strip WordPress plugin markup, scripts, etc.)
    allowed_tags = %w[h2 h3 h4 p ul ol li strong em a img figure figcaption br span blockquote]
    allowed_attrs = %w[href src alt loading class id width height]

    puts "Fetching content from WordPress API..."

    loop do
      url = URI("#{base_url}?per_page=#{per_page}&page=#{page}&_fields=slug,content")
      response = Net::HTTP.get_response(url)

      break if response.code == "400"

      posts = JSON.parse(response.body)
      break if posts.empty?

      posts.each do |post|
        wp_slug = post["slug"]
        html_content = post.dig("content", "rendered")
        next unless html_content

        # Clean WordPress-specific markup
        clean = html_content
          # Remove TOC plugin container (everything from ez-toc opening div to its closing </nav></div>)
          .gsub(/<div[^>]*ez-toc[^>]*>.*?<\/nav>\s*<\/div>/m, "")
          # Remove any remaining ez-toc elements
          .gsub(/<[^>]*ez-toc[^>]*>.*?<\/[^>]+>/m, "")
          # Remove script/style tags
          .gsub(/<script[^>]*>.*?<\/script>/m, "")
          .gsub(/<style[^>]*>.*?<\/style>/m, "")
          # Remove data attributes
          .gsub(/\s+data-\w+="[^"]*"/, "")
          # Remove inline styles
          .gsub(/\s+style="[^"]*"/, "")
          # Remove class attributes
          .gsub(/\s+class="[^"]*"/, "")
          # Remove id attributes from non-headings
          .gsub(/(<(?!h[2-4])[^>]*)\s+id="[^"]*"/, '\1')
          # Remove empty spans
          .gsub(/<span>\s*<\/span>/, "")
          # Remove empty paragraphs
          .gsub(/<p>\s*<\/p>/, "")
          # Remove empty divs
          .gsub(/<div>\s*<\/div>/, "")
          # Remove decoding attribute
          .gsub(/\s+decoding="[^"]*"/, "")
          # Remove WordPress caption shortcodes
          .gsub(/\[caption[^\]]*\](.*?)\[\/caption\]/m, '\1')
          # Rewrite any remaining writeralpha.com anchor links to local anchors
          .gsub(/href="https?:\/\/writeralpha\.com\/[^"]*#([^"]*)"/, 'href="#\1"')
          # Remove links to writeralpha.com pages (not anchors)
          .gsub(/<a[^>]*href="https?:\/\/writeralpha\.com\/[^"]*"[^>]*>(.*?)<\/a>/m, '\1')
          # Clean up whitespace
          .gsub(/\n{3,}/, "\n\n")
          .strip

        # Try matching to an Article first
        article = Article.find_by(slug: wp_slug)
        if article
          article.update_column(:content, clean)
          puts "  Article: #{wp_slug}"
          updated += 1
          next
        end

        # Try matching to Gemstone content fields via slug patterns
        # WordPress slugs like "amethyst-meaning" -> gemstone "amethyst", field "meaning_content"
        # "can-amethyst-go-in-water" -> gemstone "amethyst", field "water_safety_content"
        # "who-should-not-wear-amethyst-stone" -> gemstone "amethyst", field "who_should_not_wear_content"
        # "sleeping-with-amethyst-under-pillow" -> gemstone "amethyst", field "sleeping_with_content"

        gem_match = match_gemstone_content(wp_slug)
        if gem_match
          gemstone = Gemstone.find_by(slug: gem_match[:gemstone_slug])
          if gemstone
            gemstone.update_column(gem_match[:field], clean)
            puts "  Gemstone #{gem_match[:gemstone_slug]}.#{gem_match[:field]}: #{wp_slug}"
            updated += 1
            next
          end
        end

        skipped += 1
      end

      total_pages = response["x-wp-totalpages"].to_i
      puts "  Page #{page}/#{total_pages}"
      break if page >= total_pages

      page += 1
      sleep 0.5
    end

    puts "\nDone! Updated: #{updated}, Skipped: #{skipped}"
  end
end

def match_gemstone_content(wp_slug)
  gemstone_slugs = Gemstone.pluck(:slug)

  # Pattern: <gemstone>-meaning -> meaning_content
  gemstone_slugs.each do |gs|
    if wp_slug == "#{gs}-meaning" || wp_slug == "#{gs}-crystal-meaning" || wp_slug == "jade-crystal-meaning" && gs == "jade"
      return { gemstone_slug: gs, field: :meaning_content }
    end
  end

  # Pattern: can-<gemstone>-go-in-water -> water_safety_content
  gemstone_slugs.each do |gs|
    if wp_slug == "can-#{gs}-go-in-water"
      return { gemstone_slug: gs, field: :water_safety_content }
    end
  end

  # Pattern: who-should-not-wear-<gemstone>[-stone] -> who_should_not_wear_content
  gemstone_slugs.each do |gs|
    if wp_slug == "who-should-not-wear-#{gs}" || wp_slug == "who-should-not-wear-#{gs}-stone"
      return { gemstone_slug: gs, field: :who_should_not_wear_content }
    end
  end

  # Pattern: sleeping-with-<gemstone>-under-pillow -> sleeping_with_content
  gemstone_slugs.each do |gs|
    if wp_slug == "sleeping-with-#{gs}-under-pillow"
      return { gemstone_slug: gs, field: :sleeping_with_content }
    end
  end

  # Pattern: <gemstone>-meaning-properties-benefits[-and]-uses -> meaning_content (alternate)
  gemstone_slugs.each do |gs|
    short = gs.split("-").first # "tiger-eye" -> "tiger", "green-aventurine" -> "green"
    if wp_slug.start_with?("#{gs}-meaning") || wp_slug.start_with?("#{short}s-eye-meaning") || wp_slug.start_with?("#{short}-eye-meaning")
      return { gemstone_slug: gs, field: :meaning_content }
    end
  end

  nil
end
