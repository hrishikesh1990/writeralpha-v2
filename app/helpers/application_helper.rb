module ApplicationHelper
  ALLOWED_TAGS = %w[h2 h3 h4 p ul ol li br strong em a nav div span img figure figcaption blockquote].freeze
  ALLOWED_ATTRS = %w[href class id src alt loading width height].freeze
  LOCAL_IMAGE_PREFIX = "/images/"

  # Self-hosted images live under public/images in development. In production
  # they are served from object storage; IMAGE_BASE_URL (no trailing slash)
  # replaces the "/images" prefix, e.g. "/images/posts/x.jpg" =>
  # "https://bucket.example/posts/x.jpg".
  def image_url_for(path)
    return path if path.blank?
    base = ENV["IMAGE_BASE_URL"].presence
    return path unless base && path.start_with?(LOCAL_IMAGE_PREFIX)

    "#{base.chomp('/')}/#{path.delete_prefix(LOCAL_IMAGE_PREFIX)}"
  end

  def render_content(text)
    return "".html_safe if text.blank?

    if text.match?(/<(h[2-4]|p|ul|ol|li)\b/)
      sanitize(rewrite_image_urls(text), tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRS)
    else
      simple_format(text)
    end
  end

  # Gives every <h2> an id (for the "On this page" sidebar) and returns
  # [html, [{ id:, title: }, …]].
  def content_with_headings(html)
    return [html, []] if html.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    headings = fragment.css("h2").each_with_index.map do |node, i|
      node["id"] = node.text.parameterize.presence || "section-#{i + 1}" if node["id"].blank?
      { id: node["id"], title: node.text.squish }
    end
    [fragment.to_html, headings]
  end

  def reading_time(html)
    words = strip_tags(html.to_s).split.size
    [(words / 200.0).ceil, 1].max
  end

  # Plain-text version of a WordPress excerpt (strips tags and the "… Read more" tail).
  def plain_excerpt(html, length: 240)
    text = strip_tags(html.to_s).squish
    cut = text.sub!(/\s*…?\s*Read more\s*\z/i, "")
    text = "#{text.chomp('…')}…" if cut
    truncate(text, length: length, separator: " ", omission: "…")
  end

  # Wraps "&" in a light-weight span, as in the sub-page title design.
  def light_ampersand(title)
    safe_join(title.to_s.split(/(&)/).map { |part| part == "&" ? tag.span("&", class: "font-light") : part })
  end

  # Forces text (not emoji) presentation for symbols like ♒ so they take the
  # CSS color instead of rendering as a color emoji.
  def text_glyph(symbol)
    "#{symbol}\uFE0E"
  end

  # ---- Nav -----------------------------------------------------------------

  def nav_active?(section)
    case section
    when :gemstones     then controller_name == "gemstones"
    when :crystals      then controller_name == "crystals"
    when :angel_numbers then controller_name == "angel_numbers"
    when :learn         then controller_name == "learn" || (controller_name == "blog" && params[:category] == "learn")
    when :blog          then controller_name == "blog" && params[:category] != "learn"
    else false
    end
  end

  def nav_link_class(active)
    base = "shrink-0 whitespace-nowrap rounded-full px-[15px] py-2 card-transition"
    active ? "#{base} bg-violet/9 font-medium text-violet-deep hover:text-violet-deep" : "#{base} text-ui hover:bg-violet/6 hover:text-violet-deep"
  end

  private

  def rewrite_image_urls(html)
    return html unless ENV["IMAGE_BASE_URL"].present?

    html.gsub(/(src=["'])(\/images\/[^"']+)/) { "#{$1}#{image_url_for($2)}" }
  end
end
