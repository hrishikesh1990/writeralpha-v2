import { Controller } from "@hotwired/stimulus"

// Instant filter for the stone picker. Without JavaScript the full list of
// stones is simply shown as links.
export default class extends Controller {
  static targets = ["input", "item", "count", "empty", "top"]

  connect() {
    this.inputTarget.hidden = false
  }

  filter() {
    const q = this.inputTarget.value.trim().toLowerCase()
    let shown = 0
    this.itemTargets.forEach((li) => {
      const match = q === "" || li.dataset.search.includes(q)
      li.hidden = !match
      if (match) shown += 1
    })
    if (this.hasCountTarget) this.countTarget.textContent = `(${shown})`
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", shown > 0)
    if (this.hasTopTarget) this.topTarget.parentElement.hidden = q !== ""
  }

  // Enter opens the first visible match.
  go(event) {
    event.preventDefault()
    const first = this.itemTargets.find((li) => !li.hidden)
    const link = first && first.querySelector("a")
    if (link) link.click()
  }
}
