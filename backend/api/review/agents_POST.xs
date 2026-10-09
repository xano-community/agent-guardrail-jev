// Register a new agent and return its key ONCE. Store it in the agent's secrets.
query "agents" verb=POST {
  api_group = "Review"
  description = "Register an agent and return its X-Agent-Key (shown once)."
  auth = "user"
  input {
    text name filters=trim|lower {
      description = "Unique agent name, e.g. billing-agent"
    }

    text description? {
      description = "What this agent does"
    }
  }

  stack {
    db.has "guard_agent" {
      description = "Check whether the name is taken"
      field_name = "name"
      field_value = $input.name
    } as $exists

    // Agent names are unique
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "An agent with that name already exists."
    }

    security.create_uuid as $uuid
    db.add "guard_agent" {
      description = "Create the agent with a fresh random key"
      data = {
        name       : $input.name
        description: $input.description
        api_key    : "agk_" ~ ($uuid|replace:"-":"")
        active     : true
      }
    } as $agent
  }

  response = {
    id         : $agent.id
    name       : $agent.name
    description: $agent.description
    active     : $agent.active
    api_key    : $agent.api_key
  }
  guid = "_of-DaY_K5zg1Ey1hLlpBUuf9Gk"
}
