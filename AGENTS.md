# R-TRCE — Agent Instruction Set

R-TRCE is an architectural analysis, AST comprehension, and TRCE annotation engine specifically designed for R language projects. It extracts semantic intent from R scripts, maps internal and external dependency graphs, and generates complete 6-point TRCE telemetry doc-comments (`@trce-*`).

---

## 1. Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| CLI Entrypoint | `r_trce.R` | Subcommand router (`parse`, `explain`, `annotate`, `check`, `export-traces`, `doctor`) |
| Interactive Studio | `app.R` | Shiny webapp for visual AST inspection, dependency graphs, and live annotation |
| Core AST Parser | `R/parser.R` | AST extraction, token mapping, and comment association using base R `parse()` & `getParseData()` |
| Semantic Analyzer | `R/analyzer.R` | Archetype detection (Shiny UI/server, snowflake schemas, ANOVA models, CLI runners), call graph |
| Annotation Synthesizer | `R/annotator.R` | 6-point TRCE metadata formulation and non-destructive code injection engine |
| Trace Validator | `R/validator.R` | Audits pattern compliance (`^trce-[a-z0-9-]+-[0-9]+$`), 6-field completeness, and coverage |
| Explainer & Exporter | `R/explain.R` | Generates plain text/Markdown architectural narratives and TRCE JSON export |
| Automated Test Suite | `tests/test_r_trce.R` | Comprehensive functional verification across synthetic and real-world R Test scripts |

**Language Environment:** R (version >= 4.0.0, default: `/home/sam/.r-env/bin/Rscript`).
**External Dependencies:** Standard R library + `jsonlite`, `shiny` (for `app.R` studio).

---

## 2. Agent Workflow Protocol

Every session working in this repository must follow this context loop:

1. **Read `AGENTS.md`** (this file) — authoritative instructions.
2. **Read `Context.md`** — review trace index and monorepo layout.
3. **Verify traces** — ensure code changes map to existing `@trce-rparse-*` tags or introduce new sequential IDs.
4. **Implement changes** — maintain full 6-point TRCE annotations on all functional blocks.
5. **Update `Context.md`** — immediately index new trace pathways.
6. **Run Verification** — execute:
   ```bash
   /home/sam/.r-env/bin/Rscript tests/test_r_trce.R
   /home/sam/.r-env/bin/Rscript r_trce.R doctor
   ```

---

## 3. TRCE Annotation Standard in R

Every major functional block or module must include a standardized doc-comment block:

```r
# /**
#  * @trce-id trce-<namespace>-<NNN>
#  * @trce-who <initiating actor, agent tier, or system component>
#  * @trce-what <concrete mechanical action being performed>
#  * @trce-where <position in architecture + upstream/downstream dependencies>
#  * @trce-when <lifecycle hook, event trigger, or temporal condition>
#  * @trce-why <architectural intent, business rule, or problem solved>
#  * @trce-how <structural implementation, state mutations, formula routing>
#  */
```

---

## 4. CLI Command Reference

| Command | Description |
|---------|-------------|
| `Rscript r_trce.R parse <file>` | Parse R code AST and display identified components |
| `Rscript r_trce.R explain <file> [--md]` | Output architectural explanation and dependency breakdown |
| `Rscript r_trce.R annotate <file> [opts]` | Synthesize and inject TRCE doc-comments (`--inplace`, `--out`, `--style`) |
| `Rscript r_trce.R check <file>` | Validate TRCE annotations (pattern, 6 fields, duplicate check, coverage) |
| `Rscript r_trce.R export-traces <file>` | Export trace graph to TRCE control plane JSON |
| `Rscript r_trce.R doctor` | Run environment diagnostics and self-test verification |
