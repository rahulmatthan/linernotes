# Chain Link Workflow

Local web workflow for building one music chain link at a time.

## Run

```bash
npm run chain-link-workflow
```

Open `http://localhost:4783`.

## Notes

- The human review step is the candidate-selection step.
- Candidate links are meant to be explicit trivia facts connecting artist A to artist B.
- If no `OPENAI_API_KEY` is configured, the app will not invent candidates. You must enter the historical connection manually.
- Each downstream authoring field starts with 5 AI or fallback options.
- Every field supports `More options` and a manual fallback path.
- Exported files are written under `tools/chain-link-workflow/data/`.
- If `OPENAI_API_KEY` is set, the server will try OpenAI first and generate actual fact-based candidate links.
- Without `OPENAI_API_KEY`, the tool disables AI discovery and leaves candidate selection in manual mode.
