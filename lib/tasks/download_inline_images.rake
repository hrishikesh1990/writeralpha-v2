require "net/http"
require "uri"
require "fileutils"
require "digest"

namespace :images do
  desc "Download inline images from content and rewrite URLs to local paths"
  task inline: :environment do
    dest_dir = Rails.root.join("public/images/inline")
    FileUtils.mkdir_p(dest_dir)

    wp_pattern = /https?:\/\/writeralpha\.com\/wp-content\/uploads\/[^\s"')>]+/
    downloaded = {}
    total_rewritten = 0

    download_image = ->(url) {
      return downloaded[url] if downloaded[url]

      uri = URI(url)
      # Create a short filename from hash + original extension
      ext = File.extname(uri.path).downcase
      ext = ".jpg" if ext.empty?
      hash = Digest::MD5.hexdigest(url)[0..11]
      basename = File.basename(uri.path, ext).gsub(/[^a-zA-Z0-9_-]/, "")[0..40]
      filename = "#{basename}-#{hash}#{ext}"
      local_path = "/images/inline/#{filename}"
      full_path = dest_dir.join(filename)

      if File.exist?(full_path)
        downloaded[url] = local_path
        return local_path
      end

      begin
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPRedirection)
          response = Net::HTTP.get_response(URI(response["location"]))
        end

        if response.is_a?(Net::HTTPSuccess)
          File.binwrite(full_path, response.body)
          downloaded[url] = local_path
          return local_path
        else
          puts "    [fail] HTTP #{response.code}: #{url}"
          return nil
        end
      rescue => e
        puts "    [error] #{e.message}: #{url}"
        return nil
      end
    }

    puts "Processing articles..."
    Article.find_each do |article|
      next if article.content.blank?
      urls = article.content.scan(wp_pattern).uniq
      next if urls.empty?

      changed = false
      content = article.content
      urls.each do |url|
        local = download_image.call(url)
        if local
          content = content.gsub(url, local)
          changed = true
        end
        sleep 0.1
      end

      if changed
        article.update_column(:content, content)
        total_rewritten += urls.size
        puts "  Article: #{article.slug} (#{urls.size} images)"
      end
    end

    gemstone_fields = %w[
      description meaning_content water_safety_content sleeping_with_content
      who_should_not_wear_content benefits_content properties_content
      chakra_content combinations_content how_to_cleanse_content
      how_to_identify_content uses_content affirmations_content
      price_guide_content zodiac_content
    ]

    puts "\nProcessing gemstones..."
    Gemstone.find_each do |gem|
      gem_changed = false
      gemstone_fields.each do |field|
        val = gem.send(field)
        next if val.blank?
        urls = val.scan(wp_pattern).uniq
        next if urls.empty?

        content = val
        urls.each do |url|
          local = download_image.call(url)
          if local
            content = content.gsub(url, local)
            gem_changed = true
          end
          sleep 0.1
        end
        gem.send("#{field}=", content) if gem_changed
      end

      if gem_changed
        gem.save!(validate: false)
        puts "  Gemstone: #{gem.slug}"
        total_rewritten += 1
      end
    end

    puts "\nDone! Downloaded #{downloaded.size} unique images, rewrote #{total_rewritten} content records."
  end
end
