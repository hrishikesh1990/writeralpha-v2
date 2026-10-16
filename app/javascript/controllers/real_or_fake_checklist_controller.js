import { Controller } from "@hotwired/stimulus"

// Real or Fake? checklist. Progressive enhancement only: without JavaScript the
// form is a plain GET and the "Show my result" button does the job.
//
// - Submits the form (into its Turbo Frame) shortly after every answer, so the
//   verdict updates as you go.
// - Gently scrolls the next unanswered test into view on small screens, so you
//   can keep working with the stone in your hand.
export default class extends Controller {
  static targets = ["submit", "status"]
  static values = { delay: { type: Number, default: 150 }, advance: { type: Boolean, default: true } }

  connect() {
    this.submitTargets.forEach((el) => { el.hidden = true })
    this.announce = (event) => {
      if (!this.hasStatusTarget || event.target.id !== "rof-result") return
      const heading = event.target.querySelector("#rof-verdict h2")
      const summary = event.target.querySelector("#rof-verdict h2 + p")
      if (heading) this.statusTarget.textContent = [heading.textContent, summary && summary.textContent].filter(Boolean).join(". ")
    }
    document.addEventListener("turbo:frame-render", this.announce)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("turbo:frame-render", this.announce)
  }

  answered(event) {
    const input = event.target
    if (!(input instanceof HTMLInputElement) || input.type !== "radio") return

    const step = input.closest("[data-step]")
    const wasNew = step && step.dataset.answered !== "true"
    if (step) step.dataset.answered = "true"

    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)

    // The verdict sits in view beside the list on large screens, so only advance on small ones.
    if (wasNew && this.advanceValue && window.matchMedia("(max-width: 1023px)").matches) this.advanceFrom(step)
  }

  advanceFrom(step) {
    const steps = Array.from(this.element.querySelectorAll("[data-step]"))
    const next = steps.slice(steps.indexOf(step) + 1).find((el) => el.dataset.answered !== "true")
    if (!next) return

    // Only scroll when the next test is not already comfortably in view.
    if (next.getBoundingClientRect().top < window.innerHeight * 0.55) return

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    setTimeout(() => next.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" }), 250)
  }
}
