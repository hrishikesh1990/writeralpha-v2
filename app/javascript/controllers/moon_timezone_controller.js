import { Controller } from "@hotwired/stimulus"

// Detects the browser time zone. With no ?tz= in the URL it moves to the same
// page in the visitor's zone once per session (replacing history, so Back works);
// otherwise it only offers a "use my time zone" button. Pure enhancement: the
// page is fully server-rendered and works without this.
export default class extends Controller {
  static targets = ["select", "form", "detected"]
  static values = { current: String, explicit: Boolean, base: String }

  connect() {
    // Back/Forward can restore a cached page with the menu on a zone the user chose later.
    if (this.hasSelectTarget) {
      const shown = this.currentValue || "UTC"
      if ([...this.selectTarget.options].some((o) => o.value === shown)) this.selectTarget.value = shown
    }

    let zone
    try { zone = Intl.DateTimeFormat().resolvedOptions().timeZone } catch (_) { return }
    if (!zone) return
    this.zone = zone
    const here = this.currentValue || "UTC"
    const isUtc = zone === "UTC" || zone === "Etc/UTC"
    // Browsers may report a legacy alias ("Asia/Calcutta") for the zone the page shows ("Asia/Kolkata").
    const same = zone === here || (isUtc && here === "UTC") || this.sameOffsets(zone, here)

    if (this.hasDetectedTarget && !same) {
      this.detectedTarget.textContent = `Use my time zone (${this.friendlyName(zone)})`
      this.detectedTarget.hidden = false
    }

    if (this.explicitValue || isUtc || same) return
    try {
      if (sessionStorage.getItem("moon-tz-tried")) return
      sessionStorage.setItem("moon-tz-tried", "1")
    } catch (_) { return }
    this.go(zone, "replace")
  }

  // The select auto-submits on a mouse or touch choice. Arrow keys and type-ahead
  // on a closed select also fire "change"; those wait for Enter or the Show button
  // so keyboard users are not thrown to a new page on every key press.
  keydown(event) {
    this.keyboardChange = !["Enter", "Tab"].includes(event.key)
  }

  change() {
    if (this.keyboardChange) { this.keyboardChange = false; return }
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

  friendlyName(zone) {
    try {
      const part = new Intl.DateTimeFormat("en", { timeZone: zone, timeZoneName: "long" })
        .formatToParts(new Date()).find((p) => p.type === "timeZoneName")
      if (part) return part.value
    } catch (_) { /* fall through */ }
    return zone.split("/").pop().replace(/_/g, " ")
  }

  // True when both zones have the same UTC offset on four dates across a year.
  sameOffsets(a, b) {
    try {
      const year = new Date().getUTCFullYear()
      return [0, 3, 6, 9].every((m) => {
        const d = new Date(Date.UTC(year, m, 15, 12))
        return this.offset(a, d) === this.offset(b, d)
      })
    } catch (_) { return false }
  }

  offset(zone, date) {
    const f = new Intl.DateTimeFormat("en-US", { timeZone: zone, hourCycle: "h23", year: "numeric", month: "numeric", day: "numeric", hour: "numeric", minute: "numeric" })
    const p = Object.fromEntries(f.formatToParts(date).map((x) => [x.type, x.value]))
    return Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute) - date.getTime()
  }
}
