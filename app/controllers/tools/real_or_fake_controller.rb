# frozen_string_literal: true

module Tools
  # Real or Fake? An authenticity checklist for each stone, scored as you go,
  # plus an optional AI photo check (only when ANTHROPIC_API_KEY is set).
  #
  # Everything on #show is a GET with answers in the query string, so results
  # are shareable and work without JavaScript. Turbo Frames update the verdict
  # in place: "rof-result" (the tool page), "rof-embed-result" (the inline
  # embed on how-to-identify guides) and "rof-photo" (the photo check).
  class RealOrFakeController < ApplicationController
    MAX_ANSWERS = 40

    # Order matters: with no API key the endpoint is a plain 404 (before CSRF checks) and never
    # counts against (or reveals) the rate limit.
    prepend_before_action :require_photo_check, only: :photo
    rate_limit to: 6, within: 10.minutes, only: :photo, with: -> { photo_rate_limited }

    def show
      load_checker
      set_meta
      render_for_frame
    end

    def photo
      load_checker
      set_meta
      @photo_error = nil
      @photo_outcome = nil
      status = :ok

      if @entry.nil?
        @photo_error = "Choose a stone first, then add a photo of it."
        status = :unprocessable_entity
      else
        begin
          bytes = read_upload(params[:photo])
          media_type = AuthenticityPhotoCheck.validate(bytes)
          @photo_outcome = AuthenticityPhotoCheck.call(stone: @entry, bytes: bytes, media_type: media_type)
        rescue AuthenticityPhotoCheck::InvalidImage => e
          @photo_error = e.message
          status = :unprocessable_entity
        ensure
          bytes = nil # the photo only ever lives in memory for this request
        end
      end

      if turbo_frame_request_id == "rof-photo"
        render partial: "tools/real_or_fake/photo", locals: photo_locals, status: status, layout: false
      else
        render :show, status: status
      end
    end

    private

    # Everything the views need, derived from the query string. Unknown stones,
    # junk answers and odd parameter shapes are ignored, never an error.
    def load_checker
      all = AtlasEntry.all
      @entries = all.select { |e| e.tests.any? }
      slug = params[:stone].is_a?(String) ? params[:stone].strip.downcase.slice(0, 80) : nil
      @entry = slug.present? ? @entries.find { |e| e.slug == slug } : nil
      @unknown_stone = slug.present? && @entry.nil? ? slug : nil
      @photo_enabled = AuthenticityPhotoCheck.enabled?
      return unless @entry

      @check = AuthenticityCheck.new(@entry, answers_param)
      @result = @check.result
    end

    def answers_param
      raw = params[:a]
      return {} unless raw.is_a?(ActionController::Parameters)

      raw.to_unsafe_h.first(MAX_ANSWERS).to_h { |k, v| [k.to_s.slice(0, 40), v.is_a?(String) ? v.slice(0, 20) : nil] }
    end

    def set_meta
      @meta =
        if @entry
          { title: "Is your #{@entry.name} real? Step-by-step home authenticity check — WriterAlpha",
            description: "How to tell if #{@entry.name} is real or fake: #{@entry.tests.size} home tests ordered from safest to riskiest, what real and fake #{@entry.name} look like, and a scored, honest verdict." }
        else
          { title: "Real or Fake? Free Crystal & Gemstone Authenticity Checker — WriterAlpha",
            description: "Pick a stone and work through the home tests that separate real from fake, with an honest score as you go. Covers dyed, glass and resin imitations of #{[@entries&.size.to_i, 3].max}+ stones." }
        end
    end

    def render_for_frame
      case turbo_frame_request_id
      when "rof-result" then render partial: "tools/real_or_fake/result", layout: false
      when "rof-embed-result" then render partial: "tools/real_or_fake/embed_result", layout: false
      when "rof-photo" then render partial: "tools/real_or_fake/photo", locals: photo_locals, layout: false
      end
    end

    def photo_locals = { entry: @entry, outcome: @photo_outcome, error: @photo_error, check: @check }

    def read_upload(file)
      return nil unless file.respond_to?(:read) && file.respond_to?(:size)
      raise AuthenticityPhotoCheck::InvalidImage, "That photo is larger than 5 MB. Please choose a smaller one." if file.size > AuthenticityPhotoCheck::MAX_BYTES

      file.read(AuthenticityPhotoCheck::MAX_BYTES + 1)
    end

    # The photo feature does not exist unless a key is configured.
    def require_photo_check
      render_not_found unless AuthenticityPhotoCheck.enabled?
    end

    def photo_rate_limited
      load_checker
      set_meta
      if turbo_frame_request_id == "rof-photo"
        render partial: "tools/real_or_fake/photo_limited", layout: false, status: :too_many_requests
      else
        render "tools/real_or_fake/rate_limited", status: :too_many_requests
      end
    end
  end
end
