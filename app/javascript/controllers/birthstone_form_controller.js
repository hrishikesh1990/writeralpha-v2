import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the birthstone calculator. The page works
// without JavaScript (a plain GET form); this adds:
//   - auto-submit when a complete, valid date or a rashi is chosen
//   - keeping the form fields and the language links in step with the result
//     after a Turbo Frame update (the form and links sit outside the frame)
//   - a smooth scroll to the results after the Turbo Frame updates
//   - a "copy link" button for the shareable result URL
export default class extends Controller {
  static targets = ["form", "date", "rashi", "frame", "copy", "state", "langNav"]

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

  // change on the small rashi form inside the Vedic card: route it through the
  // main form so there is one source of truth for the inputs.
  submitNow(event) {
    event.stopPropagation()
    const select = event.target
    if (!this.hasRashiTarget || !this.hasFormTarget) {
      event.currentTarget.requestSubmit()
      return
    }
    this.rashiTarget.value = select.value
    if (this.hasDateTarget && !this.dateTarget.value && this.hasStateTarget) {
      this.dateTarget.value = this.stateTarget.dataset.dob || ""
    }
    this.formTarget.requestSubmit()
  }

  // Pressing the card's own button: same route, so the URL matches the main form.
  submitCard(event) {
    if (!this.hasRashiTarget || !this.hasFormTarget) return
    event.preventDefault()
    const select = event.currentTarget.querySelector("select[name=rashi]")
    if (select) this.rashiTarget.value = select.value
    this.formTarget.requestSubmit()
  }

  frameTargetConnected(frame) {
    frame.addEventListener("turbo:frame-load", () => this.reveal(frame))
  }

  // A new frame body carries the inputs the server used; mirror them into the
  // outer form and the language links.
  stateTargetConnected(state) {
    const { dob = "", dobRaw = "", rashi = "" } = state.dataset
    if (this.hasDateTarget && this.dateTarget.value !== dob) this.dateTarget.value = dob
    if (this.hasRashiTarget && this.rashiTarget.value !== rashi) this.rashiTarget.value = rashi
    if (this.hasLangNavTarget) {
      this.langNavTarget.querySelectorAll("a[data-lang-code]").forEach((a) => {
        const params = new URLSearchParams()
        if (dobRaw) params.set("dob", dobRaw)
        if (rashi) params.set("rashi", rashi)
        if (a.dataset.langCode !== "en") params.set("lang", a.dataset.langCode)
        const qs = params.toString()
        a.setAttribute("href", window.location.pathname + (qs ? `?${qs}` : ""))
      })
    }
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
