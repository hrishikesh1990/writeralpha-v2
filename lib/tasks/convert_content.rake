namespace :content do
  desc "Convert markdown-style content to HTML for gemstones and articles"
  task convert: :environment do
    def markdown_to_html(text)
      return "" if text.blank?
      # Already HTML? Skip.
      return text if text.match?(/<(h[2-4]|p|ul|ol)\b/)

      lines = text.split("\n")
      html_parts = []
      list_type = nil # :ul or :ol
      paragraph_lines = []

      flush_paragraph = -> {
        unless paragraph_lines.empty?
          text_block = paragraph_lines.join("<br>").strip
          html_parts << "<p>#{text_block}</p>" unless text_block.empty?
          paragraph_lines.clear
        end
      }

      close_list = -> {
        if list_type
          html_parts << (list_type == :ol ? "</ol>" : "</ul>")
          list_type = nil
        end
      }

      lines.each do |line|
        stripped = line.strip

        # Skip "Table of Contents" and "Toggle" lines
        if stripped == "Table of Contents" || stripped == "Toggle"
          flush_paragraph.call
          close_list.call
          next
        end

        # Headings
        if stripped.match?(/\A####\s/)
          flush_paragraph.call
          close_list.call
          html_parts << "<h4>#{stripped.sub(/\A####\s*/, '')}</h4>"
        elsif stripped.match?(/\A###\s/)
          flush_paragraph.call
          close_list.call
          html_parts << "<h3>#{stripped.sub(/\A###\s*/, '')}</h3>"
        elsif stripped.match?(/\A##\s/)
          flush_paragraph.call
          close_list.call
          html_parts << "<h2>#{stripped.sub(/\A##\s*/, '')}</h2>"
        # Bullet points (• or - or *)
        elsif stripped.match?(/\A[•\-\*]\s/)
          flush_paragraph.call
          if list_type != :ul
            close_list.call
            html_parts << "<ul>"
            list_type = :ul
          end
          html_parts << "<li>#{stripped.sub(/\A[•\-\*]\s*/, '')}</li>"
        # Numbered lists
        elsif stripped.match?(/\A\d+[\.\)]\s/)
          flush_paragraph.call
          if list_type != :ol
            close_list.call
            html_parts << "<ol>"
            list_type = :ol
          end
          html_parts << "<li>#{stripped.sub(/\A\d+[\.\)]\s*/, '')}</li>"
        # Empty line = paragraph break
        elsif stripped.empty?
          flush_paragraph.call
          close_list.call
        # Regular text
        else
          # Close list if we hit regular text after a list
          if list_type
            close_list.call
          end
          paragraph_lines << stripped
        end
      end

      flush_paragraph.call
      close_list.call

      html_parts.join("\n")
    end

    gemstone_fields = %w[
      description meaning_content water_safety_content sleeping_with_content
      who_should_not_wear_content benefits_content properties_content
      chakra_content combinations_content how_to_cleanse_content
      how_to_identify_content uses_content affirmations_content
      price_guide_content zodiac_content
    ]

    puts "Converting gemstone content..."
    Gemstone.find_each do |gem|
      changed = false
      gemstone_fields.each do |field|
        val = gem.send(field)
        next if val.blank?
        next if val.match?(/<(h[2-4]|p|ul|ol)\b/) # already HTML

        gem.send("#{field}=", markdown_to_html(val))
        changed = true
      end
      if changed
        gem.save!(validate: false)
        puts "  Converted: #{gem.slug}"
      end
    end

    puts "Converting article content..."
    Article.find_each do |article|
      next if article.content.blank?
      next if article.content.match?(/<(h[2-4]|p|ul|ol)\b/)

      article.content = markdown_to_html(article.content)
      article.save!(validate: false)
      puts "  Converted: #{article.slug}"
    end

    puts "Done! Content converted to HTML."
  end
end
