import { Controller } from "@hotwired/stimulus"

// Submits the form when a stone is picked with a mouse or finger. The submit
// button stays visible: it is what keyboard and no-JavaScript visitors use, and
// arrowing through a closed select must not fire a request per option.
export default class extends Controller {
  connect() {
    this.arrowing = false
  }

  key(event) {
    this.arrowing = ["ArrowUp", "ArrowDown", "Home", "End", "PageUp", "PageDown"].includes(event.key) ||
      (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey)
  }

  pointer() {
    this.arrowing = false
  }

  submit(event) {
    if (!event.target.value || this.arrowing) return
    this.element.requestSubmit()
  }
}
