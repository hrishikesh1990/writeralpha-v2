class LegacyController < ApplicationController
  # Old /business/* pages: the naming niche was retired (Aug 2026).
  # The handful of URLs with real external backlinks 301 to the homepage;
  # everything else returns 410 Gone for fast, deliberate deindexing.
  BACKLINKED_BUSINESS_SLUGS = %w[
    girly-business-names
    boutique-names
    cleaning-business-names
    esthetician-business-names
    instagram-usernames-for-boys
    lawn-care-business-names
  ].freeze

  # Legacy WordPress image paths (several have external backlinks, e.g.
  # indian-agate1.jpeg with 32 referring domains). Once IMAGE_CDN_BASE is set
  # (e.g. https://fly.storage.tigris.dev/writeralpha-images), we 301 the old
  # path to the same path on the CDN, preserving image link equity.
  def image
    base = ENV["IMAGE_CDN_BASE"].presence
    if base
      redirect_to "#{base.chomp('/')}/wp-content/uploads/#{params[:image_path]}", status: :moved_permanently, allow_other_host: true
    else
      head :not_found
    end
  end

  def gone
    render plain: "410 Gone — this section has been retired.", status: :gone
  end

  def business
    slug = params[:rest].to_s.split("/").first
    if slug.present? && BACKLINKED_BUSINESS_SLUGS.include?(slug)
      redirect_to root_path, status: :moved_permanently
    else
      gone
    end
  end

  # Catch-all resolver: check the redirects table (seeded from the URL
  # migration map), otherwise 404.
  def resolve
    path = "/" + (params[:old_path].presence || params[:unmatched].to_s)
    path = "/gemstone/#{params[:old_path]}" if params[:old_path].present?

    redirect_entry = Redirect.find_by(old_path: path) || Redirect.find_by(old_path: path.chomp("/"))

    if redirect_entry
      redirect_to redirect_entry.new_path, status: redirect_entry.status_code || 301, allow_other_host: false
    else
      raise ActionController::RoutingError, "No route matches #{path}"
    end
  rescue ActionController::RoutingError
    render plain: "404 Not Found", status: :not_found
  end
end
