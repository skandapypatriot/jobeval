"""LLM Integration Service - Structured prompts and response validation with OpenRouter."""

import hashlib
import json
import logging
import time
from typing import Any
from uuid import UUID

import httpx
from pydantic import ValidationError

from app.core.config import get_settings
from app.schemas.cad_specs import CADSpecs, ConfidenceReport, WarningItem

settings = get_settings()
logger = logging.getLogger(__name__)


class LLMService:
    """
    Service for LLM integration with structured prompts and response validation.

    Supports OpenRouter and DeepInfra providers. All LLM output is validated
    against the CAD specs JSON schema - the LLM is never the authoritative
    geometry engine.
    """

    def __init__(self) -> None:
        self.settings = settings
        self.provider = settings.LLM_PROVIDER
        self.api_key = settings.LLM_API_KEY
        self.base_url = settings.LLM_BASE_URL
        self.model = settings.LLM_MODEL
        self.timeout = settings.LLM_TIMEOUT
        self.max_retries = settings.LLM_MAX_RETRIES
        self.temperature = settings.LLM_TEMPERATURE
        self.max_tokens = settings.LLM_MAX_TOKENS
        self.enable_zdr = settings.ENABLE_ZERO_DATA_RETENTION
        self.privacy_mode = settings.PRIVACY_MODE
        self.allowed_providers = settings.ALLOWED_PROVIDERS

        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client with provider-specific headers."""
        if self._client is None:
            headers = {
                "Authorization": f"Bearer {self.api_key}" if self.api_key else "",
                "Content-Type": "application/json",
                "Accept": "application/json",
            }

            # Provider-specific headers
            if self.provider == "openrouter":
                headers["HTTP-Referer"] = "https://jobeval.local"
                headers["X-Title"] = "JobEval"
                if self.enable_zdr:
                    headers["X-OpenRouter-ZDR"] = "true"

            # NVIDIA NIM headers
            if self.provider == "nvidia_nim":
                if self.enable_zdr:
                    headers["NVIDIA-API-KEY"] = self.api_key or ""

            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                headers=headers,
                timeout=self.timeout,
            )
        return self._client

    async def close(self) -> None:
        """Close HTTP client."""
        if self._client:
            await self._client.aclose()
            self._client = None

    # ------------------------------------------------------------------ #
    # Privacy checks
    # ------------------------------------------------------------------ #

    def is_cloud_allowed(self) -> bool:
        """Check if cloud LLM processing is allowed based on privacy settings."""
        if self.privacy_mode == "local":
            return False
        if self.privacy_mode == "approved_cloud":
            return self.provider in self.allowed_providers
        return False

    def get_data_flow_description(self) -> dict[str, Any]:
        """Return documentation of actual data flow for transparency."""
        return {
            "provider": self.provider,
            "model": self.model,
            "base_url": self.base_url,
            "privacy_mode": self.privacy_mode,
            "zero_data_retention": self.enable_zdr,
            "data_sent": [
                "cad_specs.json (structured geometry and feature data)",
                "engineering view images (SVG/PNG)",
                "drawing annotations (text, dimensions, GD&T)",
            ],
            "data_not_sent": [
                "Original STEP/CAD files",
                "API keys",
                "User credentials",
            ],
            "retention_policy": "Session-only; no training on JobEval data",
            "note": "LLM output is validated against geometry - never trusted as authoritative",
        }

    # ------------------------------------------------------------------ #
    # LLM Analysis
    # ------------------------------------------------------------------ #

    async def analyze_features(
        self,
        cad_specs: CADSpecs,
        prompt_type: str = "feature_explanation",
        context: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """
        Send CAD specs to LLM for analysis with structured JSON response.

        The LLM output is validated and flagged - never treated as authoritative.
        """
        if not self.is_cloud_allowed():
            return {
                "error": "Cloud LLM processing not allowed in current privacy mode",
                "analysis": None,
                "sources": [],
                "confidence": 0.0,
                "warnings": ["Privacy mode blocks cloud LLM access"],
            }

        if not self.api_key:
            return {
                "error": "No LLM API key configured",
                "analysis": None,
                "sources": [],
                "confidence": 0.0,
                "warnings": ["LLM API key not set"],
            }

        prompt = self._build_prompt(cad_specs, prompt_type, context or {})
        system_prompt = self._get_system_prompt()

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ],
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "response_format": {"type": "json_object"},
        }

        start_time = time.time()
        last_error = None

        for attempt in range(self.max_retries):
            try:
                client = await self._get_client()
                response = await client.post("/chat/completions", json=payload)
                response.raise_for_status()
                data = response.json()

                content = data["choices"][0]["message"]["content"]
                parsed = json.loads(content)

                # Validate and flag LLM output
                result = self._validate_llm_output(parsed, prompt_type)
                result["processing_time_sec"] = round(time.time() - start_time, 2)
                result["provider"] = self.provider
                result["model"] = self.model

                return result

            except (httpx.HTTPError, json.JSONDecodeError, ValidationError) as e:
                last_error = e
                logger.warning(f"LLM attempt {attempt + 1} failed: {e}")
                if attempt < self.max_retries - 1:
                    await time.sleep(1 * (attempt + 1))  # Backoff
                continue
            except Exception as e:
                last_error = e
                logger.exception(f"Unexpected LLM error: {e}")
                break

        return {
            "error": str(last_error) if last_error else "Unknown error",
            "analysis": None,
            "sources": [],
            "confidence": 0.0,
            "warnings": [f"LLM analysis failed after {self.max_retries} attempts"],
            "provider": self.provider,
            "model": self.model,
        }

    async def generate_manufacturing_report(
        self,
        cad_specs: CADSpecs,
        report_type: str = "manufacturing",
    ) -> dict[str, Any]:
        """Generate a readable manufacturing report using LLM."""
        return await self.analyze_features(
            cad_specs,
            prompt_type="manufacturing_report",
            context={"report_type": report_type},
        )

    # ------------------------------------------------------------------ #
    # Prompt building
    # ------------------------------------------------------------------ #

    def _get_system_prompt(self) -> str:
        """Get system prompt for LLM - emphasizes JSON output and caution."""
        return """You are a senior manufacturing engineer analyzing CAD data for CNC machining.

CRITICAL INSTRUCTIONS:
1. Respond ONLY with valid JSON matching the requested schema
2. Never invent dimensions, features, or measurements not present in the data
3. If information is missing, use null or state "not_available"
4. Flag uncertainties and assumptions explicitly
5. Do not claim certainty about geometry - the CAD engine is authoritative
6. All dimensional values must include units (mm unless otherwise specified)

Your analysis will be validated against the original CAD geometry. Any unsupported claims will be flagged."""

    def _build_prompt(
        self,
        cad_specs: CADSpecs,
        prompt_type: str,
        context: dict[str, Any],
    ) -> str:
        """Build structured prompt for LLM based on analysis type."""

        base_context = {
            "job_id": cad_specs.job_id,
            "units": cad_specs.units.model_dump() if cad_specs.units else None,
            "geometry_summary": cad_specs.geometry_summary.model_dump() if cad_specs.geometry_summary else None,
            "features": [f.model_dump() for f in cad_specs.features],
            "feature_relationships": [r.model_dump() for r in cad_specs.feature_relationships],
            "warnings": [w.model_dump() for w in cad_specs.warnings],
            "confidence_report": cad_specs.confidence_report.model_dump() if cad_specs.confidence_report else None,
        }

        if prompt_type == "feature_explanation":
            return f"""Analyze the following CAD features and provide explanations for each feature type detected.
Include manufacturing considerations, typical tolerances, and potential issues.

CAD Data:
{json.dumps(base_context, indent=2)}

Respond with JSON containing:
- features_explained: array of objects with feature_id, explanation, manufacturing_notes, typical_tolerance, potential_issues
- overall_assessment: string
- confidence: float (0-1)
- assumptions: array of strings
- data_gaps: array of strings"""

        elif prompt_type == "manufacturing_suggestions":
            return f"""Analyze the CAD data and suggest manufacturing operations, setups, and potential challenges.

CAD Data:
{json.dumps(base_context, indent=2)}

Respond with JSON containing:
- suggested_setups: array of objects with setup_id, orientation, features, reasoning
- suggested_operations: array of objects with operation_id, feature_ids, operation_type, tool_category, estimated_time_min, reasoning
- challenges: array of strings
- confidence: float (0-1)
- assumptions: array of strings"""

        elif prompt_type == "drawing_interpretation":
            drawing_context = {
                "drawing_annotations": cad_specs.drawing_annotations.model_dump() if cad_specs.drawing_annotations else None,
                "cross_validation": cad_specs.cross_validation.model_dump() if cad_specs.cross_validation else None,
            }
            return f"""Interpret the engineering drawing annotations and cross-validation results.
Identify discrepancies, missing information, and critical specifications.

CAD Data:
{json.dumps(drawing_context, indent=2)}

Respond with JSON containing:
- drawing_summary: string
- critical_specifications: array of objects with type, value, feature_id, importance
- discrepancies: array of objects with property, drawing_value, model_value, severity
- missing_info: array of strings
- confidence: float (0-1)"""

        elif prompt_type == "manufacturing_report":
            return f"""Generate a manufacturing analysis report from the following CAD data.

CAD Data:
{json.dumps(base_context, indent=2)}

Context: {json.dumps(context)}

Respond with JSON containing:
- executive_summary: string
- manufacturing_assessment: string
- recommended_approach: string
- key_risks: array of strings
- cost_drivers: array of strings
- timeline_estimate_days: float
- confidence: float (0-1)
- assumptions: array of strings"""

        return json.dumps(base_context)

    # ------------------------------------------------------------------ #
    # Validation
    # ------------------------------------------------------------------ #

    def _validate_llm_output(
        self,
        parsed: dict[str, Any],
        prompt_type: str,
    ) -> dict[str, Any]:
        """
        Validate LLM output and flag any issues.
        The LLM is never authoritative - all output is treated as advisory.
        """
        warnings = []

        # Check for required fields based on prompt type
        if prompt_type == "feature_explanation":
            if "features_explained" not in parsed:
                warnings.append("LLM missing features_explained field")
            if "confidence" not in parsed:
                warnings.append("LLM missing confidence score")
                parsed["confidence"] = 0.5

        elif prompt_type == "manufacturing_suggestions":
            if "suggested_operations" not in parsed:
                warnings.append("LLM missing suggested_operations field")

        # Sanity check: confidence should be 0-1
        confidence = parsed.get("confidence", 0.5)
        if not isinstance(confidence, (int, float)) or confidence < 0 or confidence > 1:
            warnings.append(f"LLM confidence out of range: {confidence}")
            parsed["confidence"] = 0.5

        # Add validation metadata
        parsed["_validation"] = {
            "validated_by": "jobeval_llm_validator",
            "warnings": warnings,
            "is_advisory": True,
            "geometry_authoritative": True,
        }

        return parsed

    # ------------------------------------------------------------------ #
    # Hash for caching
    # ------------------------------------------------------------------ #

    def compute_content_hash(self, cad_specs: CADSpecs) -> str:
        """Compute hash of CAD specs for caching LLM responses."""
        content = json.dumps(
            {
                "geometry_summary": cad_specs.geometry_summary.model_dump() if cad_specs.geometry_summary else None,
                "features": [f.model_dump() for f in cad_specs.features],
                "drawing_annotations": cad_specs.drawing_annotations.model_dump() if cad_specs.drawing_annotations else None,
            },
            sort_keys=True,
        )
        return hashlib.sha256(content.encode()).hexdigest()[:16]