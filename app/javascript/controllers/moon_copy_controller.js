import { Controller } from "@hotwired/stimulus"

// Copies the calendar feed link to the clipboard (falls back to selecting the
// input), and, once JavaScript is running, offers a checkbox that switches every
// subscribe link between the full/new moon feed and the all-phases feed.
export default class extends Controller {
  static targets = ["button", "input", "link", "quarters"]
  static values = { text: String, base: String, all: String }

  connect() {
    if (this.hasQuartersTarget) {
      this.quartersTarget.classList.remove("hidden")
      this.quartersTarget.classList.add("flex")
    }
  }

  toggleQuarters(event) {
    const all = event.target.checked
    this.linkTargets.forEach((a) => { a.href = all ? a.dataset.allHref : a.dataset.baseHref })
    this.textValue = all ? this.allValue : this.baseValue
    if (this.hasInputTarget) this.inputTarget.value = this.textValue
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.flash("Copied")
    } catch (_) {
      if (this.hasInputTarget) { this.inputTarget.select(); this.flash("Press Ctrl+C") }
    }
  }

  flash(message) {
    if (!this.hasButtonTarget) return
    clearTimeout(this.timer)
    if (this.original === undefined) this.original = this.buttonTarget.textContent
    this.buttonTarget.textContent = message
    this.timer = setTimeout(() => { this.buttonTarget.textContent = this.original; this.original = undefined }, 1800)
  }
}
