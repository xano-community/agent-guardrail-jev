// Try the guardrail from the console: send a tool call on behalf of a registered agent and see what
// Jev and the policy decide. Runs the exact same path as POST /guard/tool-call.
query "tool-calls/simulate" verb=POST {
  api_group = "Review"
  description = "Send a test tool call on behalf of a registered agent through the real guardrail path."
  auth = "user"
  input {
    int agent_id {
      description = "The registered agent to act as"
    }

    text user_request {
      description = "What the end user asked the agent for"
    }

    text tool filters=trim {
      description = "Tool the agent wants to run"
    }

    json arguments? {
      description = "Arguments for the tool"
    }
  }

  stack {
    db.get "guard_agent" {
      description = "Load the agent to act as"
      field_name = "id"
      field_value = $input.agent_id
    } as $agent

    // The agent must exist and be active
    precondition ($agent != null && $agent.active) {
      error_type = "inputerror"
      error = "Pick an active agent to act as."
    }

    function.run "guard/evaluate_tool_call" {
      description = "Run the call through the real guardrail path"
      input = {
        agent_id    : $agent.id
        agent       : $agent.name
        user_request: $input.user_request
        tool        : $input.tool
        arguments   : $input.arguments
      }
    } as $result
  }

  response = $result
  guid = "KTVLQl25Kba2x2MlupJ11QB7s8Q"
}
