class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Styled 404 inside the site layout. Used for URLs that never had content
  # (placeholder sub-pages, unknown stones/articles) — a 404, not a 410,
  # because nothing was removed.
  def render_not_found
    @meta = { title: "Page not found — WriterAlpha", description: "That page doesn't exist." }
    render "errors/not_found", status: :not_found
  end

  # Articles have one canonical URL (Article#canonical_path). Any other route
  # that resolves the same slug 301s there, so no duplicate URLs get indexed.
  def render_article_or_redirect(article)
    unless article
      # Consolidated or renamed legacy articles live in the redirects table
      # (db/seeds/05_redirects.rb); the section routes match before the
      # catch-all resolver, so consult it here.
      if (entry = Redirect.find_by(old_path: request.path))
        redirect_to entry.new_path, status: (entry.status_code || 301)
        return false
      end
      return render_not_found
    end

    if request.path != article.canonical_path
      redirect_to article.canonical_path, status: :moved_permanently
      return false
    end

    @article = article
    @meta = { title: helpers.seo_title(article.meta_title.presence || article.title),
              description: helpers.meta_description(article.meta_description.presence || article.excerpt.presence || article.content),
              type: "article", image: article.featured_image_url }
    true
  end
end
