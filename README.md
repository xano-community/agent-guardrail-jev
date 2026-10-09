# Agent Guardrail with Jev

An approval layer for AI agents: before an agent runs a tool, it asks this Xano backend. Jev, TypeSafe AI's decision model, judges the tool call, and Xano allows it, blocks it, or holds it for a human reviewer, then logs every decision.

## Why this exists

AI agents that can call tools — look up orders, issue refunds, export data, delete records — will sometimes try to do the wrong thing. A prompt injection talks them into exporting customer emails; an ambiguous request turns "pause my subscription" into `subscriptions.cancel`. Letting every call through is risky, and asking a human to approve every call defeats the point of the agent. Building the in-between layer yourself means a classifier, thresholds, a review queue, an audit log, and a way for the agent to learn what a human decided.

This template is that layer. The agent sends each proposed tool call to `POST /guard/tool-call` before running it. Xano asks [Jev](https://docs.typesafe.ai/introduction.md) three typed questions — should this run without a human (safe / needs review / dangerous), is it destructive, and is it what the user actually asked for — and gets back probabilities, not prose. A routing rule you control turns those probabilities into a decision: confident-safe calls run, confident-dangerous calls are blocked, and everything uncertain, destructive, or off-request waits in a review queue. If Jev can't be reached or isn't configured, the guardrail fails closed — the call waits for a person. Reviewers approve or reject in a single-file console, and the agent polls for the outcome.

## How it works

Every proposed tool call runs one pipeline (`function guard/evaluate_tool_call`):

1. **Authenticate the agent.** The agent sends its key in the `X-Agent-Key` header. Unknown or disabled agents are refused before anything is recorded (`guard/authenticate_agent`).
2. **Record the proposal.** A `tool_call` row is written as `pending_review`, so nothing is ever "in flight" without a record.
3. **Ask Jev** (`jev/decide`). One `POST https://api.typesafe.ai/v1/systemone` call with the agent, the user's request, and the proposed call as `state`, and three questions: a **Choice** `verdict` (safe / needs_review / dangerous) and two **Nouls**, `destructive` and `matches_request`. The call never throws: a missing key, a network failure, or a documented error status (401, 422, 429, 529) comes back as `ok: false` with a plain-language reason.
4. **Route** (`guard/route`, pure logic). With the active `guard_policy` thresholds:
   - **auto_block** — Jev says *dangerous* with confidence ≥ `block_min_confidence` (default 0.9).
   - **auto_allow** — Jev says *safe* with confidence ≥ `allow_min_confidence` (0.9), **and** destructive < `max_destructive` (0.5), **and** matches_request ≥ `min_matches_request` (0.5).
   - **human_review** — everything else, including any call where Jev did not answer (fail closed).
5. **Log and settle.** Jev's answers, latency, token count, HTTP status, and the route go to `jev_decision`; the tool call becomes `allowed`, `blocked`, or stays `pending_review`.
6. **Human review.** A reviewer approves or rejects a held call (`guard/review_tool_call`), with a note. The agent polls `GET /guard/tool-call/{id}` and gets `may_run: true` only for `allowed` or `approved` calls.

Thresholds live in the `guard_policy` table, so tightening or loosening the guardrail is a `PATCH /policy` (or the console's Policy tab), not a redeploy. Every Jev answer is kept in `jev_decision`, which over time becomes a labeled record of what your agents tried to do and what people decided.

## Common use cases

- **Customer-support agents with write access.** A support agent can look up orders on its own, but refunds, account changes, and cancellations are held for a support lead — and prompt-injected requests to export customer data are blocked.
- **Internal ops agents.** An agent that retries jobs or cleans up data runs read-only and low-impact work immediately, while bulk deletes and anything touching production data wait for an engineer.
- **Billing and finance agents.** Money-moving tool calls (refunds, credits, payouts) get a human check by default; you lower the bar for specific low-risk cases by tuning the policy thresholds as you gain confidence.
- **A shared guardrail for several agents.** Each agent registers with its own key, so the review queue and the decision log show which agent proposed what, and you can disable one agent without touching the others.

## Quick start

1. **Push the backend** to a Xano workspace: `xano workspace push -w <workspace_id> -d backend`. Xano assigns each API group its own `api:<canonical>`; find them in the workspace's API groups (or in `canonical = "…"` after `xano workspace pull`).
2. **Load the demo data** with one call: `curl -X POST "https://<your-instance>.xano.io/api:<seed-canonical>/seed"`. This creates the default policy, three agents, eight sample tool calls, and a demo reviewer (`riley.morgan@guard.demo` / `DemoPass1`).
3. **Open the review console** — `frontend/index.html` (replace the four `__CANON_<GROUP>__` placeholders with your canonicals if your installer didn't), enter your instance URL, and sign in as the demo reviewer.
4. **Connect Jev.** Get an API key from TypeSafe AI ([docs.typesafe.ai](https://docs.typesafe.ai/introduction/quickstart.md)) and set it as the workspace environment variable `JEV_API_KEY`. Until you do, the guardrail runs but fails closed: every tool call goes to the review queue with the reason "Jev isn't configured yet".
5. **Wire your agent.** Register it in the console's Agents tab (or `POST /agents`), store the key it returns, and have the agent call `POST /guard/tool-call` with `X-Agent-Key: <key>` before every tool call. Run the tool only when `status` is `allowed`; when it's `pending_review`, poll `GET /guard/tool-call/{tool_call_id}` until `may_run` is true or the call is `rejected`.
6. **Before going live**, change or delete the demo reviewer, and remove or protect the `Seed` API group.

## API surface

**AgentGuard** — agent-facing; every call sends the agent's key in the `X-Agent-Key` header.

| Method | Path | What it does |
|---|---|---|
| POST | `/guard/tool-call` | Propose a tool call (`user_request`, `tool`, `arguments`). Returns `status` (`allowed` / `blocked` / `pending_review`), `route`, `reason`, and Jev's answers. |
| GET | `/guard/tool-call/{tool_call_id}` | Current status of a call this agent proposed, with the reviewer's note and `may_run`. |

**Review** — reviewers, `Authorization: Bearer <token>` from `/login`.

| Method | Path | What it does |
|---|---|---|
| GET | `/dashboard` | Counts by status, Jev evaluations and fail-closed count, average Jev latency, and the latest calls. |
| GET | `/tool-calls` | Calls newest first; `status=pending_review` is the review queue. |
| GET | `/tool-calls/{tool_call_id}` | One call with its logged Jev decision. |
| POST | `/tool-calls/{tool_call_id}/review` | `decision` `approve` or `reject`, with an optional `note`. |
| POST | `/tool-calls/simulate` | Send a test call as a registered agent through the real pipeline. |
| GET | `/policy` | The active thresholds. |
| PATCH | `/policy` | Change any threshold (each 0 to 1); fields you don't send are unchanged. |
| GET | `/agents` | Registered agents (keys are never listed). |
| POST | `/agents` | Register an agent; its key is returned once. |
| PATCH | `/agents/{agent_id}` | Enable or disable an agent, or rotate its key (new key returned once). |

**Auth**

| Method | Path | What it does |
|---|---|---|
| POST | `/login` | Reviewer login; returns a 24-hour token. |
| POST | `/signup` | Creates the **first** reviewer only; closed once any reviewer exists. |
| GET | `/me` | The signed-in reviewer. |
| POST | `/reviewers` | A signed-in reviewer invites another reviewer. |

**Seed**

| Method | Path | What it does |
|---|---|---|
| POST | `/seed` | Load the demo data (idempotent). |

## Database Tables

- `tool_call` — every tool call an agent proposed: the user's request, the tool and arguments, the status, the route and its reason, and who reviewed it.
- `jev_decision` — one row per Jev evaluation: verdict, confidence, probabilities, destructive and matches-request probabilities, latency, input tokens, HTTP status, and the route Xano chose.
- `guard_policy` — the confidence thresholds the routing rule applies; only the active row is used.
- `guard_agent` — registered agents, each with its own `X-Agent-Key` and an active flag.
- `user` — reviewers who sign in to the console.

## Testing

The tests ship in `backend/` and run with `xano unit_test run_all` and `xano workflow_test run_all`:

- **Unit tests** in `guard/route` (9) cover every routing branch, including stricter thresholds, unknown probabilities, and failing closed. Unit tests in `jev/decide` (5) mock the Jev call with the response shapes from the [TypeSafe API reference](https://docs.typesafe.ai/api.md) — a Choice answer plus two Noul answers, and the documented 401 and 529 errors — and check the no-key path.
- **Workflow tests** (4): the seed loads and is idempotent; a held call is approved and rejected by a reviewer and can't be reviewed twice; agent keys are enforced (unknown, empty, and disabled keys are refused); and a full pipeline run records the call and its decision and, with no `JEV_API_KEY`, holds the call for review.

None of these need a Jev key — the Jev call is mocked from the documented contract, so they prove the integration is correct against the docs, not against the live service. Two **live** tests in `live-tests/` call the real Jev API (an order lookup should be allowed; a prompt-injected customer-data export must not be). They aren't pushed with `backend/`; after setting `JEV_API_KEY`, copy them into `backend/workflow_test/`, push, and run `xano workflow_test run_all`. Jev's answers are probabilistic, so a live result can vary with the model version.

## Environment variables

**TypeSafe AI (Jev)**
- `JEV_API_KEY` — your TypeSafe API key, sent as `Authorization: Bearer <key>` to `https://api.typesafe.ai/v1/systemone`. Get one from [TypeSafe AI](https://docs.typesafe.ai/introduction/quickstart.md). Without it, every tool call fails closed to human review.

## Seed data

`POST /seed` (Seed group) is idempotent and never throws. It creates, only where missing:

- the `default` policy (allow 0.9, block 0.9, max destructive 0.5, min matches-request 0.5);
- the demo reviewer **Riley Morgan** — `riley.morgan@guard.demo` / `DemoPass1`;
- three agents — `support-agent`, `billing-agent`, `ops-agent` — each with a random key (rotate one in the console to see it);
- eight sample tool calls covering every status: two allowed, one blocked (a prompt-injected export), three held (a refund, a bulk delete Jev called safe but destructive, and a Jev outage that failed closed), one approved, and one rejected (a "pause" request the agent turned into a cancel).

The sample calls' Jev answers are **illustrative** — they are labeled `model = "seed-demo"` in `jev_decision` and marked in the console — so you can explore the console before connecting Jev. Sample calls are only inserted into an empty `tool_call` table.

## Frontend

`frontend/index.html` is a single-file review console with no build step and no external dependencies (an embedded Tailwind utility subset and inline Lucide icons). On first load it asks for your Xano instance URL. Tabs: **Dashboard** (counts, Jev availability and latency, recent calls), **Review queue** (held calls; open one to see the request, the arguments, Jev's answers, and approve or reject with a note), **All tool calls** (filter by status), **Try a tool call** (send a test call as any registered agent through the real pipeline), **Policy** (edit thresholds), and **Agents** (register agents, disable them, rotate keys).

Adapted from [cameronb-xano/jev-agent-guardrail](https://github.com/cameronb-xano/jev-agent-guardrail).
