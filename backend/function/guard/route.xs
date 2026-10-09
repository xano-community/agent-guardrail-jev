// The harness rule. Pure logic, no I/O: given Jev's typed answers and the active policy, decide
// whether the tool call runs, is blocked, or waits for a human. Anything uncertain, destructive or
// off-request goes to a person. If Jev is unreachable, the guardrail fails closed.
function "guard/route" {
  description = "Pure routing rule: map Jev's answers plus policy thresholds to auto_allow, auto_block, or human_review."
  input {
    bool jev_ok {
      description = "Whether Jev answered"
    }

    text? jev_error? {
      description = "Why Jev could not answer, when jev_ok is false"
    }

    text? verdict? {
      description = "Jev's choice: safe | needs_review | dangerous"
    }

    decimal? confidence? {
      description = "Jev's confidence in the verdict"
    }

    decimal? destructive? {
      description = "Probability the call is destructive"
    }

    decimal? matches_request? {
      description = "Probability the call is what the user asked for"
    }

    decimal allow_min_confidence?=0.9 {
      description = "Minimum confidence to auto-allow a safe verdict"
    }

    decimal block_min_confidence?=0.9 {
      description = "Minimum confidence to auto-block a dangerous verdict"
    }

    decimal max_destructive?=0.5 {
      description = "Destructive probability at or above which a human must look"
    }

    decimal min_matches_request?=0.5 {
      description = "Matches-request probability below which a human must look"
    }
  }

  stack {
    group {
      description = "Defaults (a human looks) and the policy risk flags"
      stack {
        var $route {
          description = "Default route: a human looks"
          value = "human_review"
        }

        var $reason {
          description = "Default reason, used when Jev answered but was not confident"
          value = "Jev was not confident enough to decide on its own"
        }

        var $is_destructive {
          description = "Destructive probability is unknown or at/above the policy limit"
          value = $input.destructive == null || $input.destructive >= $input.max_destructive
        }

        var $is_off_request {
          description = "Matches-request probability is unknown or below the policy floor"
          value = $input.matches_request == null || $input.matches_request < $input.min_matches_request
        }
      }
    }

    // First matching rule wins; anything not matched stays with a human.
    conditional {
      if ($input.jev_ok == false) {
        var.update $reason {
          description = "Fail closed when Jev is unavailable"
          value = "Jev was unavailable, so the guardrail failed closed" ~ ($input.jev_error == null ? "" : ": " ~ $input.jev_error)
        }
      }

      elseif ($input.verdict == "dangerous" && $input.confidence != null && $input.confidence >= $input.block_min_confidence) {
        var.update $route {
          description = "Confidently dangerous: block"
          value = "auto_block"
        }

        var.update $reason {
          description = "Explain the block"
          value = "Jev judged this call dangerous"
        }
      }

      elseif ($input.verdict == "safe" && $input.confidence != null && $input.confidence >= $input.allow_min_confidence && $is_destructive == false && $is_off_request == false) {
        var.update $route {
          description = "Confidently safe, not destructive, on-request: allow"
          value = "auto_allow"
        }

        var.update $reason {
          description = "Explain the allow"
          value = "Jev judged this call safe"
        }
      }

      elseif ($input.verdict == "safe" && $input.confidence != null && $input.confidence >= $input.allow_min_confidence) {
        var.update $reason {
          description = "Safe verdict overridden by the destructive / off-request checks"
          value = "Jev said safe, but the call looks destructive or is not what the user asked for"
        }
      }

      elseif ($input.verdict == "needs_review") {
        var.update $reason {
          description = "Jev asked for a human"
          value = "Jev flagged this call for human review"
        }
      }
    }
  }

  response = {route: $route, reason: $reason}

  test "route allows a confident safe call" {
    input = {
      jev_ok         : true
      verdict        : "safe"
      confidence     : 0.97
      destructive    : 0.02
      matches_request: 0.98
    }

    expect.to_equal ($response.route) {
      value = "auto_allow"
    }
  }

  test "route blocks a confident dangerous call" {
    input = {
      jev_ok         : true
      verdict        : "dangerous"
      confidence     : 0.95
      destructive    : 0.9
      matches_request: 0.05
    }

    expect.to_equal ($response.route) {
      value = "auto_block"
    }
  }

  test "route sends an uncertain call to a human" {
    input = {
      jev_ok         : true
      verdict        : "safe"
      confidence     : 0.71
      destructive    : 0.1
      matches_request: 0.9
    }

    expect.to_equal ($response.route) {
      value = "human_review"
    }
  }

  test "route sends a safe but destructive call to a human" {
    input = {
      jev_ok         : true
      verdict        : "safe"
      confidence     : 0.96
      destructive    : 0.8
      matches_request: 0.9
    }

    expect.to_equal ($response.route) {
      value = "human_review"
    }
  }

  test "route sends a safe but off-request call to a human" {
    input = {
      jev_ok         : true
      verdict        : "safe"
      confidence     : 0.96
      destructive    : 0.05
      matches_request: 0.2
    }

    expect.to_equal ($response.route) {
      value = "human_review"
    }
  }

  test "route does not block an unconfident dangerous call" {
    input = {
      jev_ok         : true
      verdict        : "dangerous"
      confidence     : 0.6
      destructive    : 0.7
      matches_request: 0.3
    }

    expect.to_equal ($response.route) {
      value = "human_review"
    }
  }

  test "route honors a stricter policy threshold" {
    input = {
      jev_ok              : true
      verdict             : "safe"
      confidence          : 0.93
      destructive         : 0.02
      matches_request     : 0.98
      allow_min_confidence: 0.95
    }

    expect.to_equal ($response.route) {
      value = "human_review"
    }
  }

  test "route sends a safe call with unknown destructiveness to a human" {
    input = {
      jev_ok         : true
      verdict        : "safe"
      confidence     : 0.97
      matches_request: 0.98
    }

    expect.to_equal ($response.route) {
      value = "human_review"
    }
  }

  test "route fails closed when jev is down" {
    input = {jev_ok: false, jev_error: "Jev is busy right now (rate limited or overloaded)"}
    expect.to_equal ($response.route) {
      value = "human_review"
    }

    expect.to_equal ($response.reason) {
      value = "Jev was unavailable, so the guardrail failed closed: Jev is busy right now (rate limited or overloaded)"
    }
  }

  history = 100
  guid = "kabZS8OEsVwNzrQYcobXmNYJLjs"
}
