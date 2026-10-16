import { Controller } from "@hotwired/stimulus"

// The "at a glance" panel on gemstone hubs. Without JavaScript every section
// is open and every reason is visible. On narrow screens this controller folds
// the secondary sections and the per-row reasons so the panel does not push
// the hub's own guides several screens down; from 640px up it opens everything
// again and turns the fold summaries into plain headings.
export default class extends Controller {
  static targets = ["fold", "care", "toggle"]

  connect() {
    this.query = window.matchMedia("(max-width: 639.98px)")
    this.onChange = () => this.sync()
    this.query.addEventListener("change", this.onChange)
    this.sync()
  }

  disconnect() {
    this.query.removeEventListener("change", this.onChange)
  }

  get compact() {
    return this.query.matches
  }

  sync() {
    this.foldTargets.forEach((fold) => {
      fold.open = !this.compact
      const summary = fold.querySelector("summary")
      if (summary) summary.tabIndex = this.compact ? 0 : -1
    })
    if (this.hasCareTarget) this.setReasons(!this.compact)
    if (this.hasToggleTarget) this.toggleTarget.hidden = !this.compact
  }

  // On wide screens the summaries are headings, not controls.
  guard(event) {
    if (!this.compact) event.preventDefault()
  }

  toggleReasons() {
    this.setReasons(this.careTarget.hasAttribute("data-compact"))
  }

  setReasons(show) {
    this.careTarget.toggleAttribute("data-compact", !show)
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", String(show))
      this.toggleTarget.querySelector("[data-label]").textContent = show ? "Hide the reasons" : "Show why for each"
    }
  }
}
