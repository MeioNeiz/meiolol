---
title: Writing effective tools for agents, with agents (Anthropic, 2025)
url: https://www.anthropic.com/engineering/writing-tools-for-agents
kind: article
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (whole post; example images not in snapshot)
relevance: high
grade: B/fair
description: Anthropic engineering post (Sep 2025) on designing agent tools: few consolidated tools, high-signal output, concise/detailed formats, truncation with steering, actionable errors, tool evals
---
# Writing effective tools for agents, with agents (Anthropic, 2025)

Why: what tool output shape, error messages and token budgets make an agent use its
tools well; for the commands the meiolol lab agent calls (lab-run, lab-exp, RESULT).

## Assessment

- Evidence: B. Vendor's own practice, refined against internal tool evals with
  held-out sets (Slack, Asana tools); charts not in the snapshot, no numbers in text
  except 25,000-token cap and a ~1/3 token saving.
- Reasoning: fair. Explains why (limited context, agent affordances), admits format
  effects vary by model and should be measured.
- Interests: vendor (MCP, Claude Code).
- Weigh: trust the principles; formats (JSON vs Markdown vs XML) are explicitly
  "measure yourself".

## Findings

- [lab] More tools are not better; wrapping every API endpoint wastes context. Build a
  few tools for high-impact workflows. ^f1
  > More tools don’t always lead to better outcomes.
  > We recommend building a few thoughtful tools targeting specific high-impact workflows
- [lab] Consolidate chained steps into one tool: search_logs returning relevant lines
  instead of read_logs; get_customer_context compiling everything at once. ^f2
  > Instead of implementing a `read_logs` tool, consider implementing a `search_logs` tool which only returns relevant log lines and some surrounding context.
  > implement a `get_customer_context` tool which compiles all of a customer’s recent & relevant information all at once
- [lab] Return only high-signal fields; replacing opaque UUIDs with meaningful names or
  even 0-indexed ids significantly improved precision and reduced hallucination. ^f3
  > tool implementations should take care to return only high signal information back to agents
  > merely resolving arbitrary alphanumeric UUIDs to more semantically meaningful and interpretable language (or even a 0-indexed ID scheme) significantly improves Claude’s precision in retrieval tasks by reducing hallucinations
- [lab] A response_format parameter (concise or detailed) lets the agent pick verbosity;
  concise used about a third of the tokens in their Slack example. ^f4
  > exposing a simple `response_format` enum parameter in your tool, allowing your agent to control whether tools return `“concise”` or `“detailed”` responses
  > we use ~⅓ of the tokens with `“concise”` tool responses
- [lab] Paginate, filter, range-select or truncate large outputs with sensible defaults;
  Claude Code caps tool responses at 25,000 tokens; truncation should tell the agent
  how to narrow. ^f5
  > We suggest implementing some combination of pagination, range selection, filtering, and/or truncation with sensible default parameter values
  > For Claude Code, we restrict tool responses to 25,000 tokens by default.
  > If you choose to truncate responses, be sure to steer agents with helpful instructions.
- [lab] Error responses should state specific, actionable fixes, not opaque codes or
  tracebacks. ^f6
  > prompt-engineer your error responses to clearly communicate specific and actionable improvements, rather than opaque error codes or tracebacks
- [lab] Tool descriptions matter most: unambiguous parameter names (user_id not user);
  precise description edits took Sonnet 3.5 to state of the art on SWE-bench Verified. ^f7
  > instead of a parameter named `user`, try a parameter named `user_id`
  > Claude Sonnet 3.5 achieved state-of-the-art performance on the [SWE-bench Verified](https://www.anthropic.com/engineering/swe-bench-sonnet) evaluation after we made precise refinements to tool descriptions
- [lab] Measure tool use itself: runtime per call, number of calls, tokens, tool errors;
  many redundant calls point to pagination or limits, many invalid-parameter errors to
  unclear descriptions. ^f8
  > the total runtime of individual tool calls and tasks, the total number of tool calls, the total token consumption, and tool errors
  > Lots of redundant tool calls might suggest some rightsizing of pagination or token limit parameters is warranted
- [lab] Read raw transcripts, not just the agent's own feedback: what agents omit
  often matters more than what they say. ^f9
  > what agents omit in their feedback and responses can often be more important than what they include
- [lab] (inferred) For meiolol: a `lab show <run>` / `lab compare a b` that compiles a
  run's meta, metrics and diff into one short answer fits "consolidate"; run ids
  should be short readable names, not hashes; lab-run errors should say what to change
  (e.g. "binary stale, run zig build lab"). ^f10

## Read

- Whole post text; the example tool responses and charts are images, not in snapshot.

## Not read

- Tool evaluation cookbook (platform.claude.com/cookbook/tool-evaluation-tool-evaluation).
