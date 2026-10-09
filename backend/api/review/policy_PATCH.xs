// Change the thresholds. Policy is data: the next tool call uses the new values, no redeploy.
query "policy" verb=PATCH {
  api_group = "Review"
  description = "Update the active policy thresholds (each between 0 and 1); creates the default policy if none exists."
  auth = "user"
  input {
    decimal? allow_min_confidence? filters=min:0|max:1 {
      description = "Minimum confidence to auto-allow a safe verdict"
    }

    decimal? block_min_confidence? filters=min:0|max:1 {
      description = "Minimum confidence to auto-block a dangerous verdict"
    }

    decimal? max_destructive? filters=min:0|max:1 {
      description = "Destructive probability at or above which a human must look"
    }

    decimal? min_matches_request? filters=min:0|max:1 {
      description = "Matches-request probability below which a human must look"
    }
  }

  stack {
    db.query "guard_policy" {
      description = "Load the active policy"
      where = $db.guard_policy.active == true
      sort = {id: "desc"}
      return = {type: "single"}
    } as $policy

    // No policy yet (fresh workspace, not seeded): create the default one first
    conditional {
      if ($policy == null) {
        db.add "guard_policy" {
          description = "Create the default policy"
          data = {name: "default", active: true}
        } as $policy
      }
    }

    var $updates {
      description = "Only the thresholds that were sent"
      value = {updated_at: now}
        |set_ifnotnull:"allow_min_confidence":$input.allow_min_confidence
        |set_ifnotnull:"block_min_confidence":$input.block_min_confidence
        |set_ifnotnull:"max_destructive":$input.max_destructive
        |set_ifnotnull:"min_matches_request":$input.min_matches_request
    }

    db.patch "guard_policy" {
      description = "Save the new thresholds"
      field_name = "id"
      field_value = $policy.id
      data = $updates
    } as $updated
  }

  response = $updated
  guid = "0t_RFr4CeCEaM016h8VcScSKJ8U"
}
