const state = {
  session: null
};

const fieldConfig = {
  clue: { label: "Clue", help: "Pick a clue option or request another batch." },
  hint1: { label: "Hint 1", help: "Primary timed hint shown to players." },
  hint2: { label: "Hint 2", help: "Secondary hint for tougher links." },
  multipleChoiceOptions: { label: "Multiple Choice", help: "Each option is a full set of 4 choices." },
  correctAnswers: { label: "Accepted Answers", help: "Variants accepted as correct answers." },
  answerText: { label: "Answer Text", help: "Shown when the player solves the clue." },
  songStartInfo: { label: "Song Start Info", help: "Shown when the selected song begins." },
  triviaItems: { label: "Trivia Items", help: "Each option is a 3-item trivia set." }
};

const statusEl = document.getElementById("status");
const seedForm = document.getElementById("seed-form");
const candidatePanel = document.getElementById("candidate-panel");
const candidateList = document.getElementById("candidate-list");
const candidateGenerationNote = document.getElementById("candidate-generation-note");
const manualCandidateForm = document.getElementById("manual-candidate-form");
const fieldsPanel = document.getElementById("fields-panel");
const fieldsContainer = document.getElementById("fields-container");
const summaryEl = document.getElementById("selected-candidate-summary");
const exportPanel = document.getElementById("export-panel");
const exportForm = document.getElementById("export-form");
const exportResult = document.getElementById("export-result");
const fieldTemplate = document.getElementById("field-template");

bootstrap();

async function bootstrap() {
  await refreshSession();
  bindEvents();
}

function bindEvents() {
  seedForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    setStatus("Generating candidate connections…");
    const formData = new FormData(seedForm);
    const payload = Object.fromEntries(formData.entries());
    state.session = await postJson("/api/session/start", payload);
    hydrateExportMetadata();
    render();
    setStatus("Choose the best connection and next song.");
  });

  exportForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    setStatus("Validating and exporting…");
    exportResult.classList.add("hidden");
    try {
      const formData = new FormData(exportForm);
      const payload = {
        metadata: {
          songTitle: formData.get("songTitle"),
          artistName: formData.get("artistName"),
          isrc: formData.get("isrc")
        },
        appendToHuntDraft: formData.get("appendToHuntDraft") === "on"
      };
      const result = await postJson("/api/export", payload);
      exportResult.textContent = JSON.stringify(result, null, 2);
      exportResult.classList.remove("hidden");
      setStatus("Export complete.");
      await refreshSession();
    } catch (error) {
      const details = error.payload?.validation || [error.message];
      exportResult.textContent = `Export failed:\n- ${details.join("\n- ")}`;
      exportResult.classList.remove("hidden");
      setStatus("Export failed. Fix the missing fields and try again.");
    }
  });

  manualCandidateForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    setStatus("Saving manual historical connection…");
    const formData = new FormData(manualCandidateForm);
    const payload = Object.fromEntries(formData.entries());
    state.session = await postJson("/api/candidates/manual", payload);
    hydrateExportMetadata();
    render();
    setStatus("Manual candidate selected. Review the authoring fields below.");
  });
}

async function refreshSession() {
  state.session = await fetchJson("/api/session");
  render();
}

function render() {
  renderSeed();
  renderCandidates();
  renderFields();
  renderExport();
}

function renderSeed() {
  const seed = state.session.seed;
  if (!seed) return;
  seedForm.querySelector('[name="currentSongTitle"]').value = seed.currentSongTitle || "";
  seedForm.querySelector('[name="currentArtistName"]').value = seed.currentArtistName || "";
  seedForm.querySelector('[name="themeNotes"]').value = seed.themeNotes || "";
  seedForm.querySelector('[name="avoidNotes"]').value = seed.avoidNotes || "";
}

function renderCandidates() {
  const candidates = state.session.candidateLinks || [];
  candidateList.innerHTML = "";
  candidatePanel.classList.toggle("hidden", !state.session.seed);
  const generation = state.session.candidateGeneration;
  candidateGenerationNote.innerHTML = generation?.message
    ? `${escapeHtml(generation.message)}`
    : "Review AI candidates or enter a historical connection manually.";

  for (const candidate of candidates) {
    const card = document.createElement("article");
    card.className = "candidate-card";
    card.innerHTML = `
      <p class="step">Candidate ${candidate.rank}</p>
      <h3>${escapeHtml(candidate.nextArtistName)} - ${escapeHtml(candidate.nextSongTitle)}</h3>
      <div class="candidate-meta">
        <span class="pill">${escapeHtml(candidate.connectionType)}</span>
        <span class="pill">${escapeHtml(candidate.confidence)} confidence</span>
      </div>
      <p><strong>Connection fact:</strong> ${escapeHtml(candidate.connectionFact || "")}</p>
      <p><strong>Why this works:</strong> ${escapeHtml(candidate.whyThisWorks || "")}</p>
      <p class="muted"><strong>Verify:</strong> ${escapeHtml(candidate.verificationNote || "")}</p>
      ${candidate.fallbackNotice ? `<p class="muted">${escapeHtml(candidate.fallbackNotice)}</p>` : ""}
    `;

    const button = document.createElement("button");
    button.className = state.session.selectedCandidate?.id === candidate.id ? "selected" : "primary";
    button.textContent = state.session.selectedCandidate?.id === candidate.id ? "Selected" : "Choose this link";
    button.type = "button";
    button.addEventListener("click", async () => {
      setStatus("Generating field options for the selected link…");
      state.session = await postJson("/api/candidates/select", { candidateId: candidate.id });
      hydrateExportMetadata();
      render();
      setStatus("Select AI options field by field, request more, or enter manually.");
    });

    card.appendChild(button);
    candidateList.appendChild(card);
  }
}

function renderFields() {
  const candidate = state.session.selectedCandidate;
  fieldsContainer.innerHTML = "";
  fieldsPanel.classList.toggle("hidden", !candidate);
  if (!candidate) return;

  summaryEl.innerHTML = `
    <strong>${escapeHtml(candidate.nextArtistName)} - ${escapeHtml(candidate.nextSongTitle)}</strong><br />
    <span class="muted">${escapeHtml(candidate.connectionType)} | ${escapeHtml(candidate.confidence)} confidence</span><br />
    <strong>Connection fact:</strong> ${escapeHtml(candidate.connectionFact || "")}<br />
    <strong>Why this works:</strong> ${escapeHtml(candidate.whyThisWorks || "")}<br />
    <span class="muted"><strong>Verify:</strong> ${escapeHtml(candidate.verificationNote || "")}</span>
  `;

  for (const [fieldKey, config] of Object.entries(fieldConfig)) {
    const fieldState = state.session.fieldState[fieldKey];
    if (!fieldState) continue;

    const fragment = fieldTemplate.content.cloneNode(true);
    const card = fragment.querySelector(".field-card");
    const title = fragment.querySelector("h3");
    const help = fragment.querySelector(".field-help");
    const options = fragment.querySelector(".options");
    const manual = fragment.querySelector(".manual");
    const moreButton = fragment.querySelector(".more-options");
    const manualButton = fragment.querySelector(".manual-toggle");

    title.textContent = config.label;
    help.textContent = config.help;

    fieldState.batches.forEach((batch, batchIndex) => {
      batch.options.forEach((option, optionIndex) => {
        const optionCard = document.createElement("article");
        optionCard.className = "option-card";
        const isSelected = fieldState.mode === "ai" &&
          fieldState.selected &&
          fieldState.selected.batchIndex === batchIndex &&
          fieldState.selected.optionIndex === optionIndex;

        const meta = document.createElement("div");
        meta.className = "option-meta";
        meta.innerHTML = `<span class="pill">Batch ${batchIndex + 1}</span><span class="pill">Option ${optionIndex + 1}</span>`;
        optionCard.appendChild(meta);

        const preview = document.createElement("div");
        preview.innerHTML = renderOptionPreview(option);
        optionCard.appendChild(preview);

        const chooseButton = document.createElement("button");
        chooseButton.type = "button";
        chooseButton.className = isSelected ? "selected" : "ghost";
        chooseButton.textContent = isSelected ? "Selected" : "Use this option";
        chooseButton.addEventListener("click", async () => {
          setStatus(`Saving ${config.label} selection…`);
          state.session = await postJson(`/api/fields/${fieldKey}/select`, { batchIndex, optionIndex });
          render();
          setStatus(`${config.label} updated.`);
        });
        optionCard.appendChild(chooseButton);
        options.appendChild(optionCard);
      });
    });

    moreButton.addEventListener("click", async () => {
      setStatus(`Generating another ${config.label} batch…`);
      state.session = await postJson(`/api/fields/${fieldKey}/more`, {});
      render();
      setStatus(`Added another ${config.label} batch.`);
    });

    manualButton.textContent = fieldState.mode === "manual" ? "Manual mode active" : "Enter manually";
    manualButton.addEventListener("click", async () => {
      if (fieldState.mode === "manual") {
        setStatus(`Choose an AI option card to switch ${config.label} back from manual mode.`);
        return;
      }
      await saveManualField(fieldKey, currentManualValue(fieldKey, fieldState));
    });

    if (fieldState.mode === "manual") {
      manual.classList.remove("hidden");
      manual.appendChild(buildManualEditor(fieldKey, fieldState));
    }

    card.dataset.fieldKey = fieldKey;
    fieldsContainer.appendChild(fragment);
  }
}

function renderExport() {
  const candidate = state.session.selectedCandidate;
  exportPanel.classList.toggle("hidden", !candidate);
}

function buildManualEditor(fieldKey, fieldState) {
  const wrapper = document.createElement("div");
  wrapper.className = "manual-row";

  if (fieldKey === "multipleChoiceOptions") {
    const values = Array.isArray(fieldState.manualValue) ? fieldState.manualValue : ["", "", "", ""];
    values.forEach((value, index) => {
      const input = document.createElement("input");
      input.value = value || "";
      input.placeholder = `Option ${index + 1}`;
      input.addEventListener("change", () => {
        values[index] = input.value;
      });
      wrapper.appendChild(input);
    });
    wrapper.appendChild(saveManualButton(fieldKey, () => values));
    return wrapper;
  }

  if (fieldKey === "correctAnswers" || fieldKey === "triviaItems") {
    const values = Array.isArray(fieldState.manualValue) ? [...fieldState.manualValue] : [""];
    const list = document.createElement("div");
    list.className = "manual-row";
    const renderRows = () => {
      list.innerHTML = "";
      values.forEach((value, index) => {
        const row = document.createElement("div");
        row.className = "manual-row";
        const input = document.createElement("input");
        input.value = value || "";
        input.placeholder = fieldKey === "correctAnswers" ? `Accepted answer ${index + 1}` : `Trivia item ${index + 1}`;
        input.addEventListener("change", () => {
          values[index] = input.value;
        });
        row.appendChild(input);
        list.appendChild(row);
      });
    };
    renderRows();
    const addButton = document.createElement("button");
    addButton.type = "button";
    addButton.className = "ghost";
    addButton.textContent = fieldKey === "correctAnswers" ? "Add answer" : "Add trivia";
    addButton.addEventListener("click", () => {
      values.push("");
      renderRows();
    });
    wrapper.appendChild(list);
    wrapper.appendChild(addButton);
    wrapper.appendChild(saveManualButton(fieldKey, () => values));
    return wrapper;
  }

  const textarea = document.createElement("textarea");
  textarea.rows = 4;
  textarea.value = typeof fieldState.manualValue === "string" ? fieldState.manualValue : "";
  wrapper.appendChild(textarea);
  wrapper.appendChild(saveManualButton(fieldKey, () => textarea.value));
  return wrapper;
}

function saveManualButton(fieldKey, getValue) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "primary";
  button.textContent = "Save manual value";
  button.addEventListener("click", async () => {
    await saveManualField(fieldKey, getValue());
  });
  return button;
}

async function saveManualField(fieldKey, value) {
  setStatus(`Saving manual ${fieldConfig[fieldKey].label}…`);
  state.session = await postJson(`/api/fields/${fieldKey}/manual`, { value });
  render();
  setStatus(`${fieldConfig[fieldKey].label} set to manual mode.`);
}

function currentManualValue(fieldKey, fieldState) {
  if (fieldKey === "multipleChoiceOptions") return ["", "", "", ""];
  if (fieldKey === "correctAnswers" || fieldKey === "triviaItems") return [""];
  return fieldState.manualValue || "";
}

function renderOptionPreview(option) {
  if (Array.isArray(option)) {
    return `<ul>${option.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>`;
  }
  return `<p>${escapeHtml(option)}</p>`;
}

function hydrateExportMetadata() {
  const candidate = state.session.selectedCandidate;
  if (!candidate) return;
  exportForm.querySelector('[name="songTitle"]').value = candidate.nextSongTitle || "";
  exportForm.querySelector('[name="artistName"]').value = candidate.nextArtistName || "";
}

function setStatus(message) {
  statusEl.textContent = message;
}

async function fetchJson(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Request failed with ${response.status}`);
  }
  return response.json();
}

async function postJson(url, payload) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });

  const data = await response.json();
  if (!response.ok) {
    const error = new Error(data.error || `Request failed with ${response.status}`);
    error.payload = data;
    throw error;
  }
  return data;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
