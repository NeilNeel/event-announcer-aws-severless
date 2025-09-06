const API_BASE = "https://2dtu2xkiw7.execute-api.us-east-1.amazonaws.com/dev";

// Handle subscription form
document
  .getElementById("subscriber-form")
  .addEventListener("submit", async (e) => {
    e.preventDefault();

    const email = document.getElementById("email").value;
    const submitBtn = document.getElementById("subscribe-btn");
    const successMsg = document.getElementById("subscribe-success");
    const errorMsg = document.getElementById("email-error");

    // Show loading state
    submitBtn.classList.add("loading");
    errorMsg.classList.remove("show");
    successMsg.style.display = "none";

    try {
      const response = await fetch(`${API_BASE}/subscribe`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });

      const result = await response.json();

      // Debug logging
      console.log("Subscribe response:", response.status, result);

      if (response.ok) {
        // Handle the new response format
        const message = result.message || result;
        successMsg.textContent = message;
        successMsg.style.display = "block";
        document.getElementById("subscriber-form").reset();
      } else {
        // Handle the new response format
        const errorText =
          result.error || result.message || "Subscription failed";

        if (response.status === 429) {
          errorMsg.textContent = "Too many requests. Please wait a moment and try again.";
        } else {
          errorMsg.textContent = errorText;
        }
        errorMsg.classList.add("show");
      }
    } catch (error) {
      errorMsg.textContent = "Network error. Please try again.";
      errorMsg.classList.add("show");
    } finally {
      submitBtn.classList.remove("loading");
    }
  });

// Handle event creation form
document.getElementById("event-form").addEventListener("submit", async (e) => {
  e.preventDefault();

  const formData = {
    event_title: document.getElementById("title").value,
    event_description: document.getElementById("description").value,
     event_datetime: (() => {
    const datetimeValue = document.getElementById("datetime").value;
    if (!datetimeValue) return null;

    // Create date object and ensure it's in the future
    const eventDate = new Date(datetimeValue);
    const now = new Date();

    if (eventDate <= now) {
      throw new Error("Event date must be in the future");
    }

    return Math.floor(eventDate.getTime() / 1000);
  })(),
    location: document.getElementById("location").value,
    category:
      document.getElementById("category").value === "other"
        ? document.getElementById("other-category").value
        : document.getElementById("category").value,
  };

  const submitBtn = document.getElementById("create-event-btn");
  const confirmCard = document.getElementById("confirmation-card");

  // Show loading state
  submitBtn.classList.add("loading");

  try {
    const response = await fetch(`${API_BASE}/event`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(formData),
    });

    const result = await response.json();

    // Debug logging
    console.log("Create event response:", response.status, result);

    if (response.ok) {
      // Show confirmation card
      document.getElementById("event-summary").innerHTML = `
                <strong>${formData.event_title}</strong><br>
                ${new Date(formData.event_datetime * 1000).toLocaleString()}<br>
                ${formData.location}
            `;
      confirmCard.classList.add("show");

      // Reset form
      document.getElementById("event-form").reset();
    } else {
      // Handle the new response format
      const errorText = result.error || result.message || "Unknown error";
      const titleError = document.getElementById("title-error");
      titleError.textContent = "Failed to create event: " + errorText;
      titleError.classList.add("show");
    }
  } catch (error) {
    alert("Network error. Please try again.");
  } finally {
    submitBtn.classList.remove("loading");
  }
});

// Handle category selection
document.getElementById("category").addEventListener("change", (e) => {
  const otherGroup = document.getElementById("other-category-group");
  if (e.target.value === "other") {
    otherGroup.classList.add("show");
  } else {
    otherGroup.classList.remove("show");
  }
});

// Close confirmation card
document.getElementById("close-confirmation").addEventListener("click", () => {
  document.getElementById("confirmation-card").classList.remove("show");
});
