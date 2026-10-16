import { Controller } from "@hotwired/stimulus"

// Rewrites <time datetime="..."> elements from the server's UTC text into the
// visitor's own time zone. Without JavaScript the UTC text stays.
export default class extends Controller {
  static targets = ["time"]

  connect() {
    let zone
    try { zone = Intl.DateTimeFormat().resolvedOptions().timeZone } catch (_) { return }
    this.timeTargets.forEach((el) => {
      const date = new Date(el.getAttribute("datetime"))
      if (isNaN(date)) return
      try {
        el.textContent = date.toLocaleString(undefined, {
          weekday: "short", day: "numeric", month: "short", year: "numeric",
          hour: "numeric", minute: "2-digit", timeZoneName: "short", timeZone: zone
        })
        el.title = `Shown in your time zone (${zone})`
      } catch (_) { /* keep the UTC text */ }
    })
  }
}
