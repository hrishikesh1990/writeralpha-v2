import { Controller } from "@hotwired/stimulus"

// "Copy link" for a finished result. The link is already visible in a
// read-only field, so this button only appears when JavaScript can copy it.
export default class extends Controller {
  static targets = ["source", "button"]

  connect() {
    if (this.hasButtonTarget) this.buttonTarget.classList.remove("hidden")
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    const text = this.sourceTarget.value
    try {
      await navigator.clipboard.writeText(text)
    } catch (_error) {
      this.sourceTarget.select()
      document.execCommand?.("copy")
    }
    this.confirm()
  }

  confirm() {
    const button = this.buttonTarget
    const original = button.dataset.label || button.textContent
    button.dataset.label = original
    button.textContent = "Link copied"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { button.textContent = original }, 2000)
  }
}
