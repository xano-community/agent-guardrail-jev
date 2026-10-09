// What the guardrail has been doing: counts by status, how often Jev answered, and the latest calls.
query "dashboard" verb=GET {
  api_group = "Review"
  description = "Counts of tool calls by status, Jev availability and latency, and the most recent calls."
  auth = "user"
  input {
  }

  stack {
    group {
      description = "Count tool calls by status"
      stack {
        db.query "tool_call" {
          description = "Calls Jev allowed automatically"
          where = $db.tool_call.status == "allowed"
          return = {type: "count"}
        } as $allowed

        db.query "tool_call" {
          description = "Calls Jev blocked automatically"
          where = $db.tool_call.status == "blocked"
          return = {type: "count"}
        } as $blocked

        db.query "tool_call" {
          description = "Calls waiting for a reviewer"
          where = $db.tool_call.status == "pending_review"
          return = {type: "count"}
        } as $pending

        db.query "tool_call" {
          description = "Calls a reviewer approved"
          where = $db.tool_call.status == "approved"
          return = {type: "count"}
        } as $approved

        db.query "tool_call" {
          description = "Calls a reviewer rejected"
          where = $db.tool_call.status == "rejected"
          return = {type: "count"}
        } as $rejected
      }
    }

    group {
      description = "Jev availability and latency"
      stack {
        db.query "jev_decision" {
          description = "All logged Jev evaluations"
          return = {type: "count"}
        } as $decisions

        db.query "jev_decision" {
          description = "Evaluations where Jev did not answer (guardrail failed closed)"
          where = $db.jev_decision.jev_ok == false
          return = {type: "count"}
        } as $unavailable

        db.query "jev_decision" {
          description = "Latency of evaluations where Jev answered"
          where = $db.jev_decision.jev_ok == true
          return = {type: "list"}
          output = ["latency_ms"]
        } as $answered
      }
    }

    db.query "tool_call" {
      description = "The ten most recent tool calls"
      sort = {created_at: "desc"}
      return = {type: "list", paging: {page: 1, per_page: 10}}
    } as $recent
  }

  response = {
    counts            : {
      allowed       : $allowed
      blocked       : $blocked
      pending_review: $pending
      approved      : $approved
      rejected      : $rejected
      total         : $allowed + $blocked + $pending + $approved + $rejected
    }
    jev_evaluations   : $decisions
    jev_unavailable   : $unavailable
    avg_jev_latency_ms: ($answered|count) > 0 ? (($answered|map:$$.latency_ms|avg)|round:0) : null
    recent            : $recent.items
  }
  guid = "Ffsc03-9w2f6Y_FpP1WDciltK4s"
}
