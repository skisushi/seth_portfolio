FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy API code
COPY . .

# Default to external Ollama endpoint (set via env var in Container Apps)
# For local Ollama: OLLAMA_BASE_URL=http://localhost:11434
# For Container Apps sidecar: OLLAMA_BASE_URL=http://localhost:11434
# For Azure OpenAI swap: override InferenceClient endpoint in preference_extractor.py
ENV OLLAMA_BASE_URL=http://localhost:11434
ENV OLLAMA_MODEL=llama3:8b
ENV PORT=8000

EXPOSE 8000

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
