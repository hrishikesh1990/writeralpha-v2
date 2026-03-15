require "net/http"
require "json"
require "uri"
require "fileutils"

namespace :images do
  desc "Scrape featured images from WordPress REST API and save mapping"
  task scrape: :environment do
    base_url = "https://writeralpha.com/wp-json/wp/v2/posts"
    mapping = {}
    page = 1
    per_page = 50

    puts "Fetching posts from WordPress API..."

    loop do
      url = URI("#{base_url}?per_page=#{per_page}&page=#{page}&_embed")
      response = Net::HTTP.get_response(url)

      break if response.code == "400" # past last page

      posts = JSON.parse(response.body)
      break if posts.empty?

      posts.each do |post|
        slug = post["slug"]
        embedded = post.dig("_embedded", "wp:featuredmedia")
        if embedded && embedded[0]
          image_url = embedded[0].dig("media_details", "sizes", "full", "source_url") ||
                      embedded[0]["source_url"]
          if image_url
            mapping[slug] = image_url
            puts "  #{slug} => #{image_url}"
          end
        end
      end

      total_pages = response["x-wp-totalpages"].to_i
      puts "  Page #{page}/#{total_pages}"
      break if page >= total_pages

      page += 1
      sleep 0.5 # be polite
    end

    output_path = Rails.root.join("db/wordpress_data/image_mapping.json")
    File.write(output_path, JSON.pretty_generate(mapping))
    puts "\nSaved #{mapping.size} image mappings to #{output_path}"
  end

  desc "Download images from WordPress and save locally"
  task download: :environment do
    mapping_path = Rails.root.join("db/wordpress_data/image_mapping.json")
    unless File.exist?(mapping_path)
      puts "Run `rake images:scrape` first to generate image_mapping.json"
      exit 1
    end

    mapping = JSON.parse(File.read(mapping_path))
    dest_dir = Rails.root.join("public/images/posts")
    FileUtils.mkdir_p(dest_dir)

    puts "Downloading #{mapping.size} images..."

    mapping.each_with_index do |(slug, url), i|
      ext = File.extname(URI.parse(url).path).downcase
      ext = ".jpg" if ext.empty?
      dest = dest_dir.join("#{slug}#{ext}")

      if File.exist?(dest)
        puts "  [skip] #{slug}#{ext} (exists)"
        next
      end

      begin
        uri = URI(url)
        response = Net::HTTP.get_response(uri)

        # Follow redirects
        if response.is_a?(Net::HTTPRedirection)
          uri = URI(response["location"])
          response = Net::HTTP.get_response(uri)
        end

        if response.is_a?(Net::HTTPSuccess)
          File.binwrite(dest, response.body)
          puts "  [#{i + 1}/#{mapping.size}] #{slug}#{ext} (#{response.body.size / 1024}KB)"
        else
          puts "  [fail] #{slug} - HTTP #{response.code}"
        end
      rescue => e
        puts "  [error] #{slug} - #{e.message}"
      end

      sleep 0.2
    end

    puts "Done! Images saved to #{dest_dir}"
  end

  desc "Populate featured_image_url on Gemstone and Article records from downloaded images"
  task populate: :environment do
    mapping_path = Rails.root.join("db/wordpress_data/image_mapping.json")
    unless File.exist?(mapping_path)
      puts "Run `rake images:scrape` first"
      exit 1
    end

    mapping = JSON.parse(File.read(mapping_path))
    images_dir = Rails.root.join("public/images/posts")
    updated = 0

    # Map WordPress slugs to Rails gemstone/article records
    # WordPress uses article slugs like "who-should-not-wear-rose-quartz"
    # We need to match these to our gemstone slugs and article slugs

    puts "Populating featured_image_url..."

    # First pass: direct article slug match
    Article.find_each do |article|
      wp_slug = article.slug
      if mapping[wp_slug]
        ext = File.extname(URI.parse(mapping[wp_slug]).path).downcase
        ext = ".jpg" if ext.empty?
        local_path = "/images/posts/#{wp_slug}#{ext}"

        if File.exist?(images_dir.join("#{wp_slug}#{ext}"))
          article.update_column(:featured_image_url, local_path)
          puts "  Article: #{wp_slug} => #{local_path}"
          updated += 1
        end
      end
    end

    # Second pass: try to match gemstones
    # WordPress article slugs often contain the gemstone name
    Gemstone.find_each do |gem|
      next if gem.featured_image_url.present?

      # Look for any WordPress article that contains this gemstone's name
      match_slug = mapping.keys.find { |k| k.include?(gem.slug) }
      if match_slug
        ext = File.extname(URI.parse(mapping[match_slug]).path).downcase
        ext = ".jpg" if ext.empty?
        local_path = "/images/posts/#{match_slug}#{ext}"

        if File.exist?(images_dir.join("#{match_slug}#{ext}"))
          gem.update_column(:featured_image_url, local_path)
          puts "  Gemstone: #{gem.slug} => #{local_path} (from #{match_slug})"
          updated += 1
        end
      end
    end

    puts "\nUpdated #{updated} records with featured images."
  end

  desc "Full pipeline: scrape, download, populate"
  task setup: [:scrape, :download, :populate]
end
