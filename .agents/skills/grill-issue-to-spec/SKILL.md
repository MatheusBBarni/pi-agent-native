---
name: grill-issue-to-spec
description: Run a project issue through grill-with-docs, create an AI-ready specification, update the issue description with the grill document and spec output, and remove Need PRD and Need SPEC labels. Use when the user asks to prepare, grill, specify, or finish an issue by number before implementation.
---

# Grill Issue To Spec

Turn an issue number into an implementation-ready issue by combining three outputs:

1. A completed `grill-with-docs` decision session.
2. A specification created with `create-specification`.
3. An updated issue description containing both artifacts, with `Need PRD` and `Need SPEC` removed.

Load and follow the project `grill-with-docs` skill for the interview/documentation phase. Load and follow the `create-specification` skill for the final spec file.

## Workflow

1. Resolve the target issue number. If the user did not provide one, ask for it.

2. Read the issue from the project issue tracker:
   - title
   - description/body
   - comments
   - current labels/tags
   - linked branches, pull requests, or references if visible

3. Gather repository context before grilling:
   - Read `CONTEXT-MAP.md` or the relevant `CONTEXT.md` files.
   - Read relevant ADRs under `docs/adr/`.
   - Explore code paths related to the issue before asking the user questions.

4. Run the `grill-with-docs` workflow:
   - Ask one question at a time.
   - Provide a recommended answer with every question.
   - Answer questions by codebase exploration when possible instead of asking the user.
   - Challenge unclear terminology against `CONTEXT.md`.
   - Update `CONTEXT.md` inline when domain terms are resolved.
   - Create ADRs only when the `grill-with-docs` criteria justify them.

5. Produce a concise grill document after the session:
   - `Resolved Decisions`
   - `Domain Language Updates`
   - `Codebase Findings`
   - `Constraints`
   - `Out of Scope`
   - `Open Questions` only if any remain
   - `Documentation Changes` listing updated `CONTEXT.md` or ADR files

6. Use `create-specification` to write a spec under `/spec/`:
   - Base it on the issue, codebase findings, grill decisions, and documentation updates.
   - Follow the `create-specification` template and naming convention.
   - Use precise requirements, constraints, interfaces, acceptance criteria, and validation criteria.
   - Keep the spec self-contained enough for another agent to implement from it.

7. Update the issue description/body. Preserve the original issue content unless the user explicitly asks to replace it. Add or refresh these sections:

```markdown
## Grill With Docs

[the grill document]

## Specification

- Spec file: [path/to/spec-file.md]

[the spec content or a concise spec excerpt, depending on issue tracker body limits]
```

If the issue tracker has strict body limits, include the full grill document, the spec path, and a concise spec summary in the issue body.

8. Remove these labels/tags from the issue if present:
   - `Need PRD`
   - `Need SPEC`

Do not remove unrelated labels. Do not close the issue unless the user explicitly asks.

## Completion Criteria

Finish only when all are true:

- The grill session reached shared understanding or explicitly recorded remaining open questions.
- Any resolved domain terms were captured in `CONTEXT.md`.
- Any justified ADRs were created or updated.
- A spec exists in `/spec/` using the required `spec-[a-z0-9-]+.md` naming convention.
- The issue description contains the grill document and spec reference/content.
- `Need PRD` and `Need SPEC` are absent from the issue labels/tags.

If issue tracker access is unavailable, create the grill document and spec locally, then provide the exact issue body replacement and label operations for the user to apply.
