# frozen_string_literal: true

module Api
  module V1
    # Open Gemstone Data, v1. Read-only JSON over the Atlas, CC BY 4.0.
    #
    # Deliberately an ActionController::API subclass, not ApplicationController:
    # no layout, no sessions or CSRF, no browser gate (allow_browser), so
    # curl, servers and any HTTP client are served at the canonical host.
    class StonesController < ActionController::API
      rate_limit to: 120, within: 1.minute, name: "open-data",
                 with: -> { render_error(429, "rate_limited", "Rate limit of 120 requests per minute exceeded. Download everything once with ?full=1 and cache it.", retry_after: 60) }

      before_action :set_open_headers
      rescue_from AtlasApi::InvalidParameter, with: :invalid_parameter

      # GET /api/v1/stones
      def index
        entries, applied, = AtlasApi.filter(AtlasEntry.all, filter_params)
        full = truthy?(params[:full])
        data = entries.map { |e| full ? AtlasApi.detail(e, base:) : AtlasApi.summary(e, base:) }
        respond_cached(data, count: data.size, filters: applied.presence)
      end

      # GET /api/v1/stones/:slug
      def show
        entry = AtlasEntry.find(params[:slug].to_s.downcase)
        return render_error(404, "not_found", "No stone with slug #{params[:slug].to_s.truncate(60).inspect}. List all slugs at #{base}/api/v1/stones.") unless entry

        respond_cached(AtlasApi.detail(entry, base:), count: 1)
      end

      # Catch-all for unknown /api/* paths (see config/routes.rb): a JSON 404 in
      # the same shape as every other error, and a permissive answer to CORS
      # preflights so fetch() with custom headers works from any origin.
      def not_found
        if request.options?
          response.set_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
          response.set_header("Access-Control-Allow-Headers", "*")
          response.set_header("Access-Control-Max-Age", "86400")
          return head :no_content
        end

        render_error(404, "not_found", "Unknown endpoint. The API has GET #{base}/api/v1/stones and GET #{base}/api/v1/stones/:slug.")
      end

      private

      # Only the documented filters; repeated keys (water[]=safe) are read as a
      # comma list, anything else non-scalar is passed on as text so it fails
      # validation with a readable 400.
      def filter_params
        params.to_unsafe_h.slice(*AtlasApi::FILTER_PARAMS).transform_values do |v|
          v.is_a?(Array) ? v.flatten.join(",") : v
        end
      end

      def respond_cached(data, count:, filters: nil)
        expires_in 1.hour, public: true, stale_while_revalidate: 1.day
        return unless stale?(etag: [AtlasApi::VERSION, AtlasApi.etag_for(data, base, pretty?)], public: true)

        render_json(AtlasApi.envelope(data, count:, filters:, base:))
      end

      # Every response (errors and 304s included) is open, and kept out of
      # search results: the dataset is for programs, the hubs are for people.
      def set_open_headers
        response.set_header("Access-Control-Allow-Origin", "*")
        response.set_header("Access-Control-Expose-Headers", "ETag, Retry-After")
        response.set_header("X-Robots-Tag", "noindex")
        response.set_header("Link", %(<#{AtlasApi::LICENSE_URL}>; rel="license", <#{base}#{AtlasApi::DOCS_PATH}>; rel="describedby"))
      end

      def invalid_parameter(error)
        render_error(400, "invalid_parameter", error.message, allowed: error.allowed)
      end

      def render_error(status, code, message, allowed: nil, retry_after: nil)
        set_open_headers
        response.set_header("Retry-After", retry_after.to_s) if retry_after
        response.set_header("Cache-Control", status == 404 ? "public, max-age=60" : "no-store")
        render_json(AtlasApi.error(status:, code:, message:, allowed:, base:), status:)
      end

      def render_json(payload, status: :ok)
        render json: (pretty? ? JSON.pretty_generate(payload) + "\n" : JSON.generate(payload)), status:
      end

      def pretty? = truthy?(params[:pretty])
      def truthy?(value) = %w[1 true yes].include?(value.to_s.downcase)
      def base = @base ||= AtlasApi.base_url(request)
    end
  end
end
