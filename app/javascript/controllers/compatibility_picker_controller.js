import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for a stone <select>: on devices with a mouse and
// keyboard it becomes a type-to-search combobox; on touch devices the native
// picker (which people already know) is left alone. The real <select> stays in
// the form and holds the value, so everything works without JavaScript.
export default class extends Controller {
  static targets = ["select", "holder"]
  static classes = ["input", "list", "option", "active", "empty"]

  connect() {
    this.teardown()
    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return
    this.build()
  }

  disconnect() {
    this.teardown()
  }

  // Restores the plain <select> (also used when Turbo restores a cached page
  // that still contains a previously built combobox).
  teardown() {
    this.element.querySelectorAll("[data-combo]").forEach((el) => el.remove())
    const select = this.selectTarget
    select.style.cssText = ""
    select.removeAttribute("aria-hidden")
    select.removeAttribute("tabindex")
  }

  build() {
    const select = this.selectTarget
    this.stoneOptions = Array.from(select.options)
      .filter((o) => o.value)
      .map((o) => ({ value: o.value, label: o.textContent.trim() }))
    this.uid = `combo-${select.id}`

    this.input = document.createElement("input")
    this.input.type = "text"
    this.input.setAttribute("data-combo", "")
    this.input.setAttribute("role", "combobox")
    this.input.setAttribute("aria-autocomplete", "list")
    this.input.setAttribute("aria-expanded", "false")
    this.input.setAttribute("aria-controls", `${this.uid}-list`)
    this.input.setAttribute("aria-label", this.labelText())
    this.input.setAttribute("autocomplete", "off")
    this.input.setAttribute("spellcheck", "false")
    this.input.placeholder = select.options[0]?.textContent.trim() === "None" ? "None (optional)" : "Search or choose a stone"
    this.input.className = this.inputClasses.join(" ")

    this.list = document.createElement("ul")
    this.list.id = `${this.uid}-list`
    this.list.setAttribute("data-combo", "")
    this.list.setAttribute("role", "listbox")
    this.list.hidden = true
    this.list.className = this.listClasses.join(" ")

    // Hide the native select visually but keep it focusable-by-label for the form.
    select.style.cssText = "position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;overflow:hidden;clip:rect(0 0 0 0)"
    select.setAttribute("aria-hidden", "true")
    select.tabIndex = -1

    this.holderTarget.append(this.input, this.list)
    this.syncFromSelect()

    this.input.addEventListener("focus", () => { this.input.select(); this.open() })
    this.input.addEventListener("click", () => this.open())
    this.input.addEventListener("input", () => { this.open(); this.render(this.input.value) })
    this.input.addEventListener("keydown", (e) => this.keydown(e))
    this.input.addEventListener("blur", () => setTimeout(() => this.commitOrRevert(), 120))
    this.list.addEventListener("mousedown", (e) => e.preventDefault()) // keep input focus
    this.list.addEventListener("click", (e) => {
      const li = e.target.closest("[role=option]")
      if (li) this.choose(li.dataset.value)
    })
  }

  labelText() {
    const label = this.element.querySelector(`label[for="${this.selectTarget.id}"]`)
    return label ? label.firstChild.textContent.trim() : "Stone"
  }

  syncFromSelect() {
    const current = this.stoneOptions.find((o) => o.value === this.selectTarget.value)
    this.input.value = current ? current.label : ""
  }

  open() {
    if (!this.list.hidden) return
    this.render("")
    this.list.hidden = false
    this.input.setAttribute("aria-expanded", "true")
    const sel = this.list.querySelector("[aria-selected=true]")
    if (sel) { this.setActive(sel); sel.scrollIntoView({ block: "nearest" }) }
  }

  close(revert = false) {
    if (!this.list) return
    this.list.hidden = true
    this.input.setAttribute("aria-expanded", "false")
    this.input.removeAttribute("aria-activedescendant")
    if (revert) this.syncFromSelect()
  }

  render(query) {
    const q = query.trim().toLowerCase()
    const current = this.selectTarget.value
    // When the box just shows the chosen stone, list everything.
    const showAll = !q || this.stoneOptions.some((o) => o.value === current && o.label.toLowerCase() === q)
    const matches = this.stoneOptions.filter((o) => showAll || o.label.toLowerCase().includes(q))
    this.list.replaceChildren()
    matches.forEach((o, i) => {
      const li = document.createElement("li")
      li.id = `${this.uid}-opt-${i}`
      li.setAttribute("role", "option")
      li.dataset.value = o.value
      li.setAttribute("aria-selected", o.value === current ? "true" : "false")
      li.className = this.optionClasses.join(" ")
      li.textContent = o.label
      this.list.append(li)
    })
    if (matches.length === 0) {
      const li = document.createElement("li")
      li.setAttribute("role", "presentation")
      li.className = this.emptyClasses.join(" ")
      li.textContent = "No matching stone"
      this.list.append(li)
    } else if (q && !showAll) {
      this.setActive(this.list.firstElementChild)
    }
  }

  options_() { return Array.from(this.list.querySelectorAll("[role=option]")) }

  setActive(li) {
    this.options_().forEach((el) => this.activeClasses.forEach((c) => el.classList.remove(c)))
    if (!li) { this.input.removeAttribute("aria-activedescendant"); return }
    this.activeClasses.forEach((c) => li.classList.add(c))
    this.input.setAttribute("aria-activedescendant", li.id)
    li.scrollIntoView({ block: "nearest" })
  }

  keydown(e) {
    const items = this.options_()
    const active = items.find((el) => el.id === this.input.getAttribute("aria-activedescendant"))
    const idx = items.indexOf(active)
    switch (e.key) {
      case "ArrowDown":
        e.preventDefault(); this.open()
        this.setActive(items[Math.min(idx + 1, items.length - 1)] || items[0])
        break
      case "ArrowUp":
        e.preventDefault(); this.open()
        this.setActive(items[Math.max(idx - 1, 0)])
        break
      case "Enter":
        if (!this.list.hidden && active) { e.preventDefault(); this.choose(active.dataset.value) }
        break
      case "Escape":
        if (!this.list.hidden) { e.preventDefault(); this.close(true) }
        break
      case "Backspace":
        if (this.input.value === "" && this.selectTarget.value) this.choose("")
        break
    }
  }

  // Leaving the box: take a unique match for what was typed, else go back to the chosen stone.
  commitOrRevert() {
    if (!this.input) return
    const q = this.input.value.trim().toLowerCase()
    const matches = q ? this.stoneOptions.filter((o) => o.label.toLowerCase().includes(q)) : []
    if (matches.length === 1 && matches[0].value !== this.selectTarget.value) {
      this.choose(matches[0].value)
    } else {
      this.close(true)
    }
  }

  choose(value) {
    const changed = this.selectTarget.value !== value
    this.selectTarget.value = value
    this.syncFromSelect()
    this.close()
    if (changed) this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
