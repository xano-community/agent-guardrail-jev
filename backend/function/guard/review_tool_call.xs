// A reviewer approves or rejects a tool call the guardrail held. Only held calls can be reviewed,
// and every review records who decided, when, and why.
function "guard/review_tool_call" {
  description = "Approve or reject a held tool call, recording the reviewer, time, and note."
  input {
    int tool_call_id {
      description = "The held tool call"
    }

    int reviewer_id {
      table = "user"
      description = "The reviewer making the decision"
    }

    text decision filters=trim|lower {
      description = "approve | reject"
    }

    text? note? {
      description = "Why the reviewer decided this way"
    }
  }

  stack {
    group {
      description = "Load and check the tool call and reviewer"
      stack {
        // Only approve or reject are valid decisions
        precondition ($input.decision == "approve" || $input.decision == "reject") {
          error_type = "inputerror"
          error = "Choose approve or reject."
        }

        db.get "tool_call" {
          description = "Load the tool call being reviewed"
          field_name = "id"
          field_value = $input.tool_call_id
        } as $call

        // The call must exist
        precondition ($call != null) {
          error_type = "notfound"
          error = "That tool call doesn't exist."
        }

        // Only held calls can be reviewed
        precondition ($call.status == "pending_review") {
          error_type = "inputerror"
          error = "This tool call isn't waiting for review — it was already " ~ ($call.status|replace:"_":" ") ~ "."
        }

        db.get "user" {
          description = "Load the reviewer, to record their name"
          field_name = "id"
          field_value = $input.reviewer_id
        } as $reviewer
      }
    }

    db.edit "tool_call" {
      description = "Record the decision, the reviewer, and the note"
      field_name = "id"
      field_value = $input.tool_call_id
      data = {
        status        : ($input.decision == "approve") ? "approved" : "rejected"
        reviewed_by_id: $input.reviewer_id
        reviewed_by   : $reviewer.name
        review_note   : $input.note
        reviewed_at   : now
      }
    } as $updated
  }

  response = $updated
  history = 100
  guid = "JsvfsjBN1MsOb_I4KqPhvMt3gyY"
}
