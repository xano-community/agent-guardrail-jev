// The thresholds the guardrail applies right now.
query "policy" verb=GET {
  api_group = "Review"
  description = "Return the active policy thresholds."
  auth = "user"
  input {
  }

  stack {
    db.query "guard_policy" {
      description = "Load the active policy"
      where = $db.guard_policy.active == true
      sort = {id: "desc"}
      return = {type: "single"}
    } as $policy
  }

  response = $policy
  guid = "fHDqCE2U_n3aAoCBIefyJXBKeVg"
}
