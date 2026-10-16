# frozen_string_literal: true

require "test_helper"

class AtlasPanelHelperTest < ActionView::TestCase
  include AtlasPanelHelper

  def stone(slug) = Atlas[slug] || skip("Atlas file for #{slug} not present")

  test "kind labels are honest and never a sentence" do
    assert_equal "Quartz variety", atlas_kind_label(stone("amethyst"))
    assert_equal "Man-made glass", atlas_kind_label(stone("cherry-quartz"))
    assert_equal "Jewellery", atlas_kind_label(stone("tortoise-ring"))
    assert_equal "Treated quartz", atlas_kind_label(stone("angel-aura-quartz"))
    assert_equal "Treated stone", atlas_kind_label(stone("rainbow-hematite"))
    assert_equal "Feldspar variety", atlas_kind_label(stone("moonstone"))
    Atlas.stones.each { |s| assert_operator atlas_kind_label(s).length, :<=, 36, "#{s.slug}: #{atlas_kind_label(s)}" }
  end

  test "badge only for stones that are not natural" do
    assert_nil atlas_unnatural_badge(stone("amethyst"))
    assert_equal "Not a natural stone", atlas_unnatural_badge(stone("opalite"))
    assert_equal "A jewellery piece, not a stone", atlas_unnatural_badge(stone("hematite-rings"))
  end

  test "formula digits become subscripts and markup is escaped" do
    assert_equal "Al<sub>2</sub>O<sub>3</sub>", atlas_formula_html("Al2O3")
    assert_equal "Cu<sub>2</sub>CO<sub>3</sub>(OH)<sub>2</sub>", atlas_formula_html("Cu2CO3(OH)2")
    assert_equal "&lt;b&gt;", atlas_formula_html("<b>")
  end

  test "json-ld is a Thing with the physical facts" do
    entry = AtlasEntry.new(stone("malachite"), Struct.new(:featured_image_url).new(nil))
    ld = atlas_stone_jsonld(entry, base: "https://writeralpha.com")
    assert_equal "Thing", ld["@type"]
    assert_equal "https://writeralpha.com/gemstones/malachite", ld["url"]
    toxicity = ld["additionalProperty"].find { |p| p["name"] == "Toxicity" }
    assert_equal "caution", toxicity["value"]
    assert_nothing_raised { JSON.parse(ld.to_json) }
  end
end
