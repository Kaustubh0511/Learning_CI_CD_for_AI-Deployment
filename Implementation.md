## Plan

> Create a simple AI app
    -> Create 2 end points health and chat in the app, to chat with the ai application.
> Setup environment -> digital ocean, github pipeline,
> deployment
> prompt test
> blue/green deployment

## Progress

### Done

- **Simple AI app** — FastAPI service (`app/main.py`) with:
  - `GET /health` — status, active model, timestamp
  - `POST /chat` — takes `{user_id, message}`, calls the LLM, returns `{reply, latency_ms, model, prompt_tokens, completion_tokens, user_id}`
  - Request validation (required fields, error handling around the LLM call, timeout, fail-fast on missing API key)
- **LLM provider** — settled on OpenAI (`gpt-4o-mini`) via the `openai` SDK, after trying local Ollama and Groq as swap-in alternatives (both worked, since Ollama/Groq expose OpenAI-compatible APIs — same client code, different `base_url`/key)
- **`requirements.txt`** — `fastapi`, `uvicorn`, `openai`, `pydantic`, `python-dotenv`
- **`.gitignore`** — excludes `.env`, `.venv/`, caches, build artifacts, editor/OS files
- **`README.md`** — setup, run, and endpoint docs
- Git repo initialized, work committed incrementally
- **DigitalOcean App Platform deployment** — app deployed to App Platform:
  - Linked GitHub repo to DigitalOcean
  - Created a new App Platform app
  - Set the build command and run command
  - Set `/health` as the health check path
  - Selected the server/instance size (computational power)
  - Enabled auto-deploy on push to GitHub

### Not started

- GitHub Actions pipeline (build/test/deploy workflow)
- Prompt testing (eval harness / test cases for `/chat` output quality)
- Blue/green deployment strategy

## Theory: Blue-Green Deployment

Keep two identical environments — **Blue** (live, serving traffic) and **Green** (idle, gets the new version). Deploy and test the new version on Green while Blue keeps serving users, then switch traffic to Green all at once (load balancer/router/DNS). Keep Blue up briefly as an instant rollback path; if Green is fine, Blue becomes the idle slot for the next release.

**Why:** zero-downtime releases, instant rollback (just switch traffic back), no mixed-version traffic during a deploy.

**Trade-offs:** doubles infra usage during the overlap, needs backward-compatible DB migrations (both environments often share one DB), and needs something upfront that can switch traffic atomically.

**Here:** App Platform's default deploy is rolling, not true blue-green. Real blue-green would need two Apps behind a DO Load Balancer, or a Droplet with your own reverse proxy — still open, see "Not started".

## Notes

- `.env` is git-ignored and currently holds `OPENAI_API_KEY` (empty, added manually) and `LLM_MODEL=gpt-4o-mini`.
