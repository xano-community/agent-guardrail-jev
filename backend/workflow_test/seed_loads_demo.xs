// The seed loads the policy, reviewer, agents, and samples — and a second call duplicates nothing.
workflow_test "agent_guardrail_jev_seed_loads_demo" {
  stack {
    api.call "seed" verb=POST {
      api_group = "Seed"
    } as $first

    expect.to_be_true ($first.seeded)
    api.call "seed" verb=POST {
      api_group = "Seed"
    } as $second

    expect.to_equal ($second.tool_calls) {
      value = $first.tool_calls
    }

    db.query "guard_policy" {
      description = "The active policy exists"
      where = $db.guard_policy.active == true
      return = {type: "count"}
    } as $policies

    expect.to_be_greater_than ($policies) {
      value = 0
    }

    db.query "guard_agent" {
      description = "The three demo agents exist exactly once"
      where = $db.guard_agent.name == "support-agent" || $db.guard_agent.name == "billing-agent" || $db.guard_agent.name == "ops-agent"
      return = {type: "count"}
    } as $agents

    expect.to_equal ($agents) {
      value = 3
    }

    db.query "tool_call" {
      description = "There is something in the review queue"
      where = $db.tool_call.status == "pending_review"
      return = {type: "count"}
    } as $held

    expect.to_be_greater_than ($held) {
      value = 0
    }
  }

  tags = ["seed", "user-flow"]
  guid = "RCVMEp7jxzeK3QgWYE5R21lD7Us"
}
