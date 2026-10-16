# frozen_string_literal: true

module Tools
  # Birthstone & Navaratna calculator. Everything is a GET param
  # (dob=YYYY-MM-DD, rashi=<sign>, lang=en|hi|bn) so every result is a
  # shareable, server-rendered URL; the Turbo Frame only avoids a full reload.
  class BirthstoneController < ApplicationController
    def show
      @entries = AtlasEntry.all
      @lang = BirthstoneCalculator.normalize_lang(param(:lang))
      @dob = param(:dob)
      @rashi = BirthstoneCalculator.normalize_rashi(param(:rashi))
      @calc = BirthstoneCalculator.new(dob: @dob, rashi: @rashi, lang: @lang, catalog: @entries)
      @submitted = @dob.present? || param(:rashi).present?
      @meta = {
        title: "Birthstone & Navaratna Calculator: Your Stones by Date of Birth",
        description: "Enter your date of birth to see your modern and traditional birthstone, zodiac stones, Vedic ratna by rashi and weekday stone, in English, Hindi and Bengali."
      }
    end

    private

    # Only plain strings are accepted; arrays and hashes (dob[]=x) count as absent.
    def param(key)
      v = params[key]
      v.is_a?(String) ? v.strip.first(60) : ""
    end
  end
end
