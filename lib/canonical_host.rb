# frozen_string_literal: true

# Collapses duplicate URL variants to one canonical form:
#   * any host other than CANONICAL_HOST (e.g. www.) -> the apex host
#   * trailing slashes (except "/")                   -> slash-less path
# Only active when CANONICAL_HOST is set (production). Health checks on /up
# are left alone because Fly hits them with an internal Host header.
class CanonicalHost
  def initialize(app, host: ENV["CANONICAL_HOST"])
    @app = app
    @host = host.presence
  end

  def call(env)
    request = Rack::Request.new(env)
    path = request.path
    return @app.call(env) if path == "/up" || path.start_with?("/rails/")

    target_path = path.length > 1 && path.end_with?("/") ? path.sub(%r{/+\z}, "") : path
    target_path = "/" if target_path.empty?
    wrong_host = @host && request.host != @host

    return @app.call(env) unless wrong_host || target_path != path

    scheme = @host ? "https" : request.scheme
    location = "#{scheme}://#{@host || request.host_with_port}#{target_path}"
    location += "?#{request.query_string}" if request.query_string.present?
    [301, { "location" => location, "content-type" => "text/html", "cache-control" => "public, max-age=86400" }, ["Moved Permanently"]]
  end
end
