// Enable/disable an agent, or rotate its key (the new key is returned once).
query "agents/{agent_id}" verb=PATCH {
  api_group = "Review"
  description = "Enable or disable an agent, or rotate its key (new key returned once)."
  auth = "user"
  input {
    int agent_id {
      description = "The agent to change"
    }

    bool? active? {
      description = "Set false to refuse this agent's calls"
    }

    bool? rotate_key? {
      description = "Set true to issue a new key and invalidate the old one"
    }
  }

  stack {
    db.get "guard_agent" {
      description = "Load the agent"
      field_name = "id"
      field_value = $input.agent_id
    } as $agent

    // The agent must exist
    precondition ($agent != null) {
      error_type = "notfound"
      error = "That agent doesn't exist."
    }

    security.create_uuid as $uuid
    var $updates {
      description = "The changes that were requested"
      value = {}|set_ifnotnull:"active":$input.active
    }

    // Issue a new key only when asked
    conditional {
      if ($input.rotate_key == true) {
        var.update $updates {
          description = "Add a fresh random key"
          value = $updates|set:"api_key":("agk_" ~ ($uuid|replace:"-":""))
        }
      }
    }

    db.patch "guard_agent" {
      description = "Save the changes"
      field_name = "id"
      field_value = $input.agent_id
      data = $updates
    } as $updated
  }

  response = {
    id         : $updated.id
    name       : $updated.name
    description: $updated.description
    active     : $updated.active
    api_key    : ($input.rotate_key == true) ? $updated.api_key : null
  }
  guid = "gejI8QgFC3DJ1abgQdgZx_QI23k"
}
