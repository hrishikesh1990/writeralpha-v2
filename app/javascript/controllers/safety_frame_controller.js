import { Controller } from "@hotwired/stimulus"

// Keeps Back/Forward honest for Turbo Frames that advance the URL.
// Turbo leaves the last-loaded `src` on a promoted frame, so a restored page
// re-fetches that stale address instead of showing the one in the address bar.
// Clearing it after each load (together with the page's no-cache meta tag)
// makes Back and Forward restore the right result. It also updates the page
// title and brings a new result into view.
export default class extends Controller {
  connect() {
    this.onLoad = (event) => {
      const frame = event.target
      if (!(frame instanceof HTMLElement) || frame.tagName !== "TURBO-FRAME") return
      frame.removeAttribute("src")
      frame.removeAttribute("complete")
      if (frame.id !== "safety_result") return
      // turbo-rails sends frame responses without the page <head>, so the frame
      // carries the title for its own state.
      const title = frame.querySelector("[data-safety-title]")
      if (title && title.dataset.safetyTitle) document.title = title.dataset.safetyTitle
      this.revealResult(frame)
    }
    this.element.addEventListener("turbo:frame-load", this.onLoad)
  }

  // The result renders above the pickers, so after a pick from the lower half of
  // the page bring it into view and move focus to its heading for screen readers.
  revealResult(frame) {
    const target = frame.querySelector("article") || frame
    const top = target.getBoundingClientRect().top
    const heading = target.querySelector("h2")
    if (heading) {
      heading.setAttribute("tabindex", "-1")
      heading.style.outline = "none"
      heading.focus({ preventScroll: true })
    }
    if (top < 0 || top > window.innerHeight * 0.5) {
      const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches
      target.scrollIntoView({ behavior: calm ? "auto" : "smooth", block: "start" })
    }
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.onLoad)
  }
}
