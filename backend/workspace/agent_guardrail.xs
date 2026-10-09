// Jev + Xano: an AI-agent tool-call guardrail. Jev decides; Xano enforces, logs, and routes to humans.
workspace "Agent Guardrail" {
  acceptance = {ai_terms: false}
  preferences = {
    internal_docs    : false
    track_performance: true
    sql_names        : false
    sql_columns      : true
  }
}
