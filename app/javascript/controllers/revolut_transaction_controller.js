import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="revolut-transaction"
export default class extends Controller {
  static values = { id: Number }

  update(event) {
    const input = event.target
    const name = input.name
    const value = input.value
    const id = this.idValue

    fetch(`/revolut_transactions/${id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        revolut_transaction: {
          [name]: value
        }
      })
    })
    .then(response => {
      if (response.ok) {
        // Optional: Visual feedback like flashing green
        input.classList.add("bg-green-100")
        setTimeout(() => input.classList.remove("bg-green-100"), 500)
      } else {
        input.classList.add("bg-red-100")
        alert("Failed to update transaction")
      }
    })
    .catch(error => {
      console.error("Error updating transaction:", error)
      input.classList.add("bg-red-100")
    })
  }
}
