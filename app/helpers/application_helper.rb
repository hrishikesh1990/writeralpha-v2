module ApplicationHelper
  ALLOWED_TAGS = %w[h2 h3 h4 p ul ol li br strong em a nav div span img figure figcaption blockquote].freeze
  ALLOWED_ATTRS = %w[href class id src alt loading width height].freeze

  def render_content(text)
    return "".html_safe if text.blank?

    if text.match?(/<(h[2-4]|p|ul|ol|li)\b/)
      sanitize(text, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRS)
    else
      simple_format(text)
    end
  end
end
