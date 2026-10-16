import { Controller } from "@hotwired/stimulus"

// Photo check form: client-side size and type check, a preview that never
// leaves the browser, and a busy state while the server looks at the photo.
export default class extends Controller {
  static targets = ["file", "preview", "problem", "button", "busy"]
  static values = { maxBytes: { type: Number, default: 5 * 1024 * 1024 } }

  disconnect() {
    this.revoke()
  }

  picked() {
    const file = this.fileTarget.files[0]
    this.problemTarget.classList.add("hidden")
    this.revoke()
    this.previewTarget.hidden = true
    if (!file) return

    if (!/^image\/(jpeg|png|webp)$/.test(file.type)) return this.problem("Please choose a JPEG, PNG or WebP photo.")
    if (file.size > this.maxBytesValue) return this.problem("That photo is larger than 5 MB. Please choose a smaller one.")

    this.url = URL.createObjectURL(file)
    this.previewTarget.src = this.url
    this.previewTarget.hidden = false
  }

  submitting(event) {
    if (!this.problemTarget.classList.contains("hidden")) return event.preventDefault()
    this.buttonTarget.disabled = true
    this.busyTarget.classList.remove("hidden")
  }

  problem(message) {
    this.fileTarget.value = ""
    this.problemTarget.textContent = message
    this.problemTarget.classList.remove("hidden")
  }

  revoke() {
    if (this.url) URL.revokeObjectURL(this.url)
    this.url = null
  }
}
