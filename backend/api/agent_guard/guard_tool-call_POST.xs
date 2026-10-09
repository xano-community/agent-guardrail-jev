// An agent proposes a tool call. Jev decides, Xano enforces. The response tells the agent whether it
// may run the tool now (allowed), must not (blocked), or must wait for a reviewer (pending_review).
query "guard/tool-call" verb=POST {
  api_group = "AgentGuard"
  description = "An agent proposes a tool call; returns allowed, blocked, or pending_review with Jev's answers."
  input {
    text user_request {
      description = "What the end user asked the agent for, in their words"
    }

    text tool filters=trim {
      description = "Tool the agent wants to run, e.g. orders.lookup"
    }

    json arguments? {
      description = "Arguments the agent wants to pass to the tool"
    }
  }

  stack {
    function.run "guard/authenticate_agent" {
      description = "Resolve the calling agent from its X-Agent-Key header"
      input = {
        agent_key: ($env.$http_headers|get:"X-Agent-Key":null) ?? ($env.$http_headers|get:"x-agent-key":null)
      }
    } as $agent

    function.run "guard/evaluate_tool_call" {
      description = "Record the call, ask Jev, apply the policy, and log the decision"
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
  guid = "75tqrw9JUFmfJAE6l_6xI5_hNyU"
}
