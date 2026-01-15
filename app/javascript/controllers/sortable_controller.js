import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
    static values = { url: String }

    connect() {
        this.sortable = Sortable.create(this.element, {
            onEnd: this.end.bind(this)
        })
    }

    end(event) {
        let id = event.item.dataset.id
        let newIndex = event.newIndex
        let sortOrder = []

        // Iterate over children to generate new order
        // We send array of Article IDs in order.
        Array.from(this.element.children).forEach((child) => {
            sortOrder.push(child.dataset.id)
        })

        // Send PUT request
        fetch(this.urlValue, {
            method: "PATCH",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
            },
            body: JSON.stringify({ article_ids: sortOrder })
        })
            .then(response => {
                if (!response.ok) {
                    console.error("Sortable update failed:", response.statusText)
                }
            })
            .catch(error => console.error("Sortable error:", error))
    }
}
