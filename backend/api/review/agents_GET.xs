// The registered agents. Keys are never returned here — only when an agent is created or its key rotated.
query "agents" verb=GET {
  api_group = "Review"
  description = "List registered agents (keys are not returned)."
  auth = "user"
  input {
  }

  stack {
    db.query "guard_agent" {
      description = "All registered agents"
      sort = {name: "asc"}
      return = {type: "list"}
      output = ["id", "created_at", "name", "description", "active"]
    } as $agents
  }

  response = $agents
  guid = "feyR77JmD5PBLLmx3pj4Gfek5xc"
}
