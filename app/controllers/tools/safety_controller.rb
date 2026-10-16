# frozen_string_literal: true

module Tools
  # Crystal Safety Checker: the full safety matrix, a single-stone safety card
  # (?stone=slug) and the multi-stone cleanse planner (?stones[]=a&stones[]=b).
  # Every mode is a GET so every result is a shareable, JavaScript-free URL.
  class SafetyController < ApplicationController
    MAX_PLAN_STONES = 10
    MIN_PLAN_STONES = 2
    SLUG = /\A[a-z0-9][a-z0-9-]{0,63}\z/

    def show
      @entries = AtlasEntry.all
      by_slug = @entries.index_by(&:slug)

      @rows = CrystalSafety.rows(@entries)
      @rows_by_slug = @rows.index_by(&:slug)
      @filters = permitted_filters
      @query = params[:q].is_a?(String) ? params[:q].strip.first(60) : ""
      @sort = CrystalSafety::SORTS.key?(params[:sort].to_s) ? params[:sort].to_s : "name"

      @notices = []
      @stone = nil
      @plan = nil

      requested = single_param(:stone)
      if requested
        @stone = by_slug[requested]
        @notices << "We have no safety card for that stone yet, so here is the full list." unless @stone
      end

      slugs = list_param(:stones)
      if slugs.any?
        known = slugs.filter_map { |s| by_slug[s] }.uniq(&:slug)
        @notices << "Some of those stones are not in the atlas yet and were skipped." if known.size < slugs.uniq.size
        if known.size > MAX_PLAN_STONES
          @notices << "The planner takes up to #{MAX_PLAN_STONES} stones at a time, so we used the first #{MAX_PLAN_STONES}."
          known = known.first(MAX_PLAN_STONES)
        end
        @plan_slugs = known.map(&:slug)
        if known.size >= MIN_PLAN_STONES
          @plan = CrystalSafety.common_methods(known)
          @stone = nil
        else
          @notices << "Add at least #{MIN_PLAN_STONES - known.size} more #{(MIN_PLAN_STONES - known.size) == 1 ? "stone" : "stones"} to plan a shared cleanse."
        end
      end
      @plan_slugs ||= []

      @visible = CrystalSafety.sort(CrystalSafety.filter(@rows, keys: @filters, query: @query), @sort)

      @meta = meta_for
    end

    helper_method :matrix_badge

    private

    # Compact verdict pill for the 85-row matrix. Same tone and wording as the
    # shared verdict_badge, but styled by one CSS rule instead of ~230 bytes of
    # utility classes per cell (see the <style> block in _matrix.html.erb).
    def matrix_badge(verdict, label: nil)
      return helpers.content_tag(:b, "Not rated", class: "csb i") if verdict.nil?

      tone = { good: "g", warn: "w", bad: "r", info: "i" }[helpers.verdict_tone(verdict)]
      helpers.content_tag(:b, label || helpers.verdict_label(verdict), class: "csb #{tone}")
    end

    def meta_for
      if @plan
        names = @plan.rows.map(&:name)
        { title: "How to cleanse #{names.to_sentence} together — Crystal Safety Checker",
          description: "Cleansing methods that are safe for all of #{names.to_sentence}, and which stone rules out each of the others." }
      elsif @stone
        { title: "Is #{@stone.name} safe? Water, salt, sun and sleep — Crystal Safety Checker",
          description: "Can #{@stone.name} go in water, salt water or sun, is it safe to sleep with, is it toxic, and how to cleanse it. Every answer with its reason." }
      else
        { title: "Crystal Safety Checker: Can This Crystal Go in Water, Salt or Sun?",
          description: "Check every crystal for water, salt, sun, sleep and toxicity, with the reason behind each verdict. Pick several stones to find a cleansing method safe for all of them." }
      end
    end

    # A single slug param, or nil. Arrays and hashes are rejected.
    def single_param(key)
      v = params[key]
      v.is_a?(String) && v.match?(SLUG) ? v : nil
    end

    # A list of slugs from ?key[]=a&key[]=b. Anything else is ignored.
    def list_param(key)
      v = params[key]
      return [] unless v.is_a?(Array)

      v.select { |s| s.is_a?(String) && s.match?(SLUG) }.first(40)
    end

    def permitted_filters
      v = params[:f]
      v = [v] if v.is_a?(String)
      return [] unless v.is_a?(Array)

      v.select { |k| k.is_a?(String) && CrystalSafety::FILTER_KEYS.include?(k) }.uniq
    end
  end
end
