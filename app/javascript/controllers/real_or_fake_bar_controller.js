import { Controller } from "@hotwired/stimulus"

// The pinned mobile verdict bar. It only exists to bring you back to the verdict,
// so it steps aside (and stops taking taps) whenever the verdict itself, the
// footnote or the site footer is on screen. That keeps it from ever covering
// content at the end of the page.
export default class extends Controller {
  static targets = ["link"]
  static values = { watch: String }

  connect() {
    this.visible = new Set()
    const targets = Array.from(document.querySelectorAll(this.watchValue))
    if (!("IntersectionObserver" in window) || targets.length === 0) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((e) => (e.isIntersecting ? this.visible.add(e.target) : this.visible.delete(e.target)))
      const away = this.visible.size > 0
      this.element.dataset.away = String(away)
      if (this.hasLinkTarget) {
        if (away) this.linkTarget.setAttribute("tabindex", "-1")
        else this.linkTarget.removeAttribute("tabindex")
        this.linkTarget.setAttribute("aria-hidden", String(away))
      }
    }, { rootMargin: "0px 0px 120px 0px" }) // step aside a little early, so the last test's buttons are never under the bar
    targets.forEach((t) => this.observer.observe(t))
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }
}
