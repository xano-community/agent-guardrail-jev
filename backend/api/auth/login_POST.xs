// Log a reviewer in with email + password and return a 24h auth token.
query "login" verb=POST {
  api_group = "Auth"
  description = "Log a reviewer in with email and password; returns a 24h auth token."
  input {
    email email filters=trim|lower {
      description = "Login email"
    }

    text password {
      description = "Login password"
      sensitive = true
    }
  }

  stack {
    db.get "user" {
      description = "Look up the reviewer by email"
      field_name = "email"
      field_value = $input.email
    } as $user

    // Unknown email: same message as a wrong password, so emails can't be probed
    precondition ($user != null) {
      error_type = "accessdenied"
      error = "That email and password don't match. Please try again."
    }

    security.check_password {
      text_password = $input.password
      hash_password = $user.password
    } as $ok

    // Wrong password
    precondition ($ok) {
      error_type = "accessdenied"
      error = "That email and password don't match. Please try again."
    }

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
  guid = "VpOWTzb0AF9AX179eoYiP0Oemeo"
}
