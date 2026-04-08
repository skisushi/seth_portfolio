"""
InferenceClient — abstraction for all LLM calls
Implements US 7.2.1 — InferenceClient module
Reference: docs/Veyant_Preference_Engine_Azure_Architecture.md, Section 7.1

Backend: Databricks Mosaic AI Model Serving (OpenAI-compatible REST API)
Why an abstraction: application code never imports a model SDK directly.
This is the ONLY file that touches the inference provider. To swap providers
(e.g., to Azure OpenAI or a self-hosted Llama on Azure ML), only this file changes.
"""

import json
import os
import re
from typing import Any, Optional

import httpx


class InferenceError(Exception):
    """Raised when inference fails or returns invalid output."""

    def __init__(self, message: str, raw_output: Optional[str] = None):
        super().__init__(message)
        self.raw_output = raw_output


class InferenceClient:
    """Async client for Databricks Mosaic AI Model Serving.

    Uses the OpenAI-compatible chat completions endpoint.
    Endpoint URL and access token are loaded from environment variables
    (sourced from Azure Key Vault via Managed Identity in production).
    """

    def __init__(
        self,
        endpoint_url: Optional[str] = None,
        access_token: Optional[str] = None,
        model: Optional[str] = None,
        timeout_seconds: float = 30.0,
    ):
        self.endpoint_url = endpoint_url or os.environ["DATABRICKS_INFERENCE_ENDPOINT"]
        self.access_token = access_token or os.environ["DATABRICKS_INFERENCE_TOKEN"]
        self.model = model or os.environ.get(
            "DATABRICKS_INFERENCE_MODEL",
            "databricks-meta-llama-3-70b-instruct",
        )
        self.timeout = timeout_seconds

    async def generate(
        self,
        prompt: str,
        response_schema: Optional[dict] = None,
        max_tokens: int = 1024,
        temperature: float = 0.2,
        system_prompt: Optional[str] = None,
    ) -> dict[str, Any]:
        """Call the model and return parsed JSON.

        Args:
            prompt: The user prompt
            response_schema: Optional JSON schema describing expected response shape
                (currently used for prompt augmentation, not strict validation)
            max_tokens: Output token cap
            temperature: Sampling temperature (0.2 default for extraction tasks)
            system_prompt: Optional system message to set behavior

        Returns:
            Parsed JSON dict from the model response

        Raises:
            InferenceError if the call fails or response can't be parsed as JSON
        """
        default_system = (
            "You are a data extraction assistant. You respond ONLY with valid JSON. "
            "Never add explanatory text before or after the JSON."
        )

        messages = [
            {"role": "system", "content": system_prompt or default_system},
            {"role": "user", "content": prompt},
        ]

        body = {
            "model": self.model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }

        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.post(
                    self.endpoint_url,
                    headers=headers,
                    json=body,
                )
                response.raise_for_status()
            except httpx.HTTPError as exc:
                raise InferenceError(
                    f"Inference request failed: {exc}"
                ) from exc

        result = response.json()
        try:
            content = result["choices"][0]["message"]["content"]
        except (KeyError, IndexError) as exc:
            raise InferenceError(
                f"Unexpected response shape from model serving: {result}"
            ) from exc

        return self._parse_json_response(content)

    @staticmethod
    def _parse_json_response(raw: str) -> dict[str, Any]:
        """Parse JSON from raw model output, with fallback for preamble.

        Llama 3 70B is generally well-behaved about JSON-only responses, but
        sometimes adds 'Sure! Here is...' preambles. This handles both cases.
        """
        # Fast path: clean JSON
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass

        # Fallback: extract JSON block via regex
        # Match the outermost { ... } block
        match = re.search(r"\{.*\}", raw, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError as exc:
                raise InferenceError(
                    f"Failed to parse extracted JSON block: {exc}",
                    raw_output=raw,
                ) from exc

        raise InferenceError(
            "No JSON object found in model response",
            raw_output=raw,
        )

    async def health_check(self) -> bool:
        """Verify the endpoint is reachable and the model is responding."""
        try:
            result = await self.generate(
                prompt='Respond with this exact JSON: {"status": "ok"}',
                max_tokens=20,
                temperature=0.0,
            )
            return result.get("status") == "ok"
        except InferenceError:
            return False
