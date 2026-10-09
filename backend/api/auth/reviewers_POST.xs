// An existing reviewer invites another reviewer by creating their account.
query "reviewers" verb=POST {
  api_group = "Auth"
  description = "Invite another reviewer (signed-in reviewers only)."
  auth = "user"
  input {
    text name filters=trim {
      description = "New reviewer's display name"
    }

    email email filters=trim|lower {
      description = "New reviewer's login email"
    }

    text password filters=min:8 {
      description = "Initial password (at least 8 characters)"
      sensitive = true
    }
  }

  stack {
    db.has "user" {
      description = "Check whether the email is taken"
      field_name = "email"
      field_value = $input.email
    } as $exists

    // Emails are unique
    precondition ($exists == false) {
      error_type = "inputerror"
      error = "That email is already registered."
    }

    db.add "user" {
      description = "Create the reviewer account"
      data = {name: $input.name, email: $input.email, password: $input.password}
    } as $user
  }

  response = {id: $user.id, name: $user.name, email: $user.email}
  guid = "YGYUd6f2PnWDD12XT74x1WAoAQQ"
}
