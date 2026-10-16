import { Controller } from "@hotwired/stimulus"

// Instant filtering, search and sorting for the safety matrix. The server
// renders every row (filtered rows carry the `hidden` attribute), so the page
// works without JavaScript; this just does the same thing without a round trip
// and keeps the URL in sync so any view can be shared.
export default class extends Controller {
  static targets = ["form", "list", "chip", "query", "sort", "count", "empty", "apply", "copy"]
  static values = { total: Number }

  connect() {
    if (this.hasApplyTarget) this.applyTarget.classList.add("hidden")
    if (this.hasCopyTarget) this.copyTarget.classList.remove("hidden")
    this.apply({ initial: true })
  }

  // Enter in the search box must not reload the page when JS is available.
  submit(event) {
    event.preventDefault()
    event.stopPropagation()
    this.apply()
  }

  get rowTargets() { return [...this.listTarget.children] }

  apply({ initial } = {}) {
    const selected = this.chipTargets.filter((c) => c.checked).map((c) => c.value)
    const q = this.hasQueryTarget ? this.queryTarget.value.trim().toLowerCase() : ""
    const sort = this.hasSortTarget ? this.sortTarget.value : "name"

    if (!initial) this.sortRows(sort)

    let shown = 0
    this.rowTargets.forEach((row) => {
      const flags = (row.dataset.flags || "").split(" ")
      const ok = selected.every((s) => flags.includes(s)) && (!q || row.dataset.name.includes(q))
      row.hidden = !ok
      if (ok) shown += 1
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = `Showing ${shown} of ${this.totalValue} ${this.totalValue === 1 ? "stone" : "stones"}`
    }
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
    if (!initial) this.syncUrl(selected, q, sort)
  }

  sortRows(sort) {
    const rows = [...this.rowTargets].sort((a, b) => this.compare(this.sortKey(a, sort), this.sortKey(b, sort)))
    const frag = document.createDocumentFragment()
    rows.forEach((r) => frag.appendChild(r))
    this.listTarget.appendChild(frag)
  }

  sortKey(row, sort) {
    const mn = parseFloat(row.dataset.mn)
    const mx = parseFloat(row.dataset.mx)
    const label = row.dataset.label
    if (sort === "hardest") return [-mx, -mn, label]
    if (sort === "softest") return [mn, mx, label]
    return [label]
  }

  compare(a, b) {
    for (let i = 0; i < Math.max(a.length, b.length); i++) {
      if (a[i] === b[i]) continue
      return a[i] < b[i] ? -1 : 1
    }
    return 0
  }

  syncUrl(selected, q, sort) {
    const url = new URL(window.location.href)
    ;["f[]", "q", "sort"].forEach((k) => url.searchParams.delete(k))
    selected.forEach((s) => url.searchParams.append("f[]", s))
    if (q) url.searchParams.set("q", q)
    if (sort && sort !== "name") url.searchParams.set("sort", sort)
    url.hash = ""
    history.replaceState(history.state, "", url)
  }

  reset(event) {
    event.preventDefault()
    this.chipTargets.forEach((c) => { c.checked = false })
    if (this.hasQueryTarget) this.queryTarget.value = ""
    if (this.hasSortTarget) this.sortTarget.value = "name"
    this.apply()
  }

  async copyLink() {
    const url = window.location.href
    try {
      await navigator.clipboard.writeText(url)
      this.flash("Link copied")
    } catch (_e) {
      this.flash("Copy the address bar")
    }
  }

  flash(text) {
    const btn = this.copyTarget
    const original = btn.dataset.original || btn.textContent
    btn.dataset.original = original
    btn.textContent = text
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { btn.textContent = original }, 2000)
  }

  disconnect() { clearTimeout(this.timer) }
}
