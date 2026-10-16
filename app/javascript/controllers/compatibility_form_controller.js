import { Controller } from "@hotwired/stimulus"

// Enhancement for the compatibility form: submit as soon as a stone or context
// changes (the Check button stays for everyone else), and keep the URL tidy by
// dropping empty fields from the query string.
export default class extends Controller {
  connect() {
    this.onFormData = (event) => {
      for (const [key, value] of Array.from(event.formData.entries())) {
        if (value === "") event.formData.delete(key)
      }
    }
    this.element.addEventListener("formdata", this.onFormData)
  }

  disconnect() {
    this.element.removeEventListener("formdata", this.onFormData)
    clearTimeout(this.timer)
  }

  changed(event) {
    // Only react to the stone pickers and the context radios.
    const name = event.target?.name
    if (!["a", "b", "c", "d", "ctx"].includes(name)) return
    const a = this.element.querySelector("[name=a]")
    if (!a || !a.value) return

    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 120)
  }
}
