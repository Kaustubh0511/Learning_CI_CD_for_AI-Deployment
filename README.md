# Simple AI App

A minimal FastAPI service that wraps the OpenAI chat completions API, built as a learning project for CI/CD (GitHub Actions → DigitalOcean, blue/green deployment).

## Requirements

- Python 3.11+
- An OpenAI API key

## Setup

```bash
python -m venv .venv
.venv\Scripts\activate      # Windows
pip install -r requirements.txt
```

Create a `.env` file in the project root:

```
OPENAI_API_KEY=your-api-key-here
LLM_MODEL=gpt-4o-mini        # optional, defaults to gpt-4o-mini
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
  "model": "gpt-4o-mini",
  "prompt_tokens": 42,
  "completion_tokens": 63,
  "user_id": "abc123"
}
```

## Project structure

```
app/
  main.py       # FastAPI app, endpoints, OpenAI integration
requirements.txt
.env            # not committed — see .gitignore
```
