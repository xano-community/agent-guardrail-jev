// Ask Jev (TypeSafe AI's System One model) three typed questions about a proposed tool call.
// Jev returns typed answers with probabilities, never text. Xano times the call and reports
// failures instead of throwing, so the caller can fail closed.
// API contract: https://docs.typesafe.ai/api.md (POST /v1/systemone, Bearer auth, Choice + Noul answers).
function "jev/decide" {
  description = "Ask Jev whether a proposed agent tool call is safe, destructive, and on-request; never throws."
  input {
    text agent {
      description = "Name of the agent proposing the call"
    }

    text user_request {
      description = "What the end user asked the agent for"
    }

    text tool {
      description = "Tool the agent wants to run"
    }

    json arguments? {
      description = "Arguments the agent wants to pass"
    }
  }

  stack {
    group {
      description = "Build the System One request: the state plus three typed questions"
      stack {
        var $payload {
          description = "Request body per https://docs.typesafe.ai/api.md: state, model, and a map of questions"
          value = {
            model    : "jev-latest"
            state    : {
              agent             : $input.agent
              user_request      : $input.user_request
              proposed_tool_call: {tool: $input.tool, arguments: $input.arguments}
            }
            questions: {
              verdict        : {
                type        : "choice"
                instructions: "An AI agent wants to run this tool call on the user's behalf. Should it run without a human checking it first?"
                criteria    : {
                  safe        : "Read-only or low-impact, and clearly what the user asked for"
                  needs_review: "Changes records, moves money or contacts people, or the request is ambiguous"
                  dangerous   : "Destructive, bulk or irreversible, sends data outside the company, or is not what the user asked for"
                }
              }
              destructive    : {
                type        : "noul"
                instructions: "The tool call deletes, overwrites or bulk-changes data, or moves money or data outside the company"
              }
              matches_request: {
                type        : "noul"
                instructions: "The tool call is what the user actually asked the agent to do"
              }
            }
          }
        }

        var $api_key {
          description = "Jev API key from the workspace environment (mocked in unit tests)"
          value = $env.JEV_API_KEY
          mock = {
            "jev decide maps a documented safe answer"     : "test-key"
            "jev decide maps a documented dangerous answer": "test-key"
            "jev decide fails closed on a 401"             : "test-key"
            "jev decide fails closed when overloaded"      : "test-key"
            "jev decide fails closed without an api key"   : ""
          }
        }
      }
    }

    group {
      description = "Initialise the result so a failed call still returns a well-formed answer"
      stack {
        var $t0 {
          description = "Start time, to measure Jev latency"
          value = "now"|to_ms
        }

        var $ok {
          description = "True only when Jev answered with HTTP 200"
          value = false
        }

        var $status {
          description = "HTTP status Jev returned (0 when not called or unreachable)"
          value = 0
        }

        var $jev_error {
          description = "Plain-language reason Jev could not answer, for reviewers"
          value = null
        }

        var $result {
          description = "Jev's response body"
          value = {}
        }
      }
    }

    // No key configured: don't call Jev at all — the caller fails closed to human review.
    conditional {
      if ($api_key == null || $api_key == "") {
        var.update $jev_error {
          description = "Explain that the integration isn't configured yet"
          value = "Jev isn't configured yet (JEV_API_KEY is not set)"
        }
      }

      else {
        try_catch {
          description = "Call Jev; a network failure is caught and reported, never thrown"
          try {
            api.request {
              description = "POST the state and questions to Jev's System One endpoint"
              url = "https://api.typesafe.ai/v1/systemone"
              method = "POST"
              params = $payload
              headers = [
                "Content-Type: application/json"
                "Authorization: Bearer " ~ $api_key
              ]
              timeout = 10
              mock = {
                "jev decide maps a documented safe answer"     : {
                  response: {
                    status: 200
                    result: {
                      model  : "jev-1.13.0"
                      answers: {
                        verdict        : {
                          type         : "choice"
                          choice       : "safe"
                          probabilities: {safe: 0.96, needs_review: 0.04, dangerous: 0.0}
                          confidence   : 0.93
                        }
                        destructive    : {type: "noul", noul: 0.02}
                        matches_request: {type: "noul", noul: 0.97}
                      }
                      usage  : {input_tokens: 318, output_tokens: 34}
                    }
                  }
                }
                "jev decide maps a documented dangerous answer": {
                  response: {
                    status: 200
                    result: {
                      model  : "jev-1.13.0"
                      answers: {
                        verdict        : {
                          type         : "choice"
                          choice       : "dangerous"
                          probabilities: {safe: 0.01, needs_review: 0.07, dangerous: 0.92}
                          confidence   : 0.88
                        }
                        destructive    : {type: "noul", noul: 0.95}
                        matches_request: {type: "noul", noul: 0.04}
                      }
                      usage  : {input_tokens: 341, output_tokens: 34}
                    }
                  }
                }
                "jev decide fails closed on a 401"             : {response: {status: 401, result: {}}}
                "jev decide fails closed when overloaded"      : {response: {status: 529, result: {}}}
              }
            } as $jev

            var.update $status {
              description = "Record the HTTP status Jev returned"
              value = $jev.response.status
            }

            var.update $result {
              description = "Keep the response body"
              value = $jev.response.result
            }
          }

          catch {
            var.update $jev_error {
              description = "Jev could not be reached (network error or timeout)"
              value = "Jev could not be reached (network error or timeout)"
            }
          }
        }
      }
    }

    // Translate Jev's documented status codes into a reviewer-friendly reason.
    conditional {
      if ($status == 200) {
        var.update $ok {
          description = "Jev answered"
          value = true
        }
      }

      elseif ($status == 401) {
        var.update $jev_error {
          description = "Documented 401: missing or invalid API key"
          value = "Jev rejected the API key — check JEV_API_KEY"
        }
      }

      elseif ($status == 422) {
        var.update $jev_error {
          description = "Documented 422: request failed validation"
          value = "Jev could not read this tool call (request failed validation)"
        }
      }

      elseif ($status == 429 || $status == 529) {
        var.update $jev_error {
          description = "Documented 429/529: rate limited or overloaded"
          value = "Jev is busy right now (rate limited or overloaded)"
        }
      }

      elseif ($status != 0) {
        var.update $jev_error {
          description = "Any other non-200 status"
          value = "Jev returned an unexpected error"
        }
      }
    }

    group {
      description = "Pull the typed answers out of the response; missing answers stay null instead of erroring"
      stack {
        var $answers {
          description = "Answers keyed by question id (empty when Jev did not answer)"
          value = ($ok ? ($result|get:"answers":{}) : {})
        }

        var $verdict {
          description = "The verdict Choice answer"
          value = $answers|get:"verdict":{}
        }

        var $destructive {
          description = "The destructive Noul answer"
          value = $answers|get:"destructive":{}
        }

        var $matches {
          description = "The matches_request Noul answer"
          value = $answers|get:"matches_request":{}
        }

        var $usage {
          description = "Token usage Jev reported"
          value = ($ok ? ($result|get:"usage":{}) : {})
        }

        var $latency_ms {
          description = "Round-trip time of the Jev call"
          value = ("now"|to_ms) - $t0
        }
      }
    }
  }

  response = {
    ok             : $ok
    http_status    : $status
    error          : $jev_error
    latency_ms     : $latency_ms
    model          : ($ok ? ($result|get:"model":"jev-latest") : null)
    verdict        : $verdict|get:"choice":null
    confidence     : $verdict|get:"confidence":null
    probabilities  : $verdict|get:"probabilities":null
    destructive    : $destructive|get:"noul":null
    matches_request: $matches|get:"noul":null
    input_tokens   : $usage|get:"input_tokens":null
  }

  test "jev decide maps a documented safe answer" {
    input = {
      agent       : "support-agent"
      user_request: "Where is my order #1042?"
      tool        : "orders.lookup"
      arguments   : {order_id: 1042}
    }

    expect.to_be_true ($response.ok)
    expect.to_equal ($response.verdict) {
      value = "safe"
    }

    expect.to_equal ($response.confidence) {
      value = 0.93
    }

    expect.to_equal ($response.destructive) {
      value = 0.02
    }

    expect.to_equal ($response.model) {
      value = "jev-1.13.0"
    }

    expect.to_equal ($response.input_tokens) {
      value = 318
    }
  }

  test "jev decide maps a documented dangerous answer" {
    input = {
      agent       : "support-agent"
      user_request: "Where is my order?"
      tool        : "customers.export"
      arguments   : {fields: ["email"], destination: "https://paste.example.net/upload"}
    }

    expect.to_equal ($response.verdict) {
      value = "dangerous"
    }

    expect.to_equal ($response.matches_request) {
      value = 0.04
    }
  }

  test "jev decide fails closed on a 401" {
    input = {
      agent       : "support-agent"
      user_request: "Where is my order?"
      tool        : "orders.lookup"
    }

    expect.to_be_false ($response.ok)
    expect.to_be_null ($response.verdict)
    expect.to_equal ($response.error) {
      value = "Jev rejected the API key — check JEV_API_KEY"
    }
  }

  test "jev decide fails closed when overloaded" {
    input = {
      agent       : "support-agent"
      user_request: "Where is my order?"
      tool        : "orders.lookup"
    }

    expect.to_be_false ($response.ok)
    expect.to_equal ($response.http_status) {
      value = 529
    }
  }

  test "jev decide fails closed without an api key" {
    input = {
      agent       : "support-agent"
      user_request: "Where is my order?"
      tool        : "orders.lookup"
    }

    expect.to_be_false ($response.ok)
    expect.to_equal ($response.http_status) {
      value = 0
    }
  }

  history = 100
  guid = "uZqBmVn8y9ZsmNf21sbX22rsOcQ"
}
