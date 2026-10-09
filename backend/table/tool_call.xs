// Every tool call an AI agent proposes, and what happened to it.
table "tool_call" {
  auth = false
  description = "Every tool call an AI agent proposed, the route the guardrail chose, and any human review."
  schema {
    int id
    timestamp created_at?=now
    int agent_id? {
      table = "guard_agent"
      description = "The registered agent that proposed the call"
    }

    text agent filters=trim {
      description = "Agent name at the time of the call (kept even if the agent is renamed)"
    }

    text user_request {
      description = "What the end user asked the agent for, in their words"
    }

    text tool filters=trim {
      description = "Tool the agent wants to run, e.g. orders.lookup"
    }

    json arguments? {
      description = "Arguments the agent wants to pass to the tool"
    }

    enum status?="pending_review" {
      description = "allowed | blocked | pending_review | approved | rejected"
      values = ["allowed", "blocked", "pending_review", "approved", "rejected"]
    }

    enum route? {
      description = "Route the guardrail chose: auto_allow | auto_block | human_review"
      values = ["auto_allow", "auto_block", "human_review"]
    }

    text route_reason? {
      description = "Plain-language reason for the route"
    }

    int reviewed_by_id? {
      table = "user"
      description = "Reviewer who approved or rejected the call"
    }

    text reviewed_by? {
      description = "Reviewer name at the time of review"
    }

    text review_note? {
      description = "Reviewer's note explaining the decision"
    }

    timestamp reviewed_at? {
      description = "When the review happened"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "agent_id"}]}
    {type: "btree", field: [{name: "status"}]}
    {type: "btree", field: [{name: "reviewed_by_id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
  guid = "iRO-mxedhRigcCizWGXtgiz5ezI"
}
