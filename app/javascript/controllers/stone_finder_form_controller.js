import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the Stone Finder form. Without JavaScript the
// form is a plain GET form that works fine; this adds:
//  - a three-goal limit on the intention chips (with a live counter)
//  - auto-submit on wide screens when an answer changes
//  - tidy share URLs (empty fields are dropped from the query string)
//  - scroll to the results after pressing the button on small screens
export default class extends Controller {
  static targets = ["intention", "count", "note"]
  static values = { max: { type: Number, default: 3 } }

  connect() {
    this.timer = null
    this.dropEmpty = (event) => {
      for (const [key, value] of Array.from(event.formData.entries())) {
        if (value === "") event.formData.delete(key)
      }
    }
    this.element.addEventListener("formdata", this.dropEmpty)
    this.sync()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.element.removeEventListener("formdata", this.dropEmpty)
  }

  changed(event) {
    const el = event.target
    if (this.intentionTargets.includes(el)) this.limit(el)
    this.sync()
    this.queueSubmit(el)
  }

  submitted(event) {
    // Only an explicit press of the button scrolls; auto-submits stay put.
    if (!event.submitter) return
    const frame = document.getElementById("finder-results")
    if (!frame) return
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    frame.addEventListener("turbo:frame-render", () => {
      frame.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" })
    }, { once: true })
  }

  limit(el) {
    const chosen = this.intentionTargets.filter((i) => i.checked)
    if (el.checked && chosen.length > this.maxValue) {
      el.checked = false
      this.flash()
    }
  }

  sync() {
    const chosen = this.intentionTargets.filter((i) => i.checked).length
    const full = chosen >= this.maxValue
    this.intentionTargets.forEach((i) => { i.disabled = full && !i.checked })
    if (this.hasCountTarget) this.countTarget.textContent = `${chosen} of ${this.maxValue}`
    if (this.hasNoteTarget && !full) this.noteTarget.classList.add("hidden")
    if (this.hasNoteTarget && full) this.noteTarget.classList.remove("hidden")
  }

  flash() {
    if (this.hasNoteTarget) this.noteTarget.classList.remove("hidden")
  }

  queueSubmit(el) {
    // Auto-submit only where the results sit beside the form; on phones the
    // button is clearer than results changing out of sight.
    if (!window.matchMedia("(min-width: 1024px)").matches) return
    if (el.type === "date" && el.value !== "" && !el.checkValidity()) return
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 350)
  }
}
