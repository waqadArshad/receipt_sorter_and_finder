
Below is a **single, comprehensive “builder prompt”** you can give to a coding AI (Codex, Cursor, etc.).
It is intentionally long, explicit, and opinionated, because coding agents perform best when ambiguity is removed.

This prompt asks the agent to **design first, then implement**, compare the two architectural options you described, and bias toward **low cost, hackathon-safe decisions**.

You can paste this **as-is** into Cursor/Codex.

---

# 📌 BUILDER PROMPT: Screenshot Sorter & Finder (Flutter + Serverpod, Low-Cost, Local-First)

## ROLE

You are a **senior full-stack engineer and system architect** experienced with:

* Flutter (Android + iOS)
* Dart backends
* Serverpod
* On-device ML (OCR, lightweight models)
* Cost-constrained architectures (local-first, offline-friendly)
* Hackathon-grade delivery (clear scope, demo-ready)

Your task is to **design and implement** a Screenshot Sorter & Finder app using **Flutter + Serverpod**, with a strong focus on **minimizing runtime costs** and **avoiding paid APIs wherever possible**.

---

## PRODUCT GOAL

Build a **Screenshot Butler** that:

1. Automatically processes screenshots and images
2. Extracts text (OCR)
3. Classifies the screenshot (receipt, chat, code, document, etc.)
4. Stores structured metadata server-side
5. Allows users to **search and query their screenshots later**
6. Is architecturally sound and explainable (no “black-box AI magic”)

This is **not a chatbot**.
This is a **personal automation + retrieval system**.

---

## CORE CONSTRAINTS (DO NOT VIOLATE)

* **Cost must be minimal**
* Prefer **on-device processing**
* Avoid paid cloud APIs unless explicitly justified
* Serverpod must act as:

  * Orchestration layer
  * Persistence layer
  * Query/RAG backend
* AI outputs must be:

  * Deterministic where possible
  * Auditable
  * Editable by the user

---

## HIGH-LEVEL ARCHITECTURE

```
Flutter App (Client)
 ├─ Screenshot import / capture
 ├─ On-device OCR
 ├─ (Optional) On-device classification
 ├─ Manual correction UI
 └─ Search UI

Serverpod Backend
 ├─ User auth
 ├─ Screenshot metadata storage
 ├─ Background processing
 ├─ Query + retrieval logic
 └─ Optional RAG-style reasoning
```

---

## OCR REQUIREMENT (MANDATORY)

* OCR must be **on-device**
* Use **Google ML Kit Text Recognition**
* OCR happens **before** upload when possible
* Raw OCR text must be sent to Serverpod
* Images may optionally be uploaded for reference only

Do **not** use paid OCR APIs.

---

## CLASSIFICATION: TWO OPTIONS TO DESIGN & COMPARE

You must **design, compare, and recommend** between the following:

---

### 🔹 OPTION A: Fully On-Device Classification (Local-Only)

#### A1. Text-Only Classification

* Use OCR text only
* Use:

  * Small local LLM, OR
  * Rule-based + embedding similarity
* Classifies into:

  * receipt
  * chat
  * code
  * email
  * document
  * other

#### A2. Image-Based Classification

* Use a lightweight image classifier (TFLite / CoreML)
* Classify screenshot type visually
* No text understanding

**Pros**

* Zero API cost
* Offline-friendly

**Cons**

* More complexity
* Model accuracy limitations

---

### 🔹 OPTION B: Hybrid (On-Device OCR + Free Hosted Model)

* OCR on device
* Send **only OCR text** to a **free-tier hosted model**
* Classification only (no generation)
* Must have:

  * Strict rate limits
  * Fallback to rule-based logic

**Pros**

* Better classification quality
* Simpler client models

**Cons**

* External dependency
* Free tier limits

---

## YOUR TASK REGARDING OPTIONS

1. Design **both options**
2. Compare them across:

   * Cost
   * Complexity
   * Accuracy
   * Hackathon risk
   * Implementation time
3. Recommend **one default**
4. Design the system so the other option can be swapped in later

---

## CLASSIFICATION OUTPUT REQUIREMENTS

Classification must return:

```json
{
  "type": "receipt | chat | code | document | other",
  "confidence": 0.0 - 1.0,
  "reason": "short explanation"
}
```

* If confidence < 0.6 → treat as `other`
* Never hallucinate missing data
* Never assume intent

---

## SERVERPOD RESPONSIBILITIES (MANDATORY)

Design and implement:

### 1. Data Models

* Screenshot record
* OCR text
* Classification result
* User corrections
* Timestamps
* Confidence scores

### 2. APIs

* Upload OCR + metadata
* Update classification
* Search/query screenshots
* Retrieve grouped results

### 3. Retrieval Logic (IMPORTANT)

Retrieval is **NOT semantic chat-style RAG**.

Use:

* Structured filters
* Full-text search
* Deterministic aggregation

Examples:

* “Show screenshots with code from last week”
* “Find receipts containing Amazon”
* “List chats from January”

If RAG is used:

* It must be **query planning → retrieval → optional summarization**
* Not vector search over random text chunks

---

## SEARCH & FIND FEATURES (USER-VISIBLE)

* Keyword search over OCR text
* Filter by:

  * Type
  * Date range
  * Confidence
* Group by type or time
* Fast local + server results

---

## UI REQUIREMENTS (FLUTTER)

* Screenshot import
* Processing status
* Classification preview
* Manual edit / override
* Confidence indicator
* Search screen
* Detail view

UI must allow:

* User corrections
* Re-running classification after edits

---

## NON-FUNCTIONAL REQUIREMENTS

* Offline-first where possible
* Graceful degradation if models fail
* No blocking UI on ML tasks
* Background processing
* Clear logs for demo

---

## DELIVERABLES FROM YOU (CODING AGENT)

You must produce:

1. **Architecture explanation**
2. **Option A vs Option B comparison table**
3. **Final recommendation**
4. **Serverpod schema**
5. **API design**
6. **Flutter integration plan**
7. **ML model choices**
8. **Implementation steps**
9. **Demo flow for judges**

Then:

* Start implementing incrementally
* Begin with the **recommended option**

---

## IMPORTANT PHILOSOPHY (DO NOT IGNORE)

* Do not over-engineer
* Prefer correctness over “AI magic”
* This is a **butler**, not a chatbot
* Judges value **architecture clarity** more than model novelty

---

## FINAL INSTRUCTION

Think first.
Design carefully.
Then implement in **small, testable steps**.

---

If you want, next I can:

* **Trim this prompt to a “fast version”** for Cursor
* Provide **model recommendations** for on-device classification
* Help you decide **Option A vs B** explicitly for hackathon time limits
* Draft the **Devpost technical description** based on this architecture

Just tell me how you want to proceed.
