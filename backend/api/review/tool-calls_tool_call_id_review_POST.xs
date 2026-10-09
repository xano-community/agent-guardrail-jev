// A reviewer approves or rejects a held tool call. The agent learns the outcome by polling
// GET /guard/tool-call/{id} on the AgentGuard API.
query "tool-calls/{tool_call_id}/review" verb=POST {
  api_group = "Review"
  description = "Approve or reject a held tool call as the signed-in reviewer."
  auth = "user"
  input {
    int tool_call_id {
      description = "The held tool call"
    }

    text decision filters=trim|lower {
      description = "approve | reject"
    }

    text? note? {
      description = "Why you decided this way (shown to the agent)"
    }
  }

  stack {
    function.run "guard/review_tool_call" {
      description = "Apply the review as the signed-in reviewer"
      input = {
        tool_call_id: $input.tool_call_id
        reviewer_id : $auth.id
        decision    : $input.decision
        note        : $input.note
      }
    } as $updated
  }

  response = $updated
  guid = "-BABEpu6uHJSx8kIq86Ai_HAcfA"
}
