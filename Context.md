# R-TRCE Context & Trace Index

This document maps all `@trce-rparse-*` annotations to their source files and locations across the R-TRCE codebase.

---

## 1. Monorepo Layout

```
R Parse/
├── AGENTS.md               # TRCE agent instruction set & rules
├── Context.md              # Trace index and architectural mapping (this file)
├── README.md               # User guide, CLI reference, and examples
├── r_trce.R                # CLI executable router (parse, explain, annotate, check, export, doctor)
├── app.R                   # Companion interactive Shiny studio
├── R/
│   ├── parser.R            # Core AST parsing and token extraction
│   ├── analyzer.R          # Semantic analyzer and archetype recognition
│   ├── annotator.R         # TRCE 6-point annotation generator and code injector
│   ├── validator.R         # Trace integrity and coverage auditing
│   └── explain.R           # Plain text/Markdown explanation and JSON export
└── tests/
    └── test_r_trce.R       # Automated test suite running against synthetic and real R scripts
```

---

## 2. TRCE Trace Index

| Trace ID | Initiating Actor (`who`) | Action / Responsibility (`what`) | File Location (`where`) |
|----------|--------------------------|----------------------------------|-------------------------|
| `trce-rparse-001` | R-TRCE Engine / Parser Subsystem | Parses R source files into concrete syntax trees and token coordinates using base R AST tools | `R/parser.R` (`parse_r_file`) |
| `trce-rparse-002` | R-TRCE Engine / Lexical Subsystem | Extracts comment blocks and associates them with subsequent code expressions | `R/parser.R` (`extract_comments`, `extract_top_expressions`) |
| `trce-rparse-003` | R-TRCE Engine / Semantic Analysis | Analyzes parsed R AST structures to detect architectural patterns, functions, Shiny graphs, schemas, and pipelines | `R/analyzer.R` (`analyze_r_file`, `classify_expression`) |
| `trce-rparse-004` | R-TRCE Engine / Dependency Resolver | Resolves caller-callee relationships across all functions defined within the R file | `R/analyzer.R` (`resolve_dependencies`) |
| `trce-rparse-005` | R-TRCE Engine / Annotation Synthesizer | Synthesizes complete 6-point TRCE annotations tailored to R architectural archetypes | `R/annotator.R` (`generate_annotation`, `generate_file_header`) |
| `trce-rparse-006` | R-TRCE Engine / Code Injection Subsystem | Injects generated TRCE annotation blocks into R source code preserving syntax and formatting | `R/annotator.R` (`inject_annotations`) |
| `trce-rparse-007` | R-TRCE Engine / Validator Subsystem | Validates TRCE annotations for canonical pattern compliance, 6-field completeness, and coverage | `R/validator.R` (`validate_r_annotations`) |
| `trce-rparse-008` | R-TRCE Engine / Architectural Explainer | Generates plain-text and Markdown architectural explanations and TRCE context mappings for R files | `R/explain.R` (`explain_r_file`, `format_markdown_explanation`, `export_trace_json`) |
| `trce-rparse-009` | User / CLI Operator / Automated Agent | Main CLI command router and option parser for the R-TRCE toolchain | `r_trce.R` (`main`) |
| `trce-rparse-010` | Shiny Web Browser Client / Developer | Interactive Shiny UI and Server studio for AST inspection, architecture explanation, and TRCE annotation | `app.R` (`ui`, `server`) |
| `trce-rparse-011` | Test Suite Runner / CI Verifier | Automated test harness verifying AST parsing, semantic analysis, annotation injection, and trace validation | `tests/test_r_trce.R` (`run_all_tests`) |
| `trce-rparse-012` | R-TRCE Engine / Parser Subsystem | Maps AST expressions to line boundaries and associates preceding comment scaffolding | `R/parser.R` (`extract_top_expressions`) |

---

## 3. Telemetry & Cross-System Routing

All `@trce-rparse-*` tags adhere to TRCE Go engine compatibility rules:
- Pattern: `^trce-[a-z0-9]+(?:-[a-z0-9]+)*-[0-9]+$`
- 6 Fields: `@trce-id`, `@trce-who`, `@trce-what`, `@trce-where`, `@trce-when`, `@trce-why`, `@trce-how`
- Comment style: `# /** ... */` (JSDoc format in R) or `#'` (Roxygen format)
- Compatible with TRCE daemon file watchers and `trce check` audits.
