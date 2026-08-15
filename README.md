# Simple AI App

A minimal FastAPI service that wraps the Groq chat completions API, built as a learning project for CI/CD (GitHub Actions → DigitalOcean, blue/green deployment).

## Requirements

- Python 3.11+
- A [Groq API key](https://console.groq.com/keys)

## Setup

```bash
python -m venv .venv
.venv\Scripts\activate      # Windows
pip install -r requirements.txt
```

Create a `.env` file in the project root:

```
GROQ_API_KEY=your-api-key-here
LLM_MODEL=llama-3.1-8b-instant                  # optional, defaults to llama-3.1-8b-instant
GROQ_BASE_URL=https://api.groq.com/openai/v1    # optional, defaults to this
```

## Run

```bash
python -m app.main
```

or

```bash
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`.

## Endpoints

### `GET /health`

Returns service status, active model, and timestamp.

### `POST /chat`

Request:

```json
{
  "user_id": "abc123",
  "message": "What is FastAPI?"
}
```

Response:

```json
{
  "reply": "FastAPI is ...",
  "latency_ms": 812.4,
  "model": "llama-3.1-8b-instant",
  "prompt_tokens": 42,
  "completion_tokens": 63,
  "user_id": "abc123"
}
```

## Project structure

```
app/
  main.py       # FastAPI app, endpoints, Groq integration
requirements.txt
.env            # not committed — see .gitignore
```
