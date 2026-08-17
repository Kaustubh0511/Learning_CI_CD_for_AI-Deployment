from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from openai import OpenAI
from pydantic import BaseModel
import os
import datetime
import time

load_dotenv()

app = FastAPI(
    title="Simple AI App",
    description="API for CI/CD learning",
    version="1.0.0",
    contact={
        "name": "Kaustubh",
        "email": "kautubhdaymaai@gmail.com"
    },
    license_info={
        "name": "MIT License"
    },
)

# Config Setup
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY is not set in the environment")

GROQ_BASE_URL = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
client = OpenAI(base_url=GROQ_BASE_URL, api_key=GROQ_API_KEY)

# Models
DEFAULT_MODEL = "openai/gpt-oss-20b"
LLM_MODEL = os.getenv("LLM_MODEL", DEFAULT_MODEL)

# Prompts for model
prompt = """You are a helpful assitant that can answer questions and help with tasks"""


class ChatRequest(BaseModel):
    user_id: str
    message: str


class ChatResponse(BaseModel):
    reply: str
    latency_ms: float
    model: str
    prompt_tokens: int
    completion_tokens: int
    user_id: str


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model": LLM_MODEL,
        "timestamp": datetime.datetime.now(datetime.UTC).isoformat()
    }


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    print(f"Recieved request from user {request.user_id}:{request.message}")
    full_prompt = f"{prompt}\nUser: {request.message}\nAssistant:"
    start_time = time.time()
    try:
        response = client.chat.completions.create(
            model=LLM_MODEL,
            messages=[{"role": "user", "content": full_prompt}],
            temperature=0.7,
            max_completion_tokens=1000,
            timeout=30.0
        )
    except Exception as exc:
        print(f"Error processing request from user {request.user_id}:{str(exc)}")
        raise HTTPException(
            status_code=500,
            detail=f"LLM Request Failed, Internal Server Error : {str(exc)}"
        )

    latency_ms = (time.time() - start_time) * 1000
    reply = response.choices[0].message.content
    prompt_tokens = response.usage.prompt_tokens
    completion_tokens = response.usage.completion_tokens

    return ChatResponse(
        reply=reply,
        latency_ms=latency_ms,
        model=LLM_MODEL,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        user_id=request.user_id,
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000
    )
