// Resolve the calling agent from the key it sent. Unknown or disabled agents are refused before
// anything is recorded or Jev is called.
function "guard/authenticate_agent" {
  description = "Resolve an active registered agent from its X-Agent-Key value, or refuse the request."
  input {
    text? agent_key? {
      description = "The key the agent sent in the X-Agent-Key header"
      sensitive = true
    }
  }

  stack {
    // A key is required
    precondition ($input.agent_key != null && $input.agent_key != "") {
      error_type = "accessdenied"
      error = "Send your agent key in the X-Agent-Key header."
    }

    db.get "guard_agent" {
      description = "Look up the agent that owns this key"
      field_name = "api_key"
      field_value = $input.agent_key
    } as $agent

    // The key must belong to a registered agent
    precondition ($agent != null) {
      error_type = "accessdenied"
      error = "That agent key isn't recognized."
    }

    // Disabled agents are refused
    precondition ($agent.active) {
      error_type = "accessdenied"
      error = "This agent has been disabled. Ask a reviewer to re-enable it."
    }
  }

  response = {id: $agent.id, name: $agent.name}
  history = 100
  guid = "Dk5nyKIL-eFPRolZihMOX1-HDV4"
}
