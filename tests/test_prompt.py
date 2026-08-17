from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app.main import LLM_MODEL, app, prompt

client = TestClient(app)


def _mock_completion(content="mocked reply"):
    response = MagicMock()
    response.choices = [MagicMock(message=MagicMock(content=content))]
    response.usage = MagicMock(prompt_tokens=10, completion_tokens=5)
    return response


@patch("app.main.client.chat.completions.create")
def test_system_prompt_is_included(mock_create):
    mock_create.return_value = _mock_completion()

    client.post("/chat", json={"user_id": "u1", "message": "Hello"})

    sent_content = mock_create.call_args.kwargs["messages"][0]["content"]
    assert prompt in sent_content


@patch("app.main.client.chat.completions.create")
def test_user_message_is_included(mock_create):
    mock_create.return_value = _mock_completion()

    client.post("/chat", json={"user_id": "u1", "message": "What is the capital of France?"})

    sent_content = mock_create.call_args.kwargs["messages"][0]["content"]
    assert "What is the capital of France?" in sent_content


@patch("app.main.client.chat.completions.create")
def test_prompt_ends_with_assistant_cue(mock_create):
    mock_create.return_value = _mock_completion()

    client.post("/chat", json={"user_id": "u1", "message": "Hi"})

    sent_content = mock_create.call_args.kwargs["messages"][0]["content"]
    assert sent_content.strip().endswith("Assistant:")


class TestPromptQuality:
    def test_prompt_exists(self):
        assert prompt
        assert isinstance(prompt, str)

    def test_prompt_reasonable(self):
        assert 10 <= len(prompt) <= 2000

    def test_prompt_no_secret(self):
        secret_markers = ["api_key", "sk-", "gsk_", "password", "secret"]
        lowered = prompt.lower()
        for marker in secret_markers:
            assert marker not in lowered

    def test_valid_model(self):
        assert LLM_MODEL
        assert isinstance(LLM_MODEL, str)
