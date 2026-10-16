# frozen_string_literal: true

require "test_helper"

# Endpoint behaviour that does not depend on published gemstone rows
# (the test database is empty, so lists are empty and every slug is unknown).
class OpenDataTest < ActionDispatch::IntegrationTest
  test "list returns the envelope with open headers" do
    get "/api/v1/stones"
    assert_response :ok
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_equal "noindex", response.headers["X-Robots-Tag"]
    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=3600"
    body = JSON.parse(response.body)
    assert_equal "1", body["meta"]["version"]
    assert_equal "CC BY 4.0", body["meta"]["license"]
    assert_equal "Data: WriterAlpha Gemstone Atlas (https://writeralpha.com/developers)", body["meta"]["attribution"]
    assert_kind_of Array, body["data"]
  end

  test "conditional requests return 304" do
    get "/api/v1/stones"
    etag = response.headers["ETag"]
    assert etag.present?
    get "/api/v1/stones", headers: { "If-None-Match" => etag }
    assert_response :not_modified
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "invalid filter value is a 400 listing allowed values" do
    get "/api/v1/stones", params: { water: "soaking" }
    assert_response :bad_request
    err = JSON.parse(response.body)["error"]
    assert_equal "invalid_parameter", err["code"]
    assert_equal %w[safe brief avoid], err["allowed"]
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "unknown slug is a JSON 404" do
    get "/api/v1/stones/not-a-stone"
    assert_response :not_found
    assert_equal "not_found", JSON.parse(response.body)["error"]["code"]
    assert_match %r{application/json}, response.media_type
  end

  test "pretty=1 indents" do
    get "/api/v1/stones", params: { pretty: 1 }
    assert_includes response.body, "\n  \"data\""
  end

  test "developers page renders" do
    get "/developers"
    assert_response :ok
    assert_includes response.body, "Open Gemstone Data"
    assert_includes response.body, "application/ld+json"
  end

  test "repeated filter keys read as a comma list" do
    get "/api/v1/stones", params: { water: %w[safe brief] }
    assert_response :ok
    assert_equal({ "water" => %w[safe brief] }, JSON.parse(response.body)["meta"]["filters"]) if JSON.parse(response.body)["data"].any?
    get "/api/v1/stones", params: { water: { a: "safe" } }
    assert_response :bad_request
  end

  test "unknown stones and bad slugs never raise" do
    ["NOPE", "a%20b", "x" * 300].each do |slug|
      get "/api/v1/stones/#{slug}"
      assert_response :not_found
      assert_equal "not_found", JSON.parse(response.body)["error"]["code"]
    end
  end
end
