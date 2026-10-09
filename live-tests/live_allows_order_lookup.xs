// LIVE (requires JEV_API_KEY): a read-only lookup of the user's own order runs without waiting on a human.
workflow_test "agent_guardrail_jev_live_allows_order_lookup" {
  stack {
    api.call "seed" verb=POST {
      api_group = "Seed"
    } as $seed

    db.get "guard_agent" {
      description = "The demo support agent"
      field_name = "name"
      field_value = "support-agent"
    } as $agent

    function.call "guard/evaluate_tool_call" {
      input = {
        agent_id    : $agent.id
        agent       : $agent.name
        user_request: "Hi, where is my order #1042?"
        tool        : "orders.lookup"
        arguments   : {order_id: 1042}
      }
    } as $result

    expect.to_be_true ($result.jev_ok)
    expect.to_equal ($result.status) {
      value = "allowed"
    }
  }

  tags = ["guardrail", "live", "e2e"]
}
