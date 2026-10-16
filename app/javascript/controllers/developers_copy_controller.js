import { Controller } from "@hotwired/stimulus"

// Copy-to-clipboard for code blocks on /developers. The button is hidden in
// the HTML and only revealed here, so without JavaScript there is no dead button.
export default class extends Controller {
  static targets = ["source", "button", "status"]

  connect() {
    if (this.hasButtonTarget) this.buttonTarget.hidden = false
  }

  async copy(event) {
    event.preventDefault()
    const text = this.sourceTarget.textContent.replace(/\s+$/, "")
    try {
      await navigator.clipboard.writeText(text)
    } catch (_error) {
      this.fallbackCopy(text)
    }
    this.flash()
  }

  fallbackCopy(text) {
    const area = document.createElement("textarea")
    area.value = text
    area.setAttribute("readonly", "")
    area.style.position = "fixed"
    area.style.opacity = "0"
    document.body.appendChild(area)
    area.select()
    document.execCommand("copy")
    area.remove()
  }

  flash() {
    const button = this.buttonTarget
    const original = button.dataset.label || button.textContent
    button.dataset.label = original
    button.textContent = "Copied"
    if (this.hasStatusTarget) this.statusTarget.textContent = "Copied to clipboard"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      button.textContent = original
      if (this.hasStatusTarget) this.statusTarget.textContent = ""
    }, 1600)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
