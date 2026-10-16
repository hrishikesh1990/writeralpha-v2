# frozen_string_literal: true

require "test_helper"

class AuthenticityPhotoCheckTest < ActiveSupport::TestCase
  PNG = "\x89PNG\r\n\x1A\n".b + ("0" * 40)
  JPEG = "\xFF\xD8\xFF\xE0".b + ("0" * 40)
  WEBP = "RIFF".b + [100].pack("V") + "WEBPVP8 ".b + ("0" * 20)

  def stone
    Atlas::Stone.new(
      "slug" => "amethyst", "name" => "Amethyst", "species" => "quartz",
      "identify" => {
        "common_fakes" => ["Purple glass", "Dyed quartz"],
        "tests" => [{ "id" => "magnification", "weight" => 3, "how" => "Loupe", "real" => "Feathers", "fake" => "Bubbles" },
                    { "id" => "color", "weight" => 2, "how" => "Paper", "real" => "Uneven", "fake" => "Even" }]
      }
    )
  end

  def parse(text) = AuthenticityPhotoCheck.parse(text, stone: stone)

  def fixture(name) = File.read(Rails.root.join("test/fixtures/files/photo_check", name))

  test "parses a clean JSON reply" do
    o = parse(fixture("clean.json"))
    assert o.ok?
    assert_equal "likely_imitation", o.verdict
    assert_equal "medium", o.confidence
    assert_equal ["Photo shows signs of an imitation"], [o.label]
    assert_equal :warn, o.tone
    assert_equal 2, o.observations.size
    assert_equal ["Round bubble near the surface"], o.red_flags
    assert_equal %w[magnification color], o.next_tests
  end

  test "extracts JSON wrapped in code fences and prose" do
    o = parse(fixture("fenced.txt"))
    assert_equal "consistent_with_genuine", o.verdict
    assert_equal "Photo looks consistent with genuine", o.label
    assert_equal "medium", o.confidence, "high confidence is capped for a consistent verdict"
    assert_equal ["magnification"], o.next_tests
  end

  test "drops invented test ids, wrong types and unknown verdicts" do
    o = parse(fixture("messy.json"))
    assert_equal "inconclusive", o.verdict
    assert_equal "low", o.confidence
    assert_equal ["color"], o.next_tests
    assert_equal ["Looks purple"], o.observations
    assert_equal ["not a list"], o.red_flags, "a bare string is kept as a single item"
    assert_operator o.consistent_signs.first.length, :<=, 280
  end

  test "falls back to inconclusive for unusable replies" do
    ["", "I cannot help with that.", "{not json", "[1,2]", nil, "{}"].each do |text|
      o = parse(text)
      assert_equal "inconclusive", o.verdict, text.inspect
      assert o.ok?
      assert_empty o.next_tests
    end
  end

  test "parse_response reads text blocks from an API body" do
    body = { "content" => [{ "type" => "text", "text" => fixture("clean.json") }], "usage" => {} }.to_json
    assert_equal "likely_imitation", AuthenticityPhotoCheck.parse_response(body, stone: stone).verdict
    assert_equal "inconclusive", AuthenticityPhotoCheck.parse_response("not json at all", stone: stone).verdict
    assert_equal "inconclusive", AuthenticityPhotoCheck.parse_response({ "content" => nil }.to_json, stone: stone).verdict
  end

  test "detects image types by magic bytes" do
    assert_equal "image/png", AuthenticityPhotoCheck.validate(PNG)
    assert_equal "image/jpeg", AuthenticityPhotoCheck.validate(JPEG)
    assert_equal "image/webp", AuthenticityPhotoCheck.validate(WEBP)
  end

  test "rejects non-images, empty files and oversize files" do
    assert_raises(AuthenticityPhotoCheck::InvalidImage) { AuthenticityPhotoCheck.validate("GIF89a....".b) }
    assert_raises(AuthenticityPhotoCheck::InvalidImage) { AuthenticityPhotoCheck.validate("<svg onload=alert(1)>".b) }
    assert_raises(AuthenticityPhotoCheck::InvalidImage) { AuthenticityPhotoCheck.validate("RIFF".b + [0].pack("V") + "WAVEfmt ".b) }
    assert_raises(AuthenticityPhotoCheck::InvalidImage) { AuthenticityPhotoCheck.validate("".b) }
    assert_raises(AuthenticityPhotoCheck::InvalidImage) { AuthenticityPhotoCheck.validate(nil) }
    assert_raises(AuthenticityPhotoCheck::InvalidImage) { AuthenticityPhotoCheck.validate(JPEG + ("0" * AuthenticityPhotoCheck::MAX_BYTES)) }
  end

  test "payload carries the image block, the stone's fakes and its test ids" do
    p = AuthenticityPhotoCheck.build_payload(stone: stone, bytes: PNG, media_type: "image/png")
    assert_equal 800, p[:max_tokens]
    img = p[:messages].first[:content].first
    assert_equal "image", img[:type]
    assert_equal "base64", img[:source][:type]
    assert_equal "image/png", img[:source][:media_type]
    assert_equal PNG, Base64.strict_decode64(img[:source][:data])
    assert_includes p[:system], "Purple glass"
    assert_includes p[:system], "- magnification (weight 3)"
    assert_includes p[:system], "consistent_with_genuine|inconclusive|likely_imitation"
  end

  test "call turns network failures into friendly outcomes" do
    with_post(->(_) { raise Net::ReadTimeout }) do
      o = AuthenticityPhotoCheck.call(stone: stone, bytes: PNG)
      assert_not o.ok?
      assert_equal :timeout, o.error
      assert_match(/too long/, o.error_message)
    end
    with_post(->(_) { raise SocketError }) { assert_equal :unavailable, AuthenticityPhotoCheck.call(stone: stone, bytes: PNG).error }
    with_post(->(_) { [429, "{}"] }) { assert_equal :busy, AuthenticityPhotoCheck.call(stone: stone, bytes: PNG).error }
    with_post(->(_) { [401, "{}"] }) { assert_equal :unavailable, AuthenticityPhotoCheck.call(stone: stone, bytes: PNG).error }
    with_post(->(_) { [400, "{}"] }) { assert_equal :unreadable, AuthenticityPhotoCheck.call(stone: stone, bytes: PNG).error }
  end

  test "call parses a stubbed 200 response" do
    body = { "content" => [{ "type" => "text", "text" => fixture("clean.json") }] }.to_json
    seen = nil
    with_post(->(payload) { seen = payload; [200, body] }) do
      o = AuthenticityPhotoCheck.call(stone: stone, bytes: JPEG)
      assert o.ok?
      assert_equal "likely_imitation", o.verdict
    end
    assert_equal "image/jpeg", seen[:messages].first[:content].first[:source][:media_type]
  end

  private

  def with_post(callable)
    original = AuthenticityPhotoCheck.method(:post)
    AuthenticityPhotoCheck.singleton_class.send(:define_method, :post) { |payload| callable.call(payload) }
    yield
  ensure
    AuthenticityPhotoCheck.singleton_class.send(:define_method, :post, original)
  end
end
