// Only registered, active agents can use the guardrail.
workflow_test "agent_guardrail_jev_agent_auth" {
  stack {
    api.call "seed" verb=POST {
      api_group = "Seed"
    } as $seed

    db.get "guard_agent" {
      description = "The demo support agent"
      field_name = "name"
      field_value = "support-agent"
    } as $agent

    function.call "guard/authenticate_agent" {
      input = {agent_key: $agent.api_key}
    } as $who

    expect.to_equal ($who.name) {
      value = "support-agent"
    }

    expect.to_throw {
      stack {
        function.call "guard/authenticate_agent" {
          input = {agent_key: "agk_not_a_real_key"}
        } as $nobody
      }

      exception = "That agent key isn't recognized."
    }

    expect.to_throw {
      stack {
        function.call "guard/authenticate_agent" {
          input = {agent_key: ""}
        } as $empty
      }

      exception = "Send your agent key in the X-Agent-Key header."
    }

    db.edit "guard_agent" {
      description = "Disable the agent"
      field_name = "id"
      field_value = $agent.id
      data = {active: false}
    } as $disabled

    expect.to_throw {
      stack {
        db.get "guard_agent" {
          description = "Re-load the disabled agent (outer variables aren't visible here)"
          field_name = "name"
          field_value = "support-agent"
        } as $disabled_agent

        function.call "guard/authenticate_agent" {
          input = {agent_key: $disabled_agent.api_key}
        } as $refused
      }

      exception = "This agent has been disabled. Ask a reviewer to re-enable it."
    }

    db.edit "guard_agent" {
      description = "Re-enable the agent"
      field_name = "id"
      field_value = $agent.id
      data = {active: true}
    } as $enabled
  }

  tags = ["agents", "security"]
  guid = "tnzwxIl0aRxbfp467bSZAyw0U34"
}
