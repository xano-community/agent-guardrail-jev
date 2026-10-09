// Reviewers who sign in to the console to approve or reject held tool calls. Backs authentication.
table "user" {
  auth = true
  description = "Reviewers who sign in to approve or reject tool calls the guardrail held for a human."
  schema {
    int id
    timestamp created_at?=now
    text name filters=trim {
      description = "Reviewer display name, recorded on every review"
    }

    email email filters=trim|lower {
      description = "Login email (unique)"
      sensitive = true
    }

    password password {
      description = "Hashed login password"
      sensitive = true
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "email"}]}
  ]
  guid = "ubsZzZxVeltBIROF5Ei0M1jhDNU"
}
