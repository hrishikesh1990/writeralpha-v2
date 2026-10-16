import { Controller } from "@hotwired/stimulus"

// Copies the shareable URL of the current verdict.
export default class extends Controller {
  static targets = ["label"]
  static values = { url: String }

  async copy() {
    const url = new URL(this.urlValue || window.location.href, window.location.origin).toString()
    try {
      await navigator.clipboard.writeText(url)
      this.flash("Link copied")
    } catch {
      window.prompt("Copy this link", url)
    }
  }

  flash(text) {
    if (!this.hasLabelTarget) return
    const original = this.labelTarget.textContent
    this.labelTarget.textContent = text
    setTimeout(() => (this.labelTarget.textContent = original), 1800)
  }
}
