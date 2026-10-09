// The review queue and history: tool calls, newest first, optionally filtered by status.
query "tool-calls" verb=GET {
  api_group = "Review"
  description = "List tool calls newest first; filter by status (pending_review is the review queue)."
  auth = "user"
  input {
    text? status? filters=trim|lower {
      description = "allowed | blocked | pending_review | approved | rejected (omit for all)"
    }

    int page?=1 filters=min:1 {
      description = "Page number"
    }

    int per_page?=25 filters=min:1|max:100 {
      description = "Rows per page (max 100)"
    }
  }

  stack {
    db.query "tool_call" {
      description = "Page through tool calls, filtered by status when given"
      where = $db.tool_call.status ==? $input.status
      sort = {created_at: "desc"}
      return = {type: "list", paging: {page: $input.page, per_page: $input.per_page}}
    } as $calls
  }

  response = $calls
  guid = "yrOQScy6auLhzG4iDqyt-_JT8lU"
}
