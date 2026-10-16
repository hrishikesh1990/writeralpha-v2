import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as the select changes. The submit button stays in
// the markup (it is what people without JavaScript use) and is hidden here.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.buttonTargets.forEach((b) => b.classList.add("sr-only"))
  }

  submit(event) {
    if (!event.target.value) return
    this.element.requestSubmit()
  }
}
