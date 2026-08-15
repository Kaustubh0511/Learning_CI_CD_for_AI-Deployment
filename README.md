# Simple AI App

A minimal FastAPI service that wraps a local Ollama model via its OpenAI-compatible API, built as a learning project for CI/CD (GitHub Actions → DigitalOcean, blue/green deployment).

## Requirements

- Python 3.11+
- [Ollama](https://ollama.com) installed and running locally, with a model pulled:

```bash
ollama pull llama3.2
```

## Setup

```bash
python -m venv .venv
.venv\Scripts\activate      # Windows
pip install -r requirements.txt
```

Create a `.env` file in the project root:

```
LLM_MODEL=llama3.2                              # optional, defaults to llama3.2
OLLAMA_BASE_URL=http://localhost:11434/v1       # optional, defaults to this
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
  "model": "llama3.2",
  "prompt_tokens": 42,
  "completion_tokens": 63,
  "user_id": "abc123"
}
```

## Project structure

```
app/
  main.py       # FastAPI app, endpoints, Ollama integration
requirements.txt
.env            # not committed — see .gitignore
```
