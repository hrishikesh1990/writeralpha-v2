# frozen_string_literal: true

require "test_helper"

class RealOrFakeControllerTest < ActionDispatch::IntegrationTest
  PNG = ("\x89PNG\r\n\x1A\n".b + ("0" * 64)).freeze

  setup do
    # The test database is empty: publish the first Atlas stones that have tests (rolled back after each test).
    stones = Atlas.stones.select { |s| s.tests.any? }.first(3)
    skip "no Atlas stone with identification tests" if stones.empty?
    stones.each { |s| Gemstone.create!(name: s.name, slug: s.slug, published: true, listed: true, how_to_identify_content: "Guide") }
    @stone = stones.first
    @saved_key = ENV["ANTHROPIC_API_KEY"]
  end

  teardown do
    ENV["ANTHROPIC_API_KEY"] = @saved_key
    ENV.delete("ANTHROPIC_API_KEY") if @saved_key.nil?
  end

  def upload(bytes: PNG, name: "stone.png", type: "image/png")
    file = Tempfile.new(["upload", File.extname(name)], binmode: true)
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, true, original_filename: name)
  end

  def with_post(callable)
    original = AuthenticityPhotoCheck.method(:post)
    AuthenticityPhotoCheck.singleton_class.send(:define_method, :post) { |payload| callable.call(payload) }
    yield
  ensure
    AuthenticityPhotoCheck.singleton_class.send(:define_method, :post, original)
  end

  test "picker with no params, unknown stone and garbage params all render" do
    ENV.delete("ANTHROPIC_API_KEY")
    get tools_real_or_fake_path
    assert_response :success
    assert_select "h2", text: /Most faked stones/
    assert_no_match(/robots/, response.body)

    get tools_real_or_fake_path(stone: "no-such-stone", a: { x: "fake" })
    assert_response :success
    assert_match(/do not have a checklist/, response.body)

    get "/tools/real-or-fake?stone[]=x&a=junk"
    assert_response :success
    get "/tools/real-or-fake?stone[a]=x&a[]=1"
    assert_response :success
    get "/tools/real-or-fake?a=junk&a[]=1" # contradictory shapes: Rack answers 400, never a 500
    assert_response :bad_request
    get "/tools/real-or-fake?stone=#{@stone.slug}&a[magnification]=%3Cscript%3E&a[zzz]=fake&a[#{@stone.tests.first['id']}][]=fake"
    assert_response :success
    assert_no_match(/<script>alert/, response.body)
  end

  test "stone page renders the checklist, fakes and verdict, and is noindex" do
    ENV.delete("ANTHROPIC_API_KEY")
    get tools_real_or_fake_path(stone: @stone.slug)
    assert_response :success
    assert_select "input[type=radio][name^='a[']", minimum: @stone.tests.size * 3
    assert_match(/Not started yet/, response.body)
    assert_select "meta[name=robots][content='noindex,follow']"
    assert_select "#photo", count: 0
    @stone.common_fakes.each { |f| assert_includes response.body, ERB::Util.html_escape(f) }
  end

  test "answers drive the verdict and checked radios" do
    ENV.delete("ANTHROPIC_API_KEY")
    id = @stone.tests.max_by { |t| t["weight"].to_i }["id"]
    get tools_real_or_fake_path(stone: @stone.slug, a: { id => "fake" })
    assert_response :success
    assert_select "input[name='a[#{id}]'][value=fake][checked]"
    assert_match(/gemmologist/, response.body)
  end

  test "turbo frame requests get only the frame" do
    id = @stone.tests.first["id"]
    get tools_real_or_fake_path(stone: @stone.slug, a: { id => "real" }), headers: { "Turbo-Frame" => "rof-result" }
    assert_response :success
    assert_select "turbo-frame#rof-result"
    assert_no_match(/<html/, response.body)
    get tools_real_or_fake_path(stone: @stone.slug, a: { id => "real" }), headers: { "Turbo-Frame" => "rof-embed-result" }
    assert_select "turbo-frame#rof-embed-result"
  end

  test "photo section and endpoint do not exist without a key" do
    ENV.delete("ANTHROPIC_API_KEY")
    post tools_real_or_fake_photo_path, params: { stone: @stone.slug, photo: upload }
    assert_response :not_found
    ENV["ANTHROPIC_API_KEY"] = "   "
    post tools_real_or_fake_photo_path, params: { stone: @stone.slug, photo: upload }
    assert_response :not_found
  end

  test "photo section is shown when a key is present" do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    get tools_real_or_fake_path(stone: @stone.slug)
    assert_select "#photo form[enctype='multipart/form-data']"
  end

  test "photo endpoint renders a stubbed result and never calls the network" do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    body = { "content" => [{ "type" => "text", "text" => { observations: ["Even purple colour"], consistent_signs: [], red_flags: ["Round bubble"],
                                                             verdict: "likely_imitation", confidence: "medium",
                                                             next_tests: [@stone.tests.first["id"], "bogus"] }.to_json }] }.to_json
    seen = nil
    with_post(->(p) { seen = p; [200, body] }) do
      post tools_real_or_fake_photo_path, params: { stone: @stone.slug, photo: upload }
    end
    assert_response :success
    assert_match(/Photo shows signs of an imitation/, response.body)
    assert_match(/Round bubble/, response.body)
    assert_match(/gemmologist/, response.body)
    assert_equal "image/png", seen[:messages].first[:content].first[:source][:media_type]
  end

  test "photo endpoint renders inside the turbo frame" do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    with_post(->(_) { [200, { "content" => [{ "type" => "text", "text" => "{}" }] }.to_json] }) do
      post tools_real_or_fake_photo_path, params: { stone: @stone.slug, photo: upload }, headers: { "Turbo-Frame" => "rof-photo" }
    end
    assert_response :success
    assert_select "turbo-frame#rof-photo"
    assert_no_match(/<html/, response.body)
  end

  test "photo endpoint rejects non-images by magic bytes, oversize files and missing uploads" do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    with_post(->(_) { flunk "must not call the API" }) do
      post tools_real_or_fake_photo_path, params: { stone: @stone.slug, photo: upload(bytes: "<html>not an image</html>", name: "evil.png", type: "image/png") }
      assert_response :unprocessable_entity
      assert_match(/JPEG, PNG or WebP/, response.body)

      post tools_real_or_fake_photo_path, params: { stone: @stone.slug, photo: upload(bytes: PNG + ("0" * (5 * 1024 * 1024))) }
      assert_response :unprocessable_entity
      assert_match(/larger than 5 MB/, response.body)

      post tools_real_or_fake_photo_path, params: { stone: @stone.slug }
      assert_response :unprocessable_entity

      post tools_real_or_fake_photo_path, params: { stone: "nope", photo: upload }
      assert_response :unprocessable_entity
    end
  end

  test "network failure shows a friendly message" do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    with_post(->(_) { raise Net::ReadTimeout }) do
      post tools_real_or_fake_photo_path, params: { stone: @stone.slug, photo: upload }
    end
    assert_response :success
    assert_match(/took too long/, response.body)
  end

  test "embeds render nothing for a nil entry and a checklist for a real one" do
    host = ApplicationController.new.view_context
    host.extend(RealOrFakeHelper)
    html = ApplicationController.render(partial: "tools/real_or_fake/embed_stone", locals: { gemstone: nil, entry: nil, guide: "how-to-identify" })
    assert_equal "", html.strip
    entry = AtlasEntry.find(@stone.slug)
    html = ApplicationController.render(partial: "tools/real_or_fake/embed_stone", locals: { gemstone: entry.gemstone, entry: entry, guide: "how-to-identify" })
    assert_match(/rof-embed-result/, html)
    assert_match(/Check your #{Regexp.escape(entry.name)}/, html)
    html = ApplicationController.render(partial: "tools/real_or_fake/embed_picker", locals: { article: nil })
    assert_match(/Check a stone/, html)
  end
end
