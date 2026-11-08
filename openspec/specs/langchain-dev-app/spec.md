# langchain-dev-app Specification

## Purpose

The langchain-dev-app capability defines the Python dev application (`src/`) that runs inside the `app` container. It provides a FastAPI service, a RAG chain over a scraped web page, and a devcontainer-style workspace for experimenting with Langchain and Ollama. It captures the app's endpoints, its model wiring, and its debugging access so changes to the experiment code do not break the container or its connectivity to the backends.

## Requirements

### Requirement: langchain-dev-app serves a FastAPI service
The `app` container SHALL run a uvicorn FastAPI server exposing the application module.

#### Scenario: Root endpoint returns the HTML page
- **WHEN** a client sends `GET /`
- **THEN** the server reads `./src/index.html` and returns it with `HTMLResponse`

#### Scenario: Server listens on the container port
- **WHEN** the app starts
- **THEN** uvicorn binds to `0.0.0.0:8000`
- **AND** the port is published to the host for access

### Requirement: App connects to Ollama backends
The Langchain chains SHALL reach Ollama over the internal network using the OpenAI-compatible endpoint.

#### Scenario: Direct local backend call
- **WHEN** `src/test.py` runs
- **THEN** the `Ollama` client targets `http://localhost:11434`
- **AND** it issues a completion against the configured model

#### Scenario: RAG chain uses Ollama for generation
- **WHEN** `src/rag.py` runs its QA chain
- **THEN** it uses the `Ollama` LLM for generation and a Chroma vector store with embeddings for retrieval

### Requirement: App exposes a remote debugger
The app SHALL listen on a debug port so code inside the container can be debugged from the host.

#### Scenario: Debug port is open
- **WHEN** the app starts
- **THEN** `debugpy` listens on `0.0.0.0:5678`
- **AND** the port is published for host-side debugging

### Requirement: App allows cross-origin requests
The app SHALL enable permissive CORS so browser-based clients can call it.

#### Scenario: Cross-origin requests are accepted
- **WHEN** a browser client calls the app
- **THEN** the CORS middleware allows all origins (`*`) with credentials and all methods/headers

### Requirement: App source is mounted for live iteration
The container SHALL mount the project source so experiment code changes take effect without rebuilding.

#### Scenario: Source is mounted into the container
- **WHEN** the `app` container starts
- **THEN** the project root is mounted to `/code`
- **AND** uvicorn runs with `--reload` so edits are picked up

### Requirement: App image installs project dependencies
The app's Dockerfile SHALL build an environment that can run the Langchain/FastAPI stack.

#### Scenario: Dependencies are installed at build time
- **WHEN** the `app` image is built from the Dockerfile
- **THEN** Python build tools (`gcc`, `g++`, `make`, `cmake`, `pkg-config`, `git`, `curl`) are installed
- **AND** `requirements.txt` (FastAPI, uvicorn, langchain, chromadb, gpt4all, etc.) is installed via pip
