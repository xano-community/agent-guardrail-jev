// The harness: record the proposed call, ask Jev, apply the active policy, log the decision, and
// return what the agent is allowed to do.
function "guard/evaluate_tool_call" {
  description = "Record a proposed tool call, ask Jev, apply the active policy, log the decision, and return the outcome."
  input {
    int agent_id? {
      table = "guard_agent"
      description = "Registered agent proposing the call"
    }

    text agent filters=trim {
      description = "Agent name"
    }

    text user_request {
      description = "What the end user asked the agent for"
    }

    text tool filters=trim {
      description = "Tool the agent wants to run"
    }

    json arguments? {
      description = "Arguments the agent wants to pass"
    }
  }

  stack {
    group {
      description = "Record the proposal and load the active policy"
      stack {
        db.add "tool_call" {
          description = "Record the proposed call as held until a route is chosen"
          data = {
            agent_id    : $input.agent_id
            agent       : $input.agent
            user_request: $input.user_request
            tool        : $input.tool
            arguments   : $input.arguments
            status      : "pending_review"
          }
        } as $call

        db.query "guard_policy" {
          description = "Load the active policy thresholds"
          where = $db.guard_policy.active == true
          sort = {id: "desc"}
          return = {type: "single"}
        } as $policy
      }
    }

    group {
      description = "Ask Jev and apply the routing rule"
      stack {
        function.run "jev/decide" {
          description = "Ask Jev the three typed questions"
          input = {
            agent       : $input.agent
            user_request: $input.user_request
            tool        : $input.tool
            arguments   : $input.arguments
          }
        } as $jev

        function.run "guard/route" {
          description = "Map Jev's answers plus the policy to a route"
          input = {
            jev_ok              : $jev.ok
            jev_error           : $jev.error
            verdict             : $jev.verdict
            confidence          : $jev.confidence
            destructive         : $jev.destructive
            matches_request     : $jev.matches_request
            allow_min_confidence: $policy.allow_min_confidence ?? 0.9
            block_min_confidence: $policy.block_min_confidence ?? 0.9
            max_destructive     : $policy.max_destructive ?? 0.5
            min_matches_request : $policy.min_matches_request ?? 0.5
          }
        } as $decision
      }
    }

    group {
      description = "Log the decision and settle the tool call's status"
      stack {
        db.add "jev_decision" {
          description = "Log Jev's typed answers and the route Xano chose"
          data = {
            tool_call_id   : $call.id
            model          : $jev.model
            verdict        : $jev.verdict
            confidence     : $jev.confidence
            probabilities  : $jev.probabilities
            destructive    : $jev.destructive
            matches_request: $jev.matches_request
            latency_ms     : $jev.latency_ms
            input_tokens   : $jev.input_tokens
            jev_ok         : $jev.ok
            http_status    : $jev.http_status
            route          : $decision.route
          }
        } as $logged

        var $status {
          description = "Status that follows from the route"
          value = ($decision.route == "auto_allow") ? "allowed" : (($decision.route == "auto_block") ? "blocked" : "pending_review")
        }

        db.edit "tool_call" {
          description = "Store the route, reason, and resulting status on the tool call"
          field_name = "id"
          field_value = $call.id
          data = {
            status      : $status
            route       : $decision.route
            route_reason: $decision.reason
          }
        } as $updated
      }
    }
  }

  response = {
    tool_call_id   : $call.id
    status         : $status
    route          : $decision.route
    reason         : $decision.reason
    verdict        : $jev.verdict
    confidence     : $jev.confidence
    probabilities  : $jev.probabilities
    destructive    : $jev.destructive
    matches_request: $jev.matches_request
    latency_ms     : $jev.latency_ms
    jev_ok         : $jev.ok
  }

  history = 100
  guid = "S4_PPP2-8R6Yy3zx0eYL_7O9W4Q"
}
