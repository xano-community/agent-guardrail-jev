// Confidence thresholds for the guardrail. Policy is data: edit a row, no redeploy.
table "guard_policy" {
  auth = false
  description = "Confidence thresholds the guardrail applies to Jev's answers. Edit the active row; no redeploy."
  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at? {
      description = "When the thresholds were last changed"
    }

    text name filters=trim {
      description = "Policy name, e.g. default"
    }

    decimal allow_min_confidence?=0.9 {
      description = "Jev must say safe with at least this confidence to run without a human"
    }

    decimal block_min_confidence?=0.9 {
      description = "Jev must say dangerous with at least this confidence to block outright"
    }

    decimal max_destructive?=0.5 {
      description = "Above this probability that the call is destructive, a human always looks"
    }

    decimal min_matches_request?=0.5 {
      description = "Below this probability that the call matches the request, a human always looks"
    }

    bool active?=true {
      description = "Only the active policy is applied"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "active"}]}
  ]
  guid = "GQIAnFiZS2oJRQu97vWS01uDcTA"
}
