---
name: langextract
description: Extract structured information from unstructured text using LLMs with source grounding. Use when extracting entities from documents, medical notes, clinical reports, or any text requiring precise, traceable extraction. Supports Gemini, OpenAI, and local models (Ollama). Includes visualization and long document processing.
---

# LangExtract - Structured Information Extraction

Expert assistance for extracting structured, source-grounded information from unstructured text using large language models.

## When to Use This Skill

Use this skill when you need to:
- Extract structured entities from unstructured text (medical notes, reports, documents)
- Maintain precise source grounding (map extracted data to original text locations)
- Process long documents beyond LLM token limits
- Visualize extraction results with interactive HTML highlighting
- Extract clinical information from medical records
- Structure radiology or pathology reports
- Extract medications, diagnoses, or symptoms from clinical notes
- Analyze literary texts for characters, emotions, relationships
- Build domain-specific extraction pipelines
- Work with Gemini, OpenAI, or local models (Ollama)
- Generate schema-compliant outputs without fine-tuning

## Overview

**LangExtract** is a Python library by Google for extracting structured information from unstructured text using large language models. It emphasizes:

- **Source Grounding**: Every extraction maps to its exact location in source text
- **Structured Outputs**: Schema-compliant results with controlled generation
- **Long Document Processing**: Intelligent chunking and multi-pass extraction
- **Interactive Visualization**: Self-contained HTML for reviewing extractions in context
- **Flexible LLM Support**: Works with Gemini, OpenAI, and local models
- **Few-Shot Learning**: Requires only quality examples, no expensive fine-tuning

**Key Resources:**
- **GitHub**: https://github.com/google/langextract
- **Examples**: https://github.com/google/langextract/tree/main/examples
- **Documentation**: https://github.com/google/langextract/tree/main/docs/examples

## Installation

### Prerequisites

- Python 3.8 or higher
- API key for Gemini (AI Studio), OpenAI, or local Ollama setup

### Basic Installation

```bash
# Install from PyPI (recommended)
pip install langextract

# Install with OpenAI support
pip install langextract[openai]

# Install with development tools
pip install langextract[dev]
```

### Install from Source

```bash
git clone https://github.com/google/langextract.git
cd langextract
pip install -e .

# For development with testing
pip install -e ".[test]"
```

### Docker Installation

```bash
# Build Docker image
docker build -t langextract .

# Run with API key
docker run --rm \
  -e LANGEXTRACT_API_KEY="your-api-key" \
  langextract python your_script.py
```

### API Key Setup

**Gemini (Google AI Studio):**
```bash
export LANGEXTRACT_API_KEY="your-gemini-api-key"
```

Get keys from: https://ai.google.dev/

**OpenAI:**
```bash
export OPENAI_API_KEY="your-openai-api-key"
```

**Vertex AI (Enterprise):**
```bash
# Use service account authentication
# Set project in language_model_params
```

**.env File (Development):**
```bash
# Create .env file
echo "LANGEXTRACT_API_KEY=your-key-here" > .env
```

## Quick Start

### Basic Extraction Example

```python
import langextract as lx
import textwrap

# 1. Define extraction task
prompt = textwrap.dedent("""\
    Extract all medications mentioned in the clinical note.
    Include medication name, dosage, and frequency.
    Use exact text from the document.""")

# 2. Provide examples (few-shot learning)
examples = [
    lx.data.ExampleData(
        text="Patient prescribed Lisinopril 10mg daily for hypertension.",
        extractions=[
            lx.data.Extraction(
                extraction_class="medication",
                extraction_text="Lisinopril 10mg daily",
                attributes={
                    "name": "Lisinopril",
                    "dosage": "10mg",
                    "frequency": "daily",
                    "indication": "hypertension"
                }
            )
        ]
    )
]

# 3. Input text to extract from
input_text = """
Patient continues on Metformin 500mg twice daily for diabetes management.
Started on Amlodipine 5mg once daily for blood pressure control.
Discontinued Aspirin 81mg due to side effects.
"""

# 4. Run extraction
result = lx.extract(
    text_or_documents=input_text,
    prompt_description=prompt,
    examples=examples,
    model_id="gemini-2.0-flash-exp"
)

# 5. Access results
for extraction in result.extractions:
    print(f"Medication: {extraction.extraction_text}")
    print(f"  Name: {extraction.attributes.get('name')}")
    print(f"  Dosage: {extraction.attributes.get('dosage')}")
    print(f"  Frequency: {extraction.attributes.get('frequency')}")
    print(f"  Location: {extraction.start_char}-{extraction.end_char}")
    print()

# 6. Save and visualize
lx.io.save_annotated_documents(
    [result],
    output_name="medications.jsonl",
    output_dir="."
)

html_content = lx.visualize("medications.jsonl")
with open("medications.html", "w") as f:
    f.write(html_content)
```

### Literary Text Example

```python
import langextract as lx

prompt = """Extract characters, emotions, and relationships in order of appearance.
Use exact text for extractions. Do not paraphrase or overlap entities."""

examples = [
    lx.data.ExampleData(
        text="ROMEO entered the garden, filled with wonder at JULIET's beauty.",
        extractions=[
            lx.data.Extraction(
                extraction_class="character",
                extraction_text="ROMEO",
                attributes={"emotional_state": "wonder"}
            ),
            lx.data.Extraction(
                extraction_class="character",
                extraction_text="JULIET",
                attributes={}
            ),
            lx.data.Extraction(
                extraction_class="relationship",
                extraction_text="ROMEO ... JULIET's beauty",
                attributes={
                    "subject": "ROMEO",
                    "relation": "admires",
                    "object": "JULIET"
                }
            )
        ]
    )
]

text = """Act 2, Scene 2: The Capulet's orchard.
ROMEO appears beneath JULIET's balcony, gazing upward with longing.
JULIET steps onto the balcony, unaware of ROMEO's presence below."""

result = lx.extract(
    text_or_documents=text,
    prompt_description=prompt,
    examples=examples,
    model_id="gemini-2.0-flash-exp"
)
```

## Core Concepts

### 1. Extraction Classes

Define categories of entities to extract:

```python
# Single class
extraction_class="medication"

# Multiple classes via examples
examples = [
    lx.data.ExampleData(
        text="...",
        extractions=[
            lx.data.Extraction(extraction_class="diagnosis", ...),
            lx.data.Extraction(extraction_class="symptom", ...),
            lx.data.Extraction(extraction_class="medication", ...)
        ]
    )
]
```

### 2. Source Grounding

Every extraction includes precise text location:

```python
extraction = result.extractions[0]
print(f"Text: {extraction.extraction_text}")
print(f"Start: {extraction.start_char}")
print(f"End: {extraction.end_char}")

# Extract from original document
original_text = input_text[extraction.start_char:extraction.end_char]
```

### 3. Attributes

Add structured metadata to extractions:

```python
lx.data.Extraction(
    extraction_class="medication",
    extraction_text="Lisinopril 10mg daily",
    attributes={
        "name": "Lisinopril",
        "dosage": "10mg",
        "frequency": "daily",
        "route": "oral",
        "indication": "hypertension"
    }
)
```

### 4. Few-Shot Learning

Provide 1-5 quality examples instead of fine-tuning:

```python
# Minimal examples (1-2) for simple tasks
examples = [example1]

# More examples (3-5) for complex schemas
examples = [example1, example2, example3, example4, example5]
```

### 5. Long Document Processing

Automatic chunking for documents beyond token limits:

```python
result = lx.extract(
    text_or_documents=long_document,  # Any length
    prompt_description=prompt,
    examples=examples,
    model_id="gemini-2.0-flash-exp",
    extraction_passes=3,  # Multiple passes for better recall
    max_workers=20,        # Parallel processing
    max_char_buffer=1000   # Chunk overlap for continuity
)
```

## Configuration

### Model Selection

```python
# Gemini models (recommended)
model_id="gemini-2.0-flash-exp"       # Fast, cost-effective
model_id="gemini-2.0-flash-thinking-exp"  # Complex reasoning
model_id="gemini-1.5-pro"             # Legacy

# OpenAI models
model_id="gpt-4o"                     # GPT-4 Optimized
model_id="gpt-4o-mini"                # Smaller, faster

# Local models via Ollama
model_id="gemma2:2b"                  # Local inference
model_url="http://localhost:11434"
```

### Scaling Parameters

```python
result = lx.extract(
    text_or_documents=documents,
    prompt_description=prompt,
    examples=examples,

    # Multi-pass extraction for better recall
    extraction_passes=3,

    # Parallel processing
    max_workers=20,

    # Chunk size tuning
    max_char_buffer=1000,

    # Model configuration
    model_id="gemini-2.0-flash-exp"
)
```

### Backend Configuration

**Vertex AI:**
```python
result = lx.extract(
    text_or_documents=text,
    prompt_description=prompt,
    examples=examples,
    model_id="gemini-2.0-flash-exp",
    language_model_params={
        "vertexai": True,
        "project": "your-gcp-project-id",
        "location": "us-central1"
    }
)
```

**Batch Processing:**
```python
language_model_params={
    "batch": {
        "enabled": True
    }
}
```

**OpenAI Configuration:**
```python
result = lx.extract(
    text_or_documents=text,
    prompt_description=prompt,
    examples=examples,
    model_id="gpt-4o",
    fence_output=True,  # Required for OpenAI
    use_schema_constraints=False  # Disable Gemini-specific features
)
```

**Local Ollama:**
```python
result = lx.extract(
    text_or_documents=text,
    prompt_description=prompt,
    examples=examples,
    model_id="gemma2:2b",
    model_url="http://localhost:11434",
    use_schema_constraints=False
)
```

### Environment Variables

```bash
# API Keys
LANGEXTRACT_API_KEY="gemini-api-key"
OPENAI_API_KEY="openai-api-key"

# Vertex AI
GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"

# Model configuration
LANGEXTRACT_MODEL_ID="gemini-2.0-flash-exp"
LANGEXTRACT_MODEL_URL="http://localhost:11434"
```

## Common Patterns

### Pattern 1: Clinical Note Extraction

```python
import langextract as lx

prompt = """Extract diagnoses, symptoms, and medications from clinical notes.
Include ICD-10 codes when available. Use exact medical terminology."""

examples = [
    lx.data.ExampleData(
        text="Patient presents with Type 2 Diabetes Mellitus (E11.9). Started on Metformin 500mg BID. Reports fatigue and increased thirst.",
        extractions=[
            lx.data.Extraction(
                extraction_class="diagnosis",
                extraction_text="Type 2 Diabetes Mellitus (E11.9)",
                attributes={"condition": "Type 2 Diabetes Mellitus", "icd10": "E11.9"}
            ),
            lx.data.Extraction(
                extraction_class="medication",
                extraction_text="Metformin 500mg BID",
                attributes={"name": "Metformin", "dosage": "500mg", "frequency": "BID"}
            ),
            lx.data.Extraction(
                extraction_class="symptom",
                extraction_text="fatigue",
                attributes={"symptom": "fatigue"}
            ),
            lx.data.Extraction(
                extraction_class="symptom",
                extraction_text="increased thirst",
                attributes={"symptom": "polydipsia"}
            )
        ]
    )
]

# Process multiple clinical notes
clinical_notes = [
    "Note 1: Patient presents with...",
    "Note 2: Follow-up visit for...",
    "Note 3: New onset chest pain..."
]

results = lx.extract(
    text_or_documents=clinical_notes,
    prompt_description=prompt,
    examples=examples,
    model_id="gemini-2.0-flash-exp",
    extraction_passes=2,
    max_workers=10
)

# Save structured output
lx.io.save_annotated_documents(
    results,
    output_name="clinical_extractions.jsonl",
    output_dir="./output"
)
```

### Pattern 2: Radiology Report Structuring

```python
prompt = """Extract findings, impressions, and recommendations from radiology reports.
Include anatomical location, abnormality type, and severity."""

examples = [
    lx.data.ExampleData(
        text="FINDINGS: 3.2cm mass in right upper lobe. IMPRESSION: Suspicious for malignancy. RECOMMENDATION: Biopsy recommended.",
        extractions=[
            lx.data.Extraction(
                extraction_class="finding",
                extraction_text="3.2cm mass in right upper lobe",
                attributes={
                    "location": "right upper lobe",
                    "type": "mass",
                    "size": "3.2cm"
                }
            ),
            lx.data.Extraction(
                extraction_class="impression",
                extraction_text="Suspicious for malignancy",
                attributes={"diagnosis": "possible malignancy", "certainty": "suspicious"}
            ),
            lx.data.Extraction(
                extraction_class="recommendation",
                extraction_text="Biopsy recommended",
                attributes={"action": "biopsy"}
            )
        ]
    )
]
```

### Pattern 3: Multi-Document Processing

```python
import langextract as lx
from pathlib import Path

# Load multiple documents
documents = []
for file_path in Path("./documents").glob("*.txt"):
    with open(file_path, "r") as f:
        documents.append(f.read())

# Extract from all documents
results = lx.extract(
    text_or_documents=documents,
    prompt_description=prompt,
    examples=examples,
    model_id="gemini-2.0-flash-exp",
    extraction_passes=3,
    max_workers=20
)

# Results is a list of AnnotatedDocument objects
for i, result in enumerate(results):
    print(f"\nDocument {i+1}: {len(result.extractions)} extractions")
    for extraction in result.extractions:
        print(f"  - {extraction.extraction_class}: {extraction.extraction_text}")
```

### Pattern 4: Interactive Visualization

```python
# Generate interactive HTML
html_content = lx.visualize("extractions.jsonl")

# Save to file
with open("interactive_results.html", "w") as f:
    f.write(html_content)

# Open in browser (optional)
import webbrowser
webbrowser.open("interactive_results.html")
```

### Pattern 5: Custom Provider Plugin

```python
# See examples/custom_provider_plugin/ for full implementation
from langextract.providers import ProviderPlugin

class CustomProvider(ProviderPlugin):
    def extract(self, text, prompt, examples, **kwargs):
        # Custom extraction logic
        return extractions

    def supports_schema_constraints(self):
        return False

# Register custom provider
lx.register_provider("custom", CustomProvider())

# Use custom provider
result = lx.extract(
    text_or_documents=text,
    prompt_description=prompt,
    examples=examples,
    model_id="custom",
    provider="custom"
)
```

## API Reference

### Core Functions

#### `lx.extract()`

Main extraction function.

```python
result = lx.extract(
    text_or_documents,           # str or list of str
    prompt_description,          # str: extraction instructions
    examples,                    # list of ExampleData
    model_id="gemini-2.0-flash-exp",  # str: model identifier
    extraction_passes=1,         # int: number of passes
    max_workers=None,            # int: parallel workers
    max_char_buffer=1000,        # int: chunk overlap
    language_model_params=None,  # dict: model config
    fence_output=False,          # bool: required for OpenAI
    use_schema_constraints=True, # bool: use schema enforcement
    model_url=None,              # str: custom model endpoint
    api_key=None                 # str: API key (prefer env var)
)
```

**Returns**: `AnnotatedDocument` or `list[AnnotatedDocument]`

#### `lx.visualize()`

Generate interactive HTML visualization.

```python
html_content = lx.visualize(
    jsonl_file_path,           # str: path to JSONL file
    title="Extraction Results", # str: HTML page title
    show_attributes=True       # bool: display attributes
)
```

**Returns**: `str` (HTML content)

#### `lx.io.save_annotated_documents()`

Save results to JSONL format.

```python
lx.io.save_annotated_documents(
    annotated_documents,  # list of AnnotatedDocument
    output_name,          # str: filename (e.g., "results.jsonl")
    output_dir="."        # str: output directory
)
```

### Data Classes

#### `ExampleData`

Few-shot example definition.

```python
example = lx.data.ExampleData(
    text="Example text here",
    extractions=[
        lx.data.Extraction(...)
    ]
)
```

#### `Extraction`

Single extraction definition.

```python
extraction = lx.data.Extraction(
    extraction_class="medication",  # str: entity type
    extraction_text="Aspirin 81mg",  # str: exact text
    attributes={                     # dict: metadata
        "name": "Aspirin",
        "dosage": "81mg"
    },
    start_char=0,                    # int: start position (auto-set)
    end_char=13                      # int: end position (auto-set)
)
```

#### `AnnotatedDocument`

Extraction results for a document.

```python
result.text                  # str: original text
result.extractions          # list of Extraction
result.metadata             # dict: additional info
```

## Best Practices

### Extraction Design

1. **Write Clear Prompts**: Be specific about what to extract and how
   ```python
   # Good
   prompt = "Extract medications with dosage, frequency, and route of administration. Use exact medical terminology."

   # Avoid
   prompt = "Extract medications."
   ```

2. **Provide Quality Examples**: 1-5 well-crafted examples beat many poor ones
   ```python
   # Include edge cases in examples
   examples = [
       normal_case_example,
       edge_case_example,
       complex_case_example
   ]
   ```

3. **Use Exact Text**: Extract verbatim from source for accurate grounding
   ```python
   # Good
   extraction_text="Lisinopril 10mg daily"

   # Avoid paraphrasing
   extraction_text="10mg lisinopril taken once per day"
   ```

4. **Define Attributes Clearly**: Structure metadata consistently
   ```python
   attributes={
       "name": "Lisinopril",        # Drug name
       "dosage": "10mg",             # Amount
       "frequency": "daily",         # How often
       "route": "oral"               # How taken
   }
   ```

### Performance Optimization

1. **Multi-Pass for Long Documents**: Improves recall
   ```python
   extraction_passes=3  # 2-3 passes recommended for thorough extraction
   ```

2. **Parallel Processing**: Speed up batch operations
   ```python
   max_workers=20  # Adjust based on API rate limits
   ```

3. **Chunk Size Tuning**: Balance accuracy and context
   ```python
   max_char_buffer=1000  # Larger for context, smaller for speed
   ```

4. **Model Selection**: Choose based on task complexity
   ```python
   # Simple extraction
   model_id="gemini-2.0-flash-exp"

   # Complex reasoning
   model_id="gemini-2.0-flash-thinking-exp"
   ```

### Production Deployment

1. **API Key Security**: Never hardcode keys
   ```python
   # Good: Use environment variables
   import os
   api_key = os.getenv("LANGEXTRACT_API_KEY")

   # Avoid: Hardcoding
   api_key = "AIza..."  # Never do this
   ```

2. **Error Handling**: Handle API failures gracefully
   ```python
   try:
       result = lx.extract(...)
   except Exception as e:
       logger.error(f"Extraction failed: {e}")
       # Implement retry logic or fallback
   ```

3. **Cost Management**: Monitor API usage
   ```python
   # Use cheaper models for bulk processing
   model_id="gemini-2.0-flash-exp"  # vs "gemini-1.5-pro"

   # Batch processing for cost efficiency
   language_model_params={"batch": {"enabled": True}}
   ```

4. **Validation**: Verify extraction quality
   ```python
   for extraction in result.extractions:
       # Validate extraction is within document bounds
       assert 0 <= extraction.start_char < len(result.text)
       assert extraction.end_char <= len(result.text)

       # Verify text matches
       extracted = result.text[extraction.start_char:extraction.end_char]
       assert extracted == extraction.extraction_text
   ```

### Common Pitfalls

1. **Overlapping Extractions**
   - **Issue**: Extractions overlap or duplicate
   - **Solution**: Specify in prompt "Do not overlap entities"

2. **Paraphrasing Instead of Exact Text**
   - **Issue**: Extracted text doesn't match original
   - **Solution**: Prompt "Use exact text from document. Do not paraphrase."

3. **Insufficient Examples**
   - **Issue**: Poor extraction quality
   - **Solution**: Provide 3-5 diverse examples covering edge cases

4. **Model Limitations**
   - **Issue**: Schema constraints not supported on all models
   - **Solution**: Set `use_schema_constraints=False` for OpenAI/Ollama

## Troubleshooting

### Common Issues

#### Issue 1: API Authentication Failed

**Symptoms:**
- `AuthenticationError: Invalid API key`
- `Permission denied` errors

**Solution:**
```bash
# Verify API key is set
echo $LANGEXTRACT_API_KEY

# Set API key
export LANGEXTRACT_API_KEY="your-key-here"

# For OpenAI
export OPENAI_API_KEY="your-openai-key"

# Verify key works
python -c "import os; print(os.getenv('LANGEXTRACT_API_KEY'))"
```

#### Issue 2: Schema Constraints Error

**Symptoms:**
- `Schema constraints not supported` error
- Malformed output with OpenAI or Ollama

**Solution:**
```python
# Disable schema constraints for non-Gemini models
result = lx.extract(
    text_or_documents=text,
    prompt_description=prompt,
    examples=examples,
    model_id="gpt-4o",
    use_schema_constraints=False,  # Disable for OpenAI
    fence_output=True               # Enable for OpenAI
)
```

#### Issue 3: Token Limit Exceeded

**Symptoms:**
- `Token limit exceeded` error
- Truncated results

**Solution:**
```python
# Use multi-pass extraction
result = lx.extract(
    text_or_documents=long_text,
    prompt_description=prompt,
    examples=examples,
    extraction_passes=3,      # Multiple passes
    max_char_buffer=1000,     # Adjust chunk size
    max_workers=10            # Parallel processing
)
```

#### Issue 4: Poor Extraction Quality

**Symptoms:**
- Missing entities
- Incorrect extractions
- Paraphrased text

**Solution:**
```python
# Improve prompt specificity
prompt = """Extract medications with exact dosage and frequency.
Use exact text from document. Do not paraphrase.
Include generic and brand names.
Extract discontinued medications as well."""

# Add more diverse examples
examples = [
    normal_case,
    edge_case_1,
    edge_case_2,
    complex_case
]

# Increase extraction passes
extraction_passes=3

# Try more capable model
model_id="gemini-2.0-flash-thinking-exp"
```

#### Issue 5: Ollama Connection Failed

**Symptoms:**
- `Connection refused` to localhost:11434
- Ollama model not found

**Solution:**
```bash
# Start Ollama server
ollama serve

# Pull required model
ollama pull gemma2:2b

# Verify Ollama is running
curl http://localhost:11434/api/tags

# Use in langextract
python -c "
import langextract as lx
result = lx.extract(
    text_or_documents='test',
    prompt_description='Extract entities',
    examples=[],
    model_id='gemma2:2b',
    model_url='http://localhost:11434',
    use_schema_constraints=False
)
"
```

### Debugging Tips

1. **Enable Verbose Logging**
   ```python
   import logging
   logging.basicConfig(level=logging.DEBUG)
   ```

2. **Inspect Intermediate Results**
   ```python
   # Save each pass separately
   for i, result in enumerate(results):
       lx.io.save_annotated_documents(
           [result],
           output_name=f"pass_{i}.jsonl",
           output_dir="./debug"
       )
   ```

3. **Validate Examples**
   ```python
   # Check examples match expected format
   for example in examples:
       for extraction in example.extractions:
           # Verify text is in example text
           assert extraction.extraction_text in example.text
           print(f"✓ {extraction.extraction_class}: {extraction.extraction_text}")
   ```

4. **Test with Simple Input First**
   ```python
   # Start with minimal test
   test_result = lx.extract(
       text_or_documents="Patient on Aspirin 81mg daily.",
       prompt_description="Extract medications.",
       examples=[simple_example],
       model_id="gemini-2.0-flash-exp"
   )
   print(f"Extractions: {len(test_result.extractions)}")
   ```

## Advanced Topics

### Custom Extraction Schemas

Define complex nested structures:

```python
examples = [
    lx.data.ExampleData(
        text="Patient presents with chest pain. ECG shows ST elevation. Diagnosed with STEMI.",
        extractions=[
            lx.data.Extraction(
                extraction_class="clinical_event",
                extraction_text="Patient presents with chest pain. ECG shows ST elevation. Diagnosed with STEMI.",
                attributes={
                    "symptom": "chest pain",
                    "diagnostic_test": "ECG",
                    "finding": "ST elevation",
                    "diagnosis": "STEMI",
                    "severity": "severe",
                    "timeline": [
                        {"event": "symptom_onset", "description": "chest pain"},
                        {"event": "diagnostic", "description": "ECG shows ST elevation"},
                        {"event": "diagnosis", "description": "STEMI"}
                    ]
                }
            )
        ]
    )
]
```

### Batch Processing with Progress Tracking

```python
from tqdm import tqdm
import langextract as lx

documents = load_documents()  # List of documents
results = []

for i, doc in enumerate(tqdm(documents)):
    try:
        result = lx.extract(
            text_or_documents=doc,
            prompt_description=prompt,
            examples=examples,
            model_id="gemini-2.0-flash-exp"
        )
        results.append(result)

        # Save incrementally
        if (i + 1) % 100 == 0:
            lx.io.save_annotated_documents(
                results,
                output_name=f"batch_{i+1}.jsonl",
                output_dir="./batches"
            )
            results = []  # Clear for next batch
    except Exception as e:
        print(f"Failed on document {i}: {e}")
        continue
```

### Integration with Data Pipelines

```python
import langextract as lx
import pandas as pd

# Load data
df = pd.read_csv("clinical_notes.csv")

# Extract from each note
extractions_data = []

for idx, row in df.iterrows():
    result = lx.extract(
        text_or_documents=row['note_text'],
        prompt_description=prompt,
        examples=examples,
        model_id="gemini-2.0-flash-exp"
    )

    for extraction in result.extractions:
        extractions_data.append({
            'patient_id': row['patient_id'],
            'note_date': row['note_date'],
            'extraction_class': extraction.extraction_class,
            'extraction_text': extraction.extraction_text,
            **extraction.attributes
        })

# Create structured DataFrame
extractions_df = pd.DataFrame(extractions_data)
extractions_df.to_csv("structured_extractions.csv", index=False)
```

### Performance Benchmarking

```python
import time
import langextract as lx

def benchmark_extraction(documents, model_id, passes=1):
    start = time.time()

    results = lx.extract(
        text_or_documents=documents,
        prompt_description=prompt,
        examples=examples,
        model_id=model_id,
        extraction_passes=passes,
        max_workers=20
    )

    elapsed = time.time() - start
    total_extractions = sum(len(r.extractions) for r in results)

    print(f"Model: {model_id}")
    print(f"Passes: {passes}")
    print(f"Documents: {len(documents)}")
    print(f"Total extractions: {total_extractions}")
    print(f"Time: {elapsed:.2f}s")
    print(f"Throughput: {len(documents)/elapsed:.2f} docs/sec")
    print()

# Compare models
benchmark_extraction(docs, "gemini-2.0-flash-exp", passes=1)
benchmark_extraction(docs, "gemini-2.0-flash-exp", passes=3)
benchmark_extraction(docs, "gpt-4o", passes=1)
```

## Examples

### Example Projects

The repository includes several example implementations:

1. **Custom Provider Plugin** (`examples/custom_provider_plugin/`)
   - How to create custom extraction backends
   - Integration with proprietary models

2. **Jupyter Notebooks** (`examples/notebooks/`)
   - Interactive extraction workflows
   - Visualization and analysis

3. **Ollama Integration** (`examples/ollama/`)
   - Local model usage
   - Privacy-preserving extraction

### Medical Use Case

See `examples/clinical_extraction.py` for a complete medical extraction pipeline.

### Literary Analysis

See `examples/literary_extraction.py` for character and relationship extraction from novels.

## Testing

### Running Tests

```bash
# Install test dependencies
pip install -e ".[test]"

# Run all tests
pytest tests

# Run with coverage
pytest tests --cov=langextract

# Run specific test
pytest tests/test_extraction.py

# Run integration tests
pytest tests/integration/
```

### Integration Testing with Ollama

```bash
# Install tox
pip install tox

# Run Ollama integration tests
tox -e ollama-integration
```

### Writing Tests

```python
import langextract as lx

def test_basic_extraction():
    prompt = "Extract names."
    examples = [
        lx.data.ExampleData(
            text="John Smith visited the clinic.",
            extractions=[
                lx.data.Extraction(
                    extraction_class="name",
                    extraction_text="John Smith"
                )
            ]
        )
    ]

    result = lx.extract(
        text_or_documents="Mary Johnson was the doctor.",
        prompt_description=prompt,
        examples=examples,
        model_id="gemini-2.0-flash-exp"
    )

    assert len(result.extractions) >= 1
    assert result.extractions[0].extraction_class == "name"
```

## Resources

### Official Documentation
- **GitHub Repository**: https://github.com/google/langextract
- **Examples Directory**: https://github.com/google/langextract/tree/main/examples
- **Documentation**: https://github.com/google/langextract/tree/main/docs/examples

### Model Documentation
- **Gemini API**: https://ai.google.dev/
- **Vertex AI**: https://cloud.google.com/vertex-ai
- **OpenAI API**: https://platform.openai.com/
- **Ollama**: https://ollama.ai/

### Related Tools
- **Google AI Studio**: Web interface for Gemini models
- **Vertex AI Workbench**: Enterprise AI development
- **LangChain**: LLM application framework
- **Instructor**: Structured outputs library

### Use Case Examples
- Clinical information extraction
- Legal document analysis
- Scientific literature mining
- Customer feedback structuring
- Contract entity extraction

## Contributing

Contributions welcome! See the official repository for guidelines:
https://github.com/google/langextract

### Development Setup

```bash
git clone https://github.com/google/langextract.git
cd langextract
pip install -e ".[dev]"
pre-commit install
```

### Running CI Locally

```bash
# Full test matrix
tox

# Specific Python version
tox -e py310

# Code formatting
black langextract/
isort langextract/

# Linting
flake8 langextract/
mypy langextract/
```

## Version Information

**Last Updated**: 2025-12-25
**Skill Version**: 1.0.0
**LangExtract Version**: Latest (check PyPI)

---

*This skill provides comprehensive guidance for LangExtract based on official documentation and examples. For the latest updates, refer to the GitHub repository.*