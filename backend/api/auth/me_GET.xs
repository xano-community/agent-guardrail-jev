// The signed-in reviewer's profile.
query "me" verb=GET {
  api_group = "Auth"
  description = "Return the signed-in reviewer's profile."
  auth = "user"
  input {
  }

  stack {
    db.get "user" {
      description = "Load the signed-in reviewer"
      field_name = "id"
      field_value = $auth.id
    } as $user
  }

  response = {id: $user.id, name: $user.name, email: $user.email}
  guid = "pM17LsVUylMIBLiQxNY6ejtJKqA"
}
