import { Controller } from "@hotwired/stimulus"

// Detects the browser time zone. With no ?tz= in the URL it moves to the same
// page in the visitor's zone once per session (replacing history, so Back works);
// otherwise it only offers a "use my time zone" button. Pure enhancement: the
// page is fully server-rendered and works without this.
export default class extends Controller {
  static targets = ["select", "form", "detected"]
  static values = { current: String, explicit: Boolean, base: String }

  connect() {
    let zone
    try { zone = Intl.DateTimeFormat().resolvedOptions().timeZone } catch (_) { return }
    if (!zone) return
    this.zone = zone
    const here = this.currentValue || "UTC"
    const isUtc = zone === "UTC" || zone === "Etc/UTC"

    if (this.hasDetectedTarget && !isUtc && zone !== here) {
      this.detectedTarget.textContent = `Use my time zone (${zone.replace(/_/g, " ")})`
      this.detectedTarget.hidden = false
    }

    if (this.explicitValue || isUtc || zone === here) return
    try {
      if (sessionStorage.getItem("moon-tz-tried")) return
      sessionStorage.setItem("moon-tz-tried", "1")
    } catch (_) { return }
    this.go(zone, "replace")
  }

  change() {
    this.formTarget.requestSubmit()
  }

  useDetected() {
    if (this.zone) this.go(this.zone, "advance")
  }

  go(zone, action) {
    const url = new URL(window.location.href)
    url.searchParams.set("tz", zone)
    if (window.Turbo) window.Turbo.visit(url.toString(), { action })
    else window.location.replace(url.toString())
  }
}
