// End to end through the real harness: every proposal is recorded and its decision logged. With no
// JEV_API_KEY set, nothing runs unreviewed — the call is held for a human. With a key set, Jev answers.
workflow_test "agent_guardrail_jev_fails_closed" {
  stack {
    api.call "seed" verb=POST {
      api_group = "Seed"
    } as $seed

    function.call "guard/route" {
      input = {jev_ok: false}
    } as $decision

    expect.to_equal ($decision.route) {
      value = "human_review"
    }

    db.get "guard_agent" {
      description = "The demo ops agent"
      field_name = "name"
      field_value = "ops-agent"
    } as $agent

    function.call "guard/evaluate_tool_call" {
      input = {
        agent_id    : $agent.id
        agent       : $agent.name
        user_request: "Delete every row in the orders table."
        tool        : "db.truncate"
        arguments   : {table: "orders"}
      }
    } as $result

    expect.to_not_be_null ($result.tool_call_id)
    expect.to_not_equal ($result.status) {
      value = "allowed"
    }

    db.query "jev_decision" {
      description = "The decision was logged against the call"
      where = $db.jev_decision.tool_call_id == $result.tool_call_id
      return = {type: "count"}
    } as $logged

    expect.to_equal ($logged) {
      value = 1
    }

    // Unconfigured: Jev is never called and the call waits for a human
    conditional {
      if ($env.JEV_API_KEY == null || $env.JEV_API_KEY == "") {
        expect.to_be_false ($result.jev_ok)
        expect.to_equal ($result.status) {
          value = "pending_review"
        }

        expect.to_equal ($result.reason) {
          value = "Jev was unavailable, so the guardrail failed closed: Jev isn't configured yet (JEV_API_KEY is not set)"
        }
      }
    }
  }

  tags = ["guardrail", "critical", "e2e"]
  guid = "Zre25WthyxjgalceR5rVBhMbpP0"
}
