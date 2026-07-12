const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const ROOT = path.join(__dirname);
const PUBLIC_DIR = path.join(ROOT, "public");
const DATA_DIR = path.join(ROOT, "data");
const SESSION_PATH = path.join(DATA_DIR, "current-session.json");
const APPROVED_LINKS_PATH = path.join(DATA_DIR, "approved-links.json");
const HUNT_DRAFT_PATH = path.join(DATA_DIR, "hunt-draft.json");
const PORT = Number(process.env.CHAIN_LINK_WORKFLOW_PORT || 4783);

const FIELD_LIMITS = {
  clue: 300,
  hint1: 150,
  hint2: 150,
  answerText: 300,
  songStartInfo: 300,
  triviaItem: 200,
  maxTriviaItems: 10,
  mcOption: 50
};

const FIELD_KEYS = [
  "clue",
  "hint1",
  "hint2",
  "multipleChoiceOptions",
  "correctAnswers",
  "answerText",
  "songStartInfo",
  "triviaItems"
];

ensureDir(DATA_DIR);

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);

    if (url.pathname.startsWith("/api/")) {
      await handleApi(req, res, url);
      return;
    }

    serveStatic(req, res, url);
  } catch (error) {
    sendJson(res, error.validation ? 400 : 500, {
      error: error.message || "Unexpected server error",
      validation: error.validation || undefined
    });
  }
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`Chain link workflow running at http://localhost:${PORT}`);
});

async function handleApi(req, res, url) {
  if (req.method === "GET" && url.pathname === "/api/session") {
    sendJson(res, 200, getSession());
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/session/start") {
    const body = await parseJsonBody(req);
    const session = await createSession(body);
    persistSession(session);
    sendJson(res, 200, session);
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/candidates/select") {
    const body = await parseJsonBody(req);
    const session = getSession();
    const selectedCandidate = session.candidateLinks.find((candidate) => candidate.id === body.candidateId);
    if (!selectedCandidate) {
      sendJson(res, 400, { error: "Selected candidate was not found in the current session." });
      return;
    }

    session.selectedCandidate = selectedCandidate;
    session.fieldState = await generateFieldState(session);
    persistSession(session);
    sendJson(res, 200, session);
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/candidates/manual") {
    const body = await parseJsonBody(req);
    const session = getSession();
    const candidate = createManualCandidate(body);
    session.candidateLinks = [candidate, ...session.candidateLinks];
    session.selectedCandidate = candidate;
    session.fieldState = await generateFieldState(session);
    persistSession(session);
    sendJson(res, 200, session);
    return;
  }

  if (req.method === "POST" && url.pathname.startsWith("/api/fields/") && url.pathname.endsWith("/more")) {
    const fieldKey = url.pathname.split("/")[3];
    const session = getSession();
    assertFieldKey(fieldKey);
    assertCandidateSelected(session);
    const nextBatch = await generateFieldBatch(session, fieldKey, session.fieldState[fieldKey].batches.length);
    session.fieldState[fieldKey].batches.push(nextBatch);
    persistSession(session);
    sendJson(res, 200, session);
    return;
  }

  if (req.method === "POST" && url.pathname.startsWith("/api/fields/") && url.pathname.endsWith("/select")) {
    const fieldKey = url.pathname.split("/")[3];
    const body = await parseJsonBody(req);
    const session = getSession();
    assertFieldKey(fieldKey);
    const field = session.fieldState[fieldKey];
    if (!field) {
      sendJson(res, 400, { error: `Field ${fieldKey} is unavailable until a candidate is selected.` });
      return;
    }

    const batch = field.batches[body.batchIndex];
    if (!batch || !batch.options[body.optionIndex]) {
      sendJson(res, 400, { error: "Selected option is out of range." });
      return;
    }

    field.mode = "ai";
    field.selected = { batchIndex: body.batchIndex, optionIndex: body.optionIndex };
    persistSession(session);
    sendJson(res, 200, session);
    return;
  }

  if (req.method === "POST" && url.pathname.startsWith("/api/fields/") && url.pathname.endsWith("/manual")) {
    const fieldKey = url.pathname.split("/")[3];
    const body = await parseJsonBody(req);
    const session = getSession();
    assertFieldKey(fieldKey);
    const field = session.fieldState[fieldKey];
    if (!field) {
      sendJson(res, 400, { error: `Field ${fieldKey} is unavailable until a candidate is selected.` });
      return;
    }

    field.mode = "manual";
    field.manualValue = body.value;
    persistSession(session);
    sendJson(res, 200, session);
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/export") {
    const body = await parseJsonBody(req);
    const session = getSession();
    const exported = buildExportedLink(session, body.metadata || {});
    persistApprovedLink(exported, body.appendToHuntDraft === true);
    session.lastExport = {
      exportedAt: new Date().toISOString(),
      file: APPROVED_LINKS_PATH
    };
    persistSession(session);
    sendJson(res, 200, {
      exported,
      approvedLinksPath: APPROVED_LINKS_PATH,
      huntDraftPath: HUNT_DRAFT_PATH
    });
    return;
  }

  sendJson(res, 404, { error: "Route not found." });
}

function serveStatic(req, res, url) {
  const filePath = url.pathname === "/" ? path.join(PUBLIC_DIR, "index.html") : path.join(PUBLIC_DIR, url.pathname);
  const normalizedPath = path.normalize(filePath);

  if (!normalizedPath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.readFile(normalizedPath, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }

    res.writeHead(200, { "Content-Type": contentTypeFor(normalizedPath) });
    res.end(data);
  });
}

async function createSession(input) {
  const seed = {
    currentSongTitle: sanitizeText(input.currentSongTitle),
    currentArtistName: sanitizeText(input.currentArtistName),
    themeNotes: sanitizeText(input.themeNotes),
    avoidNotes: sanitizeText(input.avoidNotes)
  };

  if (!seed.currentSongTitle || !seed.currentArtistName) {
    throw new Error("Current song title and artist are required.");
  }

  const candidateResult = await generateCandidateLinks(seed);

  return {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    seed,
    candidateLinks: candidateResult.candidates,
    candidateGeneration: candidateResult.meta,
    selectedCandidate: null,
    fieldState: {},
    lastExport: null
  };
}

function getSession() {
  if (!fs.existsSync(SESSION_PATH)) {
    return {
      id: null,
      createdAt: null,
      seed: null,
      candidateLinks: [],
      candidateGeneration: null,
      selectedCandidate: null,
      fieldState: {},
      lastExport: null
    };
  }

  return JSON.parse(fs.readFileSync(SESSION_PATH, "utf8"));
}

function persistSession(session) {
  fs.writeFileSync(SESSION_PATH, JSON.stringify(session, null, 2));
}

function persistApprovedLink(link, appendToHuntDraft) {
  const approvedLinks = fs.existsSync(APPROVED_LINKS_PATH)
    ? JSON.parse(fs.readFileSync(APPROVED_LINKS_PATH, "utf8"))
    : [];
  approvedLinks.push(link);
  fs.writeFileSync(APPROVED_LINKS_PATH, JSON.stringify(approvedLinks, null, 2));

  if (appendToHuntDraft) {
    const draft = fs.existsSync(HUNT_DRAFT_PATH)
      ? JSON.parse(fs.readFileSync(HUNT_DRAFT_PATH, "utf8"))
      : createEmptyHuntDraft();
    draft.modifiedDate = new Date().toISOString();
    draft.links.push(link);
    fs.writeFileSync(HUNT_DRAFT_PATH, JSON.stringify(draft, null, 2));
  }
}

async function generateFieldState(session) {
  const fieldState = {};
  for (const fieldKey of FIELD_KEYS) {
    fieldState[fieldKey] = {
      mode: "ai",
      selected: null,
      manualValue: defaultManualValue(fieldKey),
      batches: [await generateFieldBatch(session, fieldKey, 0)]
    };
  }
  return fieldState;
}

async function generateFieldBatch(session, fieldKey, batchIndex) {
  const batch = await generateFieldOptions(session.seed, session.selectedCandidate, fieldKey, batchIndex);
  return {
    createdAt: new Date().toISOString(),
    batchIndex,
    options: batch
  };
}

async function generateFieldOptions(seed, candidate, fieldKey, batchIndex) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (apiKey) {
    try {
      return await generateFieldOptionsWithOpenAI(apiKey, seed, candidate, fieldKey, batchIndex);
    } catch (error) {
      console.warn(`OpenAI generation failed for ${fieldKey}; falling back to local templates. ${error.message}`);
    }
  }

  return generateFieldOptionsFallback(seed, candidate, fieldKey, batchIndex);
}

async function generateFieldOptionsWithOpenAI(apiKey, seed, candidate, fieldKey, batchIndex) {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL || "gpt-4.1-mini",
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text: [
                "You generate music treasure-hunt authoring options.",
                "Return strict JSON with a top-level key named options.",
                "Each response must contain exactly 5 options.",
                "Respect these field formats:",
                "- clue, hint1, hint2, answerText, songStartInfo: string",
                "- multipleChoiceOptions: array of 4 short strings",
                "- correctAnswers: array of accepted answer variants",
                "- triviaItems: array of 3 concise strings",
                "Avoid repeating phrasing across options.",
                "Keep options realistic and specific to the selected connection."
              ].join(" ")
            }
          ]
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: JSON.stringify({
                batchIndex,
                fieldKey,
                seed,
                candidate,
                limits: FIELD_LIMITS
              })
            }
          ]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "field_options",
          schema: {
            type: "object",
            additionalProperties: false,
            required: ["options"],
            properties: {
              options: optionSchemaFor(fieldKey)
            }
          }
        }
      }
    })
  });

  if (!response.ok) {
    throw new Error(`OpenAI API returned ${response.status}`);
  }

  const payload = await response.json();
  const content = payload.output?.[0]?.content?.find((entry) => entry.type === "output_text")?.text;
  if (!content) {
    throw new Error("OpenAI API returned no structured output.");
  }

  const parsed = JSON.parse(content);
  if (!Array.isArray(parsed.options) || parsed.options.length !== 5) {
    throw new Error("OpenAI output did not include exactly 5 options.");
  }

  return parsed.options;
}

function optionSchemaFor(fieldKey) {
  if (fieldKey === "multipleChoiceOptions") {
    return {
      type: "array",
      minItems: 5,
      maxItems: 5,
      items: {
        type: "array",
        minItems: 4,
        maxItems: 4,
        items: { type: "string" }
      }
    };
  }

  if (fieldKey === "correctAnswers" || fieldKey === "triviaItems") {
    return {
      type: "array",
      minItems: 5,
      maxItems: 5,
      items: {
        type: "array",
        minItems: 2,
        items: { type: "string" }
      }
    };
  }

  return {
    type: "array",
    minItems: 5,
    maxItems: 5,
    items: { type: "string" }
  };
}

async function generateCandidateLinks(seed) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (apiKey) {
    try {
      const candidates = await generateCandidateLinksWithOpenAI(apiKey, seed);
      return {
        candidates,
        meta: {
          mode: "ai",
          message: "AI-generated historical connection candidates are ready for review."
        }
      };
    } catch (error) {
      console.warn(`OpenAI candidate generation failed; falling back to local templates. ${error.message}`);
      return {
        candidates: [],
        meta: {
          mode: "manual_only",
          message: `AI candidate generation failed: ${error.message}. Enter a historical connection manually or retry after fixing the model configuration.`
        }
      };
    }
  }

  return {
    candidates: [],
    meta: {
      mode: "manual_only",
      message: "No OPENAI_API_KEY detected. Candidate discovery is disabled to avoid fake historical connections. Enter a connection manually or configure OpenAI."
    }
  };
}

async function generateCandidateLinksWithOpenAI(apiKey, seed) {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL || "gpt-4.1-mini",
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text: [
                "You generate candidate music chain links.",
                "The user is reviewing connections between the current artist and the next artist/song.",
                "Each candidate must be built around one specific trivia fact that links artist A to artist B.",
                "Do not return vague categories alone such as 'shared stage' or 'label mates'.",
                "For every candidate, provide:",
                "- nextArtistName",
                "- nextSongTitle",
                "- connectionFact: one concrete fact sentence connecting the current artist to the next artist",
                "- connectionType: short label like 'name-change', 'tour-support', 'sample', 'producer', 'cover', 'band-member'",
                "- whyThisWorks: why this fact makes a strong next-step link",
                "- verificationNote: short note describing what should be checked by a human reviewer",
                "- confidence: High, Medium, or Speculative",
                "Return exactly 8 candidates in strict JSON."
              ].join(" ")
            }
          ]
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: JSON.stringify({ seed })
            }
          ]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "candidate_links",
          schema: {
            type: "object",
            additionalProperties: false,
            required: ["candidates"],
            properties: {
              candidates: {
                type: "array",
                minItems: 8,
                maxItems: 8,
                items: {
                  type: "object",
                  additionalProperties: false,
                  required: [
                    "nextArtistName",
                    "nextSongTitle",
                    "connectionFact",
                    "connectionType",
                    "whyThisWorks",
                    "verificationNote",
                    "confidence"
                  ],
                  properties: {
                    nextArtistName: { type: "string" },
                    nextSongTitle: { type: "string" },
                    connectionFact: { type: "string" },
                    connectionType: { type: "string" },
                    whyThisWorks: { type: "string" },
                    verificationNote: { type: "string" },
                    confidence: { type: "string", enum: ["High", "Medium", "Speculative"] }
                  }
                }
              }
            }
          }
        }
      }
    })
  });

  if (!response.ok) {
    throw new Error(`OpenAI API returned ${response.status}`);
  }

  const payload = await response.json();
  const content = payload.output?.[0]?.content?.find((entry) => entry.type === "output_text")?.text;
  if (!content) {
    throw new Error("OpenAI API returned no structured output.");
  }

  const parsed = JSON.parse(content);
  if (!Array.isArray(parsed.candidates) || parsed.candidates.length !== 8) {
    throw new Error("Candidate output did not include exactly 8 candidates.");
  }

  return parsed.candidates.map((candidate, index) => ({
    id: crypto.randomUUID(),
    rank: index + 1,
    connectionType: sanitizeText(candidate.connectionType),
    nextArtistName: sanitizeText(candidate.nextArtistName),
    nextSongTitle: sanitizeText(candidate.nextSongTitle),
    connectionFact: sanitizeText(candidate.connectionFact),
    whyThisWorks: sanitizeText(candidate.whyThisWorks),
    verificationNote: sanitizeText(candidate.verificationNote),
    confidence: sanitizeText(candidate.confidence),
    fallbackNotice: null
  }));
}

function createManualCandidate(input) {
  const nextArtistName = sanitizeText(input.nextArtistName);
  const nextSongTitle = sanitizeText(input.nextSongTitle);
  const connectionFact = sanitizeText(input.connectionFact);
  const connectionType = sanitizeText(input.connectionType) || "manual";
  const whyThisWorks = sanitizeText(input.whyThisWorks) || "Entered manually by the reviewer.";
  const verificationNote = sanitizeText(input.verificationNote) || "Manual entry. Verify wording before export.";
  const confidence = sanitizeText(input.confidence) || "Manual";

  if (!nextArtistName || !nextSongTitle || !connectionFact) {
    throw new Error("Manual candidate entry requires next artist, next song, and a connection fact.");
  }

  return {
    id: crypto.randomUUID(),
    rank: 1,
    connectionType,
    nextArtistName,
    nextSongTitle,
    connectionFact,
    whyThisWorks,
    verificationNote,
    confidence,
    fallbackNotice: null
  };
}

function generateFieldOptionsFallback(seed, candidate, fieldKey, batchIndex) {
  const variants = Array.from({ length: 5 }, (_, index) => {
    const tone = toneFor(batchIndex, index);
    const bridge = bridgePhrase(candidate.connectionType, index);
    const fact = candidate.connectionFact;
    const song = candidate.nextSongTitle;
    const artist = candidate.nextArtistName;
    const currentArtist = seed.currentArtistName;

    if (fieldKey === "clue") {
      return truncate(
        `${tone} ${fact} Which artist does that fact point to, and which act takes the chain into "${song}"?`,
        FIELD_LIMITS.clue
      );
    }

    if (fieldKey === "hint1") {
      return truncate(
        `Focus on this fact: ${fact}`,
        FIELD_LIMITS.hint1
      );
    }

    if (fieldKey === "hint2") {
      return truncate(
        `The fact connects ${currentArtist} to ${artist}, and the selected next song is "${song}".`,
        FIELD_LIMITS.hint2
      );
    }

    if (fieldKey === "multipleChoiceOptions") {
      return uniqueTrimmed([
        artist,
        distractorArtist(artist, index),
        distractorArtist(artist, index + 1),
        distractorArtist(artist, index + 2)
      ]).slice(0, 4).map((item) => truncate(item, FIELD_LIMITS.mcOption));
    }

    if (fieldKey === "correctAnswers") {
      return uniqueTrimmed([
        artist,
        artist.toLowerCase(),
        normalizeAnswerVariant(artist),
        `The band ${artist}`,
        `${artist} band`
      ]).slice(0, 5);
    }

    if (fieldKey === "answerText") {
      return truncate(
        `${fact} That is why ${artist} is the right answer, and why "${song}" is the right musical landing point for the next step in the chain.`,
        FIELD_LIMITS.answerText
      );
    }

    if (fieldKey === "songStartInfo") {
      return truncate(
        `Now "${song}" begins. The chain has moved from ${currentArtist} to ${artist} through this fact: ${bridge}.`,
        FIELD_LIMITS.songStartInfo
      );
    }

    if (fieldKey === "triviaItems") {
      return [
        truncate(fact, FIELD_LIMITS.triviaItem),
        truncate(`"${song}" gives this hop a clear musical landing point instead of ending with the artist alone.`, FIELD_LIMITS.triviaItem),
        truncate(candidate.whyThisWorks || `Use this option if you want a clue that rewards factual recall more than broad genre familiarity.`, FIELD_LIMITS.triviaItem)
      ];
    }

    return "";
  });

  return variants;
}

function toneFor(batchIndex, index) {
  return [
    "Classic route.",
    "Story-driven route.",
    "Fact-first route.",
    "Player-friendly route.",
    "Slightly trickier route."
  ][(batchIndex + index) % 5];
}

function bridgePhrase(connectionType, index) {
  const phrases = {
    "name-change": [
      "a band name change",
      "an early identity swap",
      "a rebrand before fame",
      "a discarded original name",
      "a decision to avoid confusion"
    ],
    "shared-stage": [
      "a major live-event moment",
      "a famous concert crossover",
      "a shared performance context",
      "a landmark stage appearance",
      "a live-show turning point"
    ],
    "production-lineage": [
      "producer lineage",
      "a studio-side connection",
      "shared production DNA",
      "the hand behind the console",
      "recording-room continuity"
    ],
    "cover-version": [
      "a reinvention of an older song",
      "a cover that eclipsed expectations",
      "a borrowed composition turned signature hit",
      "a reworked original",
      "a famous reinterpretation"
    ],
    "sample-reference": [
      "a borrowed musical phrase",
      "a sample-led connection",
      "a reference embedded in a later hit",
      "a string-led reuse",
      "an echo of an earlier recording"
    ],
    "label-mates": [
      "life on the same label",
      "record-label proximity",
      "shared label history",
      "a catalogue-side connection",
      "the same corporate home"
    ],
    "session-musician": [
      "a key player behind the scenes",
      "session-musician overlap",
      "a guitarist-for-hire connection",
      "shared studio personnel",
      "a musician appearing on more than one story"
    ],
    "chart-rivalry": [
      "a chart rivalry",
      "a same-era chart battle",
      "pop competition at the top end",
      "a race for the singles chart",
      "commercial rivalry"
    ]
  };

  const list = phrases[connectionType] || ["a music-industry connection"];
  return list[index % list.length];
}

function distractorArtist(correctArtist, offset) {
  const pool = [
    "Thin Lizzy",
    "Wishbone Ash",
    "ELO",
    "T. Rex",
    "The Hollies",
    "The Kinks",
    "Roxy Music",
    "10cc",
    "Supertramp",
    "The Who"
  ].filter((artist) => artist !== correctArtist);
  return pool[offset % pool.length];
}

function defaultManualValue(fieldKey) {
  if (fieldKey === "multipleChoiceOptions") {
    return ["", "", "", ""];
  }
  if (fieldKey === "correctAnswers" || fieldKey === "triviaItems") {
    return [""];
  }
  return "";
}

function buildExportedLink(session, metadata) {
  assertCandidateSelected(session);
  const selectedCandidate = session.selectedCandidate;
  const values = {};

  for (const fieldKey of FIELD_KEYS) {
    const field = session.fieldState[fieldKey];
    if (!field) {
      throw new Error(`Field ${fieldKey} is missing.`);
    }

    values[fieldKey] = resolveFieldValue(field);
  }

  const exported = {
    id: crypto.randomUUID(),
    clue: sanitizeText(values.clue),
    hint1: sanitizeText(values.hint1),
    hint2: sanitizeText(values.hint2) || null,
    multipleChoiceOptions: normalizeStringArray(values.multipleChoiceOptions),
    correctAnswers: normalizeStringArray(values.correctAnswers),
    isrc: sanitizeText(metadata.isrc),
    songTitle: sanitizeText(metadata.songTitle) || selectedCandidate.nextSongTitle,
    artistName: sanitizeText(metadata.artistName) || selectedCandidate.nextArtistName,
    answerText: sanitizeText(values.answerText),
    songStartInfo: sanitizeText(values.songStartInfo),
    triviaItems: normalizeStringArray(values.triviaItems),
    albumArtData: null
  };

  const validation = validateLink(exported);
  if (validation.length > 0) {
    const error = new Error("Validation failed");
    error.validation = validation;
    throw error;
  }

  return exported;
}

function validateLink(link) {
  const issues = [];
  if (!link.clue) issues.push("Clue is required.");
  if (!link.hint1) issues.push("Hint 1 is required.");
  if (!link.isrc) issues.push("ISRC is required.");
  if (link.multipleChoiceOptions.length !== 4) issues.push("Exactly 4 multiple choice options are required.");
  if (link.multipleChoiceOptions.some((option) => !option)) issues.push("Multiple choice options cannot be empty.");
  if (link.correctAnswers.length === 0) issues.push("At least one correct answer is required.");
  if (!link.answerText) issues.push("Answer text is required.");
  if (!link.songStartInfo) issues.push("Song start info is required.");
  if (link.triviaItems.length === 0) issues.push("At least one trivia item is required.");
  if (link.triviaItems.length > FIELD_LIMITS.maxTriviaItems) issues.push("Too many trivia items.");
  if (link.clue.length > FIELD_LIMITS.clue) issues.push("Clue exceeds max length.");
  if (link.hint1.length > FIELD_LIMITS.hint1) issues.push("Hint 1 exceeds max length.");
  if (link.hint2 && link.hint2.length > FIELD_LIMITS.hint2) issues.push("Hint 2 exceeds max length.");
  if (link.multipleChoiceOptions.some((option) => option.length > FIELD_LIMITS.mcOption)) issues.push("A multiple choice option exceeds max length.");
  if (link.answerText.length > FIELD_LIMITS.answerText) issues.push("Answer text exceeds max length.");
  if (link.songStartInfo.length > FIELD_LIMITS.songStartInfo) issues.push("Song start info exceeds max length.");
  if (link.triviaItems.some((item) => item.length > FIELD_LIMITS.triviaItem)) issues.push("A trivia item exceeds max length.");
  return issues;
}

function resolveFieldValue(field) {
  if (field.mode === "manual") {
    return field.manualValue;
  }
  if (!field.selected) {
    throw new Error("Every field must have either an AI option selected or a manual value entered.");
  }
  return field.batches[field.selected.batchIndex].options[field.selected.optionIndex];
}

function createEmptyHuntDraft() {
  return {
    createdDate: new Date().toISOString(),
    modifiedDate: new Date().toISOString(),
    description: "Workflow-generated hunt draft",
    id: crypto.randomUUID(),
    links: [],
    loopbackClue: null,
    name: "Workflow Draft",
    version: "2.0"
  };
}

function assertFieldKey(fieldKey) {
  if (!FIELD_KEYS.includes(fieldKey)) {
    throw new Error(`Unknown field: ${fieldKey}`);
  }
}

function assertCandidateSelected(session) {
  if (!session.selectedCandidate) {
    throw new Error("Select a candidate link before generating or exporting field options.");
  }
}

function ensureDir(target) {
  if (!fs.existsSync(target)) {
    fs.mkdirSync(target, { recursive: true });
  }
}

function parseJsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      try {
        const raw = Buffer.concat(chunks).toString("utf8");
        resolve(raw ? JSON.parse(raw) : {});
      } catch (error) {
        reject(new Error("Request body must be valid JSON."));
      }
    });
    req.on("error", reject);
  });
}

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, { "Content-Type": "application/json" });
  res.end(JSON.stringify(payload, null, 2));
}

function contentTypeFor(filePath) {
  if (filePath.endsWith(".css")) return "text/css";
  if (filePath.endsWith(".js")) return "application/javascript";
  if (filePath.endsWith(".json")) return "application/json";
  return "text/html";
}

function sanitizeText(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return uniqueTrimmed(value);
}

function uniqueTrimmed(values) {
  const seen = new Set();
  const normalized = [];
  for (const value of values) {
    const trimmed = sanitizeText(String(value));
    if (!trimmed || seen.has(trimmed.toLowerCase())) {
      continue;
    }
    seen.add(trimmed.toLowerCase());
    normalized.push(trimmed);
  }
  return normalized;
}

function normalizeAnswerVariant(value) {
  return value.replace(/^The /i, "");
}

function truncate(value, limit) {
  return value.length <= limit ? value : `${value.slice(0, limit - 1)}…`;
}
