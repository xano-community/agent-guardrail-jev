// One tool call with everything a reviewer needs: the request, the arguments, and Jev's answers.
query "tool-calls/{tool_call_id}" verb=GET {
  api_group = "Review"
  description = "One tool call with its Jev decision(s), for the reviewer's detail view."
  auth = "user"
  input {
    int tool_call_id {
      description = "The tool call to show"
    }
  }

  stack {
    db.get "tool_call" {
      description = "Load the tool call"
      field_name = "id"
      field_value = $input.tool_call_id
    } as $call

    // The call must exist
    precondition ($call != null) {
      error_type = "notfound"
      error = "That tool call doesn't exist."
    }

    db.query "jev_decision" {
      description = "Jev's logged answers for this call"
      where = $db.jev_decision.tool_call_id == $input.tool_call_id
      sort = {created_at: "desc"}
      return = {type: "list"}
    } as $decisions
  }

  response = {tool_call: $call, decisions: $decisions}
  guid = "JWRWwblUx3b8sIAdpxbikPfd1iQ"
}
