import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the birthstone calculator. The page works
// without JavaScript (a plain GET form); this adds:
//   - auto-submit when a complete, valid date or a rashi is chosen
//   - a smooth scroll to the results after the Turbo Frame updates
//   - a "copy link" button for the shareable result URL
export default class extends Controller {
  static targets = ["form", "date", "frame", "copy"]

  connect() {
    this.timer = null
    // Keep shareable URLs clean: drop empty fields (?dob=&rashi=) before a GET submit.
    this.dropEmpty = (event) => {
      for (const [key, value] of [...event.formData.entries()]) {
        if (value === "") event.formData.delete(key)
      }
    }
    this.element.addEventListener("formdata", this.dropEmpty)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.element.removeEventListener("formdata", this.dropEmpty)
  }

  // change on the main form: submit once the date is complete and in range,
  // or when a rashi is picked. Debounced so typing a year does not fire early.
  changed(event) {
    const el = event.target
    if (el === this.dateTarget && !(el.value && el.validity.valid)) return
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.formTarget.requestSubmit(), 250)
  }

  // change on the small rashi form inside the Vedic card
  submitNow(event) {
    event.currentTarget.requestSubmit()
  }

  frameTargetConnected(frame) {
    frame.addEventListener("turbo:frame-load", () => this.reveal(frame))
  }

  reveal(frame) {
    const top = frame.getBoundingClientRect().top
    if (top >= 0 && top < window.innerHeight * 0.6) return
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    frame.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" })
  }

  async copyLink(event) {
    const button = event.currentTarget
    const done = button.dataset.copiedLabel || "Copied"
    const original = button.textContent
    try {
      await navigator.clipboard.writeText(window.location.href)
      button.textContent = done
    } catch (_) {
      window.prompt("Copy this link", window.location.href)
    }
    setTimeout(() => { button.textContent = original }, 2000)
  }
}
