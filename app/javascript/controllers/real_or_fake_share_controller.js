import { Controller } from "@hotwired/stimulus"

// "Copy link to this result". Hidden unless the Clipboard API is available.
export default class extends Controller {
  static targets = ["button"]
  static values = { url: String }

  connect() {
    if (navigator.clipboard && window.isSecureContext) this.buttonTarget.hidden = false
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    const original = this.buttonTarget.textContent
    try {
      await navigator.clipboard.writeText(this.urlValue)
      this.buttonTarget.textContent = "Link copied"
    } catch {
      this.buttonTarget.textContent = "Copy failed, use the address bar"
    }
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.buttonTarget.textContent = original }, 2200)
  }
}
