import { Controller } from "@hotwired/stimulus"

// Multi-stone picker for the cleanse planner. The checkboxes are real form
// fields, so the form works without JavaScript; this adds search, a live
// selected count, a 2..10 limit and a Clear button.
export default class extends Controller {
  static targets = ["search", "input", "count", "submit", "clear", "empty", "list"]
  static values = { min: { type: Number, default: 2 }, max: { type: Number, default: 10 } }

  connect() {
    this.refresh()
  }

  filter() {
    const q = this.searchTarget.value.trim().toLowerCase()
    let shown = 0
    this.inputTargets.forEach((input) => {
      const label = input.closest("label")
      const match = input.checked || !q || input.nextElementSibling.textContent.toLowerCase().includes(q)
      label.hidden = !match
      if (match) shown += 1
    })
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", shown > 0)
  }

  toggle() {
    this.refresh()
  }

  clear() {
    this.inputTargets.forEach((i) => { i.checked = false })
    this.refresh()
  }

  refresh() {
    const n = this.inputTargets.filter((i) => i.checked).length
    const atMax = n >= this.maxValue
    this.inputTargets.forEach((i) => { i.disabled = atMax && !i.checked })
    if (this.hasCountTarget) {
      let text = `${n} selected`
      if (n < this.minValue) text += `, pick ${this.minValue - n} more`
      else if (atMax) text += ` (the most we can plan at once)`
      this.countTarget.textContent = text
    }
    if (this.hasSubmitTarget) this.submitTarget.disabled = n < this.minValue
    if (this.hasClearTarget) this.clearTarget.classList.toggle("hidden", n === 0)
  }
}
