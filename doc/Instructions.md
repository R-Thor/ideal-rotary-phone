# Reproducible State Documentation for Fedora VM + Podman + AI‑Sandbox

## PHASE 1 — Hyper‑V Fedora Server VM Setup

### Step 1.1 — Create VM
- Gen2 VM
- Explicit RAM allocation sized for AI workloads
- Explicit disk sizing for OS plus model storage
- Secure Boot enabled
- ISO: Fedora Server (minimal install)

### Step 1.2 — Install Fedora Server
- Skip root password
- Create a single admin user
- Choose minimal package set
- Validate package count
- Confirm clean boot into the new system

### Step 1.3 — Create pristine checkpoint
- Take a Hyper‑V checkpoint immediately after first boot
- Treat this as the deterministic rollback baseline

Gotcha:  
If you skip this checkpoint, later debugging of Podman, systemd, or cgroups becomes much more time‑consuming and harder to reproduce.

---

## PHASE 2 — Podman Rootless Environment

### Step 2.1 — Validate systemd user session
- Confirm that systemctl --user works
- Enable lingering for the user if needed (for long‑running user services)
- Confirm that cgroup v2 is active on the system

### Step 2.2 — Install Podman
- Install Podman from Fedora repositories using dnf
- Verify installation with:
  - podman info
  - podman version

### Step 2.3 — Validate rootless container startup
- Run a trivial rootless container (for example, a small test image)
- Confirm that slirp4netns networking works
- Confirm that port forwarding works while the firewall is in a simple or permissive state

Gotcha:  
Rootless Podman requires firewalld masquerading for port forwarding to work correctly. Without masquerading, published ports may silently fail.

---

## PHASE 3 — AI‑Sandbox Container Architecture

### Step 3.1 — Build AI‑sandbox container
- Create a container image with:
  - llama.cpp built inside the container
  - an application directory, for example /app
- Mount models from the host into the container:
  - Host path: /home/brutef0rce/models
  - Container path: /app/models
- Expose port 8080 from the container
- Set the container entrypoint or command to run the llama.cpp server (for example, llama-server or similar binary)

### Step 3.2 — Run container
- Example rootless Podman run command:

  - podman run --rm -it
    - publish host port 8080 to container port 8080
    - mount host models directory into container models directory
    - use the AI‑sandbox image

### Step 3.3 — Validate health
- From inside the VM, confirm the server is reachable on localhost:
  - curl http://127.0.0.1:8080/health (or the equivalent health endpoint your server exposes)

---

## PHASE 4 — Networking and Firewall Fixes

### Step 4.1 — Initial state with firewall disabled
- In the early phase, firewalld may be stopped or disabled
- In this state, rootless Podman port forwarding usually works without additional configuration
- This is useful for initial validation but not acceptable for a hardened or realistic system

### Step 4.2 — Re‑enable firewalld
- Start and verify firewalld:
  - systemctl start firewalld
  - firewall-cmd --state

### Step 4.3 — Enable masquerading (critical for rootless Podman)
- Add and persist masquerading in firewalld:
  - firewall-cmd --add-masquerade --permanent
  - firewall-cmd --reload
- After enabling masquerading, re‑test rootless Podman port forwarding and external access

Gotcha (critical):  
Without masquerading, rootless Podman port forwarding fails silently. Symptoms:
- Connections to published ports are reset or time out
- The containerized llama.cpp server receives no requests and logs nothing related to those attempts
- No obvious error messages indicate that masquerading is missing

---

## PHASE 5 — llama.cpp Behavior and Model Selection

### Step 5.1 — Base model in use
- Model file: llama-2-7b.Q4_K_M.gguf
- This is a base LLaMA‑2 model, not an instruction‑tuned or chat‑tuned variant

Characteristics of the base model:
- Does not understand chat templates or roles
- Does not reliably follow natural language instructions
- Behaves as a pure next‑token predictor (raw language model)

### Step 5.2 — llama.cpp server mode and chat format
- Server logs show a chat format of "Content-only"
- Implications:
  - No chat template is being applied by default
  - The server treats the prompt as raw content
  - Endpoints like /chat/completions may be internally mapped to /completion behavior
  - Special tokens like chat markers or role delimiters are treated as literal text, not control tokens

### Step 5.3 — Correct model and configuration options
To get assistant‑like behavior and proper instruction following, you can:

- Use a chat‑tuned model:
  - For example: Llama-2-7B-Chat.Q4_K_M.gguf
- Or explicitly specify a chat template when starting llama.cpp:
  - For example: a template corresponding to LLaMA‑2 chat format
- Or run llama.cpp in an OpenAI‑compatible API mode so /v1/chat/completions behaves predictably

Gotcha:  
Using a base model for chat‑style interaction leads to:
- Hallucinated forum‑like content
- Poor instruction compliance
- Misinterpretation of chat style prompts and role markers

---

## PHASE 6 — Prompting Strategy for Base Models

### Effective prompting pattern for the base LLaMA‑2 model
The base model responds best to explicit, structured prompts, such as:

- Task: followed by a clear instruction
- Answer: marker to indicate where the model should produce its output

For example:
- Task: Explain how DNS works in three parts. Answer:
- Task: Write a Bash script that does X. Only output the script. Answer:

### Practices to avoid with the base model
- Short, underspecified prompts such as:
  - add 1 and 3
- Natural language questions relying on implicit understanding
- Use of chat‑style role markers or conversation templates without a proper chat model

### Practices that improve reliability
- Use multi‑step, clearly structured instructions
- Segment complex tasks into numbered sections
- Explicitly define the desired output format (for example: "Only output the Bash script", "Write three paragraphs", etc.)
- Use Task: and Answer: framing to push the model into a deterministic Q and A mode

Gotcha:  
Short prompts tend to produce chaotic or irrelevant output with the base model, including:
- Random code snippets
- Hallucinated comments
- StackOverflow‑style chatter

---

## PHASE 7 — Known Gotchas (Explicit List)

### GOTCHA 1 — Rootless Podman requires firewalld masquerading
- Without masquerading:
  - Published ports appear open but do not function correctly
  - Requests never reach the container
  - There may be no clear error messaging to indicate the missing configuration

### GOTCHA 2 — Base LLaMA‑2 model is not a chat model
- Symptoms:
  - Ignores chat formatting and role separation
  - Repeats or loops special tokens used as chat markers
  - Produces forum‑like or irrelevant text instead of concise answers

### GOTCHA 3 — Chat endpoints may map to completion behavior
- Some llama.cpp configurations route chat endpoints internally to completion behavior when no chat template is configured
- This means:
  - The model does not receive structured chat metadata
  - Prompts must be written as raw instruction text

### GOTCHA 4 — Short prompts cause hallucination and drift
- Minimal prompts provide too little context for the base model
- Leads to:
  - Hallucinated context
  - Off‑topic expansions
  - Misinterpretation of the user’s intent

### GOTCHA 5 — Chat format labels in logs can mislead
- A label like "Content-only" in logs can look like chat is enabled when it is not
- Important:
  - Chat format "Content-only" means the prompt is passed directly as text
  - No template or role metadata is being applied

### GOTCHA 6 — Underspecified prompts increase drift
- When instructions lack detail, the base model:
  - Fills in gaps with guessed context
  - Produces less reliable or less relevant responses
- Solution:
  - Use highly explicit prompts with clear structure, constraints, and expected formats

### GOTCHA 7 — Firewall state silently affects Podman networking
- Changing firewalld state without adjusting for rootless needs (such as masquerading) leads to:
  - Broken port forwarding
  - No obvious error messages from Podman
  - Confusing behavior where containers run but are not reachable

---

This document represents the key steps and gotchas needed to reconstruct the current functional state of the Fedora Server VM, Podman rootless environment, and AI‑sandbox (llama.cpp) setup.

