# frozen_string_literal: true

require "test_helper"

class AtlasApiTest < ActiveSupport::TestCase
  FakeGemstone = Struct.new(:featured_image_url, :content, :flags) do
    def attributes = flags
    def sub_page_content(path) = content[path]
  end

  BASE = "https://writeralpha.com"

  def entry(slug, image: "/images/gemstones/#{slug}.jpg", flags: {}, content: {})
    stone = Atlas[slug] or skip("Atlas file for #{slug} not present")
    AtlasEntry.new(stone, FakeGemstone.new(image, content, flags))
  end

  def all_entries = Atlas.stones.map { |s| AtlasEntry.new(s, FakeGemstone.new(nil, {}, {})) }

  test "summary has the documented lean fields" do
    s = AtlasApi.summary(entry("amethyst"), base: BASE)
    assert_equal %w[slug name url api_url kind species mohs colors safety tradition image_url], s.keys
    assert_equal "https://writeralpha.com/gemstones/amethyst", s["url"]
    assert_equal "https://writeralpha.com/api/v1/stones/amethyst", s["api_url"]
    assert_equal({ "min" => 7, "max" => 7 }, s["mohs"])
    assert_equal "safe", s["safety"]["water"]
    assert_equal "none", s["safety"]["toxicity"]
    assert_equal %w[crown third_eye], s["tradition"]["chakras"]
    assert_equal "https://writeralpha.com/images/gemstones/amethyst.jpg", s["image_url"]
    refute s.to_json.include?("reason"), "summary carries verdicts only, never reasons"
  end

  test "detail is a superset of summary with identical values" do
    e = entry("malachite")
    s = AtlasApi.summary(e, base: BASE)
    d = AtlasApi.detail(e, base: BASE)
    s.each do |key, value|
      if value.is_a?(Hash)
        assert_equal value, d[key].slice(*value.keys), key
      else
        assert_equal value, d[key], key
      end
    end
    assert_equal "caution", d["safety"]["toxicity"]
    assert d["safety_notes"]["toxicity"].present?
    assert d["identification"]["tests"].first.key?("how")
    assert_includes d["tradition"]["note"], "not as scientific fact"
    assert_equal Atlas["malachite"].sources, d["sources"]
    assert_equal Atlas["malachite"].safe_cleanse_methods, d["cleanse"]["safe"]
  end

  test "detail links list only guides that exist" do
    e = entry("amethyst", content: { "meaning" => "text", "can-go-in-water" => "text" })
    assert_equal %w[meaning can-go-in-water], AtlasApi.detail(e, base: BASE)["links"]["guides"].keys
    flagged = entry("amethyst", flags: { "has_how_to_identify" => true, "has_meaning" => false })
    assert_equal %w[how-to-identify], AtlasApi.detail(flagged, base: BASE)["links"]["guides"].keys
  end

  test "missing image yields null" do
    assert_nil AtlasApi.summary(entry("amethyst", image: nil), base: BASE)["image_url"]
  end

  test "envelope carries licence, attribution and version" do
    env = AtlasApi.envelope([], count: 0, base: BASE, now: Time.utc(2026, 10, 16, 9))
    assert_equal({ "count" => 0, "version" => "1", "license" => "CC BY 4.0",
                   "license_url" => "https://creativecommons.org/licenses/by/4.0/",
                   "attribution" => "Data: WriterAlpha Gemstone Atlas (https://writeralpha.com/developers)",
                   "documentation_url" => "https://writeralpha.com/developers",
                   "generated_at" => "2026-10-16T09:00:00Z" }, env["meta"])
  end

  test "base_url prefers CANONICAL_HOST" do
    old = ENV["CANONICAL_HOST"]
    ENV["CANONICAL_HOST"] = "writeralpha.com"
    assert_equal "https://writeralpha.com", AtlasApi.base_url
  ensure
    ENV["CANONICAL_HOST"] = old
  end

  test "filters AND across parameters and OR within one" do
    entries = all_entries
    safe, applied, = AtlasApi.filter(entries, "water" => "safe")
    assert safe.all? { |e| e.safety("water") == "safe" }
    assert_equal({ "water" => ["safe"] }, applied)

    both, = AtlasApi.filter(entries, "water" => "safe,brief")
    assert both.size >= safe.size
    assert both.all? { |e| %w[safe brief].include?(e.safety("water")) }

    narrow, = AtlasApi.filter(entries, "water" => "safe", "sun" => "limit")
    assert narrow.all? { |e| e.safety("water") == "safe" && e.safety("sun") == "limit" }
  end

  test "filters accept hyphen or underscore spellings and any case" do
    entries = all_entries
    a, = AtlasApi.filter(entries, "chakra" => "third-eye")
    b, = AtlasApi.filter(entries, "chakra" => "THIRD_EYE")
    assert_equal a.map(&:slug), b.map(&:slug)
    assert a.all? { |e| e.chakras.include?("third_eye") }
    assert_nothing_raised { AtlasApi.filter(entries, "intention" => "peace_calm") }
  end

  test "invalid values raise with the allowed list" do
    err = assert_raises(AtlasApi::InvalidParameter) { AtlasApi.filter(all_entries, "water" => "soaking") }
    assert_equal "water", err.parameter
    assert_equal %w[safe brief avoid], err.allowed
    assert_includes err.message, "safe, brief, avoid"
    assert_raises(AtlasApi::InvalidParameter) { AtlasApi.filter(all_entries, "mohs_min" => "11") }
    assert_raises(AtlasApi::InvalidParameter) { AtlasApi.filter(all_entries, "water" => ",") }
    assert_raises(AtlasApi::InvalidParameter) { AtlasApi.filter(all_entries, "q" => "x" * 81) }
  end

  test "blank and unknown parameters are ignored" do
    entries = all_entries
    out, applied, = AtlasApi.filter(entries, "water" => "", "colour" => "red")
    assert_equal entries.size, out.size
    assert_empty applied
  end

  test "q searches names, aliases, species and family" do
    out, = AtlasApi.filter(all_entries, "q" => "QUARTZ")
    assert_includes out.map(&:slug), "amethyst"
  end

  test "mohs filters use range overlap" do
    hard, = AtlasApi.filter(all_entries, "mohs_min" => "7")
    assert hard.all? { |e| e.mohs_max >= 7 }
    soft, = AtlasApi.filter(all_entries, "mohs_max" => "3")
    assert soft.all? { |e| e.mohs_min <= 3 }
  end

  test "every filter's values come from Atlas vocabularies" do
    assert_equal Atlas::CHAKRAS, AtlasApi::FILTERS["chakra"][:values]
    assert_equal Atlas::INTENTIONS, AtlasApi::FILTERS["intention"][:values]
    assert_equal Atlas::SAFETY_VERDICTS["sun"], AtlasApi::FILTERS["sun"][:values]
  end

  test "etag changes with data and is stable otherwise" do
    assert_equal AtlasApi.etag_for({ "a" => 1 }), AtlasApi.etag_for({ "a" => 1 })
    refute_equal AtlasApi.etag_for({ "a" => 1 }), AtlasApi.etag_for({ "a" => 2 })
    refute_equal AtlasApi.etag_for({ "a" => 1 }, true), AtlasApi.etag_for({ "a" => 1 }, false)
  end

  test "every Atlas stone serializes to valid JSON" do
    all_entries.each do |e|
      assert JSON.parse(JSON.generate(AtlasApi.detail(e, base: BASE))), e.slug
    end
  end
end
