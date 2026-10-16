import { Controller } from "@hotwired/stimulus"

// Copies a link to the clipboard. Falls back to selecting the input.
export default class extends Controller {
  static targets = ["button"]
  static values = { text: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.flash("Copied")
    } catch (_) {
      const input = this.element.querySelector("input[readonly]")
      if (input) { input.select(); this.flash("Press Ctrl+C") }
    }
  }

  flash(message) {
    if (!this.hasButtonTarget) return
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = message
    setTimeout(() => (this.buttonTarget.textContent = original), 1800)
  }
}
