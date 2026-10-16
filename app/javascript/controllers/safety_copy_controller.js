import { Controller } from "@hotwired/stimulus"

// Copies the current page URL (or data-safety-copy-url-value) to the clipboard.
export default class extends Controller {
  static targets = ["button", "status"]
  static values = { url: String }

  async copy() {
    const url = this.urlValue || window.location.href
    let ok = false
    try {
      await navigator.clipboard.writeText(url)
      ok = true
    } catch (_e) {
      ok = this.fallback(url)
    }
    this.announce(ok ? "Link copied" : "Copy failed: copy the address bar instead")
  }

  fallback(text) {
    const ta = document.createElement("textarea")
    ta.value = text
    ta.setAttribute("readonly", "")
    ta.style.position = "fixed"
    ta.style.opacity = "0"
    document.body.appendChild(ta)
    ta.select()
    let ok = false
    try { ok = document.execCommand("copy") } catch (_e) { ok = false }
    ta.remove()
    return ok
  }

  announce(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
    if (this.hasButtonTarget) {
      const original = this.buttonTarget.dataset.original || this.buttonTarget.textContent
      this.buttonTarget.dataset.original = original
      this.buttonTarget.textContent = message.startsWith("Link") ? "Copied" : "Copy failed"
      clearTimeout(this.timer)
      this.timer = setTimeout(() => {
        this.buttonTarget.textContent = original
        if (this.hasStatusTarget) this.statusTarget.textContent = ""
      }, 2200)
    }
  }

  disconnect() { clearTimeout(this.timer) }
}
