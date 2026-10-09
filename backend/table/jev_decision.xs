// One row per Jev call: the typed answers, the confidence, the latency and the route Xano chose.
// Over time this is a labeled dataset of real agent decisions.
table "jev_decision" {
  auth = false
  description = "One row per Jev evaluation: typed answers, confidence, latency, and the route Xano chose."
  schema {
    int id
    timestamp created_at?=now
    int tool_call_id? {
      table = "tool_call"
      description = "The tool call this decision is about"
    }

    text model? {
      description = "Model version Jev reported, e.g. jev-1.13.0 (seed-demo for seeded rows)"
    }

    text verdict? {
      description = "Jev's choice: safe | needs_review | dangerous"
    }

    decimal confidence? {
      description = "Jev's confidence in the verdict, 0 to 1"
    }

    json probabilities? {
      description = "Probability of each verdict option"
    }

    decimal destructive? {
      description = "Noul: probability the call is destructive"
    }

    decimal matches_request? {
      description = "Noul: probability the call is what the user asked for"
    }

    int latency_ms? {
      description = "Round-trip time of the Jev call in milliseconds"
    }

    int input_tokens? {
      description = "Input tokens Jev reported"
    }

    bool jev_ok?=true {
      description = "False when Jev could not be reached or returned an error"
    }

    int http_status? {
      description = "HTTP status Jev returned (0 when it was not reached)"
    }

    enum route? {
      description = "Route Xano chose: auto_allow | auto_block | human_review"
      values = ["auto_allow", "auto_block", "human_review"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "tool_call_id"}]}
    {type: "btree", field: [{name: "route"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
  guid = "8UB46cRmJA7SwJUpVWPJhGBcl-c"
}
