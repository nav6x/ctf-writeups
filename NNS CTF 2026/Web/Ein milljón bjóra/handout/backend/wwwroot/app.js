const form = document.getElementById("form");
const result = document.getElementById("result");
const submit = document.getElementById("submit");

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  submit.disabled = true;
  submit.textContent = "Bjórlögreglan skoðar myndina";
  result.innerHTML = '<span class="spinner"></span>';
  try {
    const response = await fetch("/api/beers", {
      method: "POST",
      body: new FormData(form),
    });
    const body = await response.json();
    result.textContent = response.ok
      ? `${body.approved ? "Talinn" : "Skráður en ekki talinn"}: ${body.classification}`
      : body.error;
  } catch {
    result.textContent = "Bjórlögreglan svaraði ekki.";
  } finally {
    submit.disabled = false;
    submit.textContent = "Telja";
  }
  refresh();
});

async function refresh() {
  const stats = await (await fetch("/api/stats")).json();
  document.getElementById("counted").textContent =
    stats.counted.toLocaleString("is-IS");
  document.getElementById("goal").textContent =
    stats.goal.toLocaleString("is-IS");
  document.getElementById("approved").textContent = stats.approved;
  document.getElementById("rejected").textContent = stats.rejected;
  document.getElementById("flag").textContent = stats.flag ?? "";
  draw(stats.map);
}

function draw(places) {
  document.getElementById("dots").innerHTML = places
    .map((place) => {
      const radius = 1.5 + Math.sqrt(place.beers);
      return (
        `<circle cx="${place.x + 180}" cy="${90 - place.y}" r="${radius}">` +
        `<title>${place.x}°, ${place.y}° — ${place.beers}</title></circle>`
      );
    })
    .join("");
}

refresh();
