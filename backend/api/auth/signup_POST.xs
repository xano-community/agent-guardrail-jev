// Create the FIRST reviewer account. Once any reviewer exists, signup closes and new reviewers are
// invited by an existing one (POST /reviewers) — so nobody can sign themselves up to approve calls.
query "signup" verb=POST {
  api_group = "Auth"
  description = "Create the first reviewer (only while no reviewers exist); returns a 24h auth token."
  input {
    text name filters=trim {
      description = "Reviewer display name"
    }

    email email filters=trim|lower {
      description = "Login email"
    }

    text password filters=min:8 {
      description = "Login password (at least 8 characters)"
      sensitive = true
    }
  }

  stack {
    db.query "user" {
      description = "Count existing reviewers"
      return = {type: "count"}
    } as $reviewers

    // Signup is only open to bootstrap the first reviewer
    precondition ($reviewers == 0) {
      error_type = "accessdenied"
      error = "Signup is closed. Ask an existing reviewer to invite you."
    }

    db.add "user" {
      description = "Create the first reviewer"
      data = {name: $input.name, email: $input.email, password: $input.password}
    } as $user

    security.create_auth_token {
      table = "user"
      id = $user.id
      extras = {}
      expiration = 86400
    } as $token
  }

  response = {
    authToken: $token
    user     : {id: $user.id, name: $user.name, email: $user.email}
  }
  guid = "GtdFImnG15ZS88D2umA1VpOC62Q"
}
