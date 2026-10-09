// The AI agents allowed to ask the guardrail for permission. Each authenticates with its own key.
table "guard_agent" {
  auth = false
  description = "Registered AI agents. Each sends its own key in the X-Agent-Key header when it proposes a tool call."
  schema {
    int id
    timestamp created_at?=now
    text name filters=trim {
      description = "Unique agent name, e.g. support-agent"
    }

    text description? {
      description = "What this agent does, shown to reviewers"
    }

    text api_key {
      description = "Secret key the agent sends in the X-Agent-Key header"
      sensitive = true
    }

    bool active?=true {
      description = "Inactive agents are refused before Jev is called"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "name"}]}
    {type: "btree|unique", field: [{name: "api_key"}]}
  ]
  guid = "hSmlYuecwY5T6dknMQCTVDswi7Q"
}
