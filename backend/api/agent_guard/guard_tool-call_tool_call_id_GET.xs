// An agent polls a tool call it proposed, to learn whether a reviewer approved or rejected it.
query "guard/tool-call/{tool_call_id}" verb=GET {
  api_group = "AgentGuard"
  description = "An agent checks the current status of a tool call it proposed (e.g. after human review)."
  input {
    int tool_call_id {
      description = "The tool call returned by POST /guard/tool-call"
    }
  }

  stack {
    function.run "guard/authenticate_agent" {
      description = "Resolve the calling agent from its X-Agent-Key header"
      input = {
        agent_key: ($env.$http_headers|get:"X-Agent-Key":null) ?? ($env.$http_headers|get:"x-agent-key":null)
      }
    } as $agent

    db.get "tool_call" {
      description = "Load the tool call"
      field_name = "id"
      field_value = $input.tool_call_id
    } as $call

    // Agents can only see their own calls; a foreign id looks the same as a missing one
    precondition ($call != null && $call.agent_id == $agent.id) {
      error_type = "notfound"
      error = "That tool call doesn't exist for this agent."
    }
  }

  response = {
    tool_call_id: $call.id
    tool        : $call.tool
    status      : $call.status
    route       : $call.route
    reason      : $call.route_reason
    reviewed_by : $call.reviewed_by
    review_note : $call.review_note
    reviewed_at : $call.reviewed_at
    may_run     : $call.status == "allowed" || $call.status == "approved"
  }
  guid = "ZPxIsWKNWLyDS_u9PFL1LGfOBRU"
}
