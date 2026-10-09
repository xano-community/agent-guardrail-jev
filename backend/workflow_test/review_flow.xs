// User flow: a held tool call is approved by a reviewer, the agent sees may_run = true, and the call
// can't be reviewed twice. A second held call is rejected and the agent sees may_run = false.
workflow_test "agent_guardrail_jev_review_flow" {
  stack {
    api.call "seed" verb=POST {
      api_group = "Seed"
    } as $seed

    db.get "user" {
      description = "The demo reviewer"
      field_name = "email"
      field_value = "riley.morgan@guard.demo"
    } as $reviewer

    db.get "guard_agent" {
      description = "The demo billing agent"
      field_name = "name"
      field_value = "billing-agent"
    } as $agent

    db.add "tool_call" {
      description = "A call the guardrail held for a human"
      data = {
        agent_id    : $agent.id
        agent       : $agent.name
        user_request: "Refund the duplicate charge on invoice INV-9001."
        tool        : "payments.refund"
        arguments   : {invoice_id: "INV-9001", amount: 25}
        status      : "pending_review"
        route       : "human_review"
        route_reason: "Jev flagged this call for human review"
      }
    } as $held

    function.call "guard/review_tool_call" {
      input = {
        tool_call_id: $held.id
        reviewer_id : $reviewer.id
        decision    : "approve"
        note        : "Duplicate charge confirmed."
      }
    } as $approved

    expect.to_equal ($approved.status) {
      value = "approved"
    }

    expect.to_equal ($approved.reviewed_by) {
      value = "Riley Morgan"
    }

    expect.to_throw {
      stack {
        db.get "tool_call" {
          description = "Re-load the approved call (outer variables aren't visible here)"
          field_name = "user_request"
          field_value = "Refund the duplicate charge on invoice INV-9001."
        } as $done

        db.get "user" {
          description = "Re-load the demo reviewer"
          field_name = "email"
          field_value = "riley.morgan@guard.demo"
        } as $same_reviewer

        function.call "guard/review_tool_call" {
          input = {
            tool_call_id: $done.id
            reviewer_id : $same_reviewer.id
            decision    : "reject"
          }
        } as $again
      }

      exception = "This tool call isn't waiting for review — it was already approved."
    }

    db.add "tool_call" {
      description = "A second held call, to reject"
      data = {
        agent_id    : $agent.id
        agent       : $agent.name
        user_request: "Can I pause my plan?"
        tool        : "subscriptions.cancel"
        status      : "pending_review"
        route       : "human_review"
        route_reason: "Jev said safe, but the call looks destructive or is not what the user asked for"
      }
    } as $held2

    function.call "guard/review_tool_call" {
      input = {
        tool_call_id: $held2.id
        reviewer_id : $reviewer.id
        decision    : "reject"
        note        : "Customer asked to pause, not cancel."
      }
    } as $rejected

    expect.to_equal ($rejected.status) {
      value = "rejected"
    }

    expect.to_equal ($rejected.review_note) {
      value = "Customer asked to pause, not cancel."
    }
  }

  tags = ["review", "human-in-the-loop", "user-flow"]
  guid = "UZotqhTGFxw3_jC3Lw6fp-lrQbw"
}
