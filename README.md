# R-TRCE: R Code Parser, Semantic Analyzer & TRCE Annotator

A specialized toolchain for parsing R code, understanding its architectural structure and intent, and generating complete 6-point TRCE telemetry annotations (`@trce-*`) to fully explain R codebases.

Built directly on the architectural patterns and lessons from **R Test** (CLI tools, Shiny reactive graphs, star/snowflake schemas, ANOVA models, and data pipelines).

---

## Features

* **100% Native R AST Parsing:** Leverages base R's `parse(keep.source = TRUE)` and `getParseData()` to inspect concrete syntax trees, line coordinates, and comment blocks with zero external C++ dependencies.
* **Semantic Architectural Comprehension:** Automatically classifies R code archetypes:
  - **Shiny Interactive Web Applications:** Detects UI hierarchies (`fluidPage`, `navbarPage`, widgets) and Server reactive graphs (`reactive`, `reactiveVal`, `observeEvent`, `renderPlot`).
  - **Relational Data Architectures & Pipelines:** Identifies snowflake/star schema definitions (`TABLES`, `JOIN_PLAN`), defensive validation checks (`validate_tables`), and lineage flattening routines (`build_analytic`).
  - **Statistical & Modeling Engines:** Recognizes ANOVA variance decompositions, method-of-moments estimators, linear models (`lm`), and confounding guards.
  - **Command-Line Tools:** Recognizes `commandArgs` parsing, `usage()` dispatchers, subcommand routers, and execution guards (`if (!interactive())`).
* **Complete 6-Point TRCE Annotations:** Generates rich doc-comments conforming to TRCE control plane standards:
  1. `@trce-id`: Canonical identifier matching `^trce-[a-z0-9-]+-[0-9]+$`
  2. `@trce-who`: Initiating actor / system component
  3. `@trce-what`: Mechanical action being performed
  4. `@trce-where`: Architectural position and upstream/downstream call graph
  5. `@trce-when`: Lifecycle trigger or event phase
  6. `@trce-why`: Architectural intent and domain problem solved
  7. `@trce-how`: Structural implementation, state mutations, and formulas
* **Student Tutor & Pedagogical Suite:** Tailored specifically for students learning R:
  - **Student Pitfall Sentinel:** Audits code for common beginner traps (`1:length(x)`, `x == NA`, `attach()`, `as.numeric(factor)`, and quadratic `rbind` memory loops).
  - **Data Pipeline Flow Inspector:** Deconstructs multi-stage native (`|>`) and magrittr (`%>%`) pipelines into discrete, human-readable steps.
  - **Statistical Formula Deconstructor:** Translates model formulas (`y ~ x1 + x2 * x3`) into clear statistical explanations of response variables, predictors, and interaction terms.
  - **Comprehension Quiz Generator:** Generates automated self-study multiple-choice questions directly from user code.
* **Non-Destructive Code Injection:** Automatically injects annotations into R source files while preserving existing formatting, author comments, and indentation.
* **Integrity Audit & Coverage:** Audits existing or generated annotations, verifies field completeness, flags duplicate IDs, and reports coverage percentages.
* **Dual Interfaces:** Provides both a Unix-philosophy command-line tool (`r_trce.R`) and an interactive Shiny web dashboard (`app.R` with dedicated 🎓 Student Studio).

---

## ⚡ 1-Minute Quick Install

### 🐧 Linux & 🍏 macOS (One-Line Auto-Installer)
```bash
curl -fsSL https://raw.githubusercontent.com/AsterovLabs/R-TRCE/main/install.sh | bash
```
*Works on all Linux distributions (Ubuntu, Debian, Arch, Fedora, openSUSE, Alpine) and macOS. Creates global `r-trce` and `r-trce-studio` commands.*

### 🪟 Windows 11 & Windows 10 (PowerShell One-Line Auto-Installer)
Open PowerShell (or Windows Terminal) and run:
```powershell
irm https://raw.githubusercontent.com/AsterovLabs/R-TRCE/main/install.ps1 | iex
```
*Auto-detects or installs R via winget, configures `PATH`, adds `r-trce` & `r-trce-studio` commands, and places a desktop shortcut for R-TRCE Studio.*

### 📦 Standalone & Offline Downloads (GitHub Releases)

Pre-packaged bundles are available on the [GitHub Releases](https://github.com/AsterovLabs/R-TRCE/releases) page:

| Operating System | Package Archive | Installation |
| :--- | :--- | :--- |
| **Windows 11 / 10** | [`r-trce-windows-all.zip`](https://github.com/AsterovLabs/R-TRCE/releases/latest) | Extract zip and double-click `install.bat` |
| **Linux (All Distros)** | [`r-trce-linux-all.tar.gz`](https://github.com/AsterovLabs/R-TRCE/releases/latest) | Extract tarball and run `./install.sh` |
| **macOS** | [`r-trce-macos-all.tar.gz`](https://github.com/AsterovLabs/R-TRCE/releases/latest) | Extract tarball and run `./install.sh` |

---

## Setup & Requirements

R version >= 4.0.0 is required. If using the Asterov user environment:

```bash
# Path to environment Rscript:
/home/sam/.r-env/bin/Rscript --version
```

Dependencies (`jsonlite`, `shiny`, `DT`) are pre-installed in `~/.r-env`.

---

## CLI Usage

Run commands with `r_trce.R`:

```bash
# 1. Parse and inspect components of an R script
/home/sam/.r-env/bin/Rscript r_trce.R parse "path/to/script.R"

# 2. Generate a comprehensive architectural explanation
/home/sam/.r-env/bin/Rscript r_trce.R explain "path/to/script.R"
/home/sam/.r-env/bin/Rscript r_trce.R explain "path/to/script.R" --md

# 3. Student tutor walkthrough, package primer & concept decoder
/home/sam/.r-env/bin/Rscript r_trce.R tutor "path/to/script.R"

# 4. Audit beginner traps and copy-on-modify memory bottlenecks
/home/sam/.r-env/bin/Rscript r_trce.R pitfalls "path/to/script.R"

# 5. Generate interactive comprehension quiz or Markdown study worksheet
/home/sam/.r-env/bin/Rscript r_trce.R quiz "path/to/script.R"
/home/sam/.r-env/bin/Rscript r_trce.R quiz "path/to/script.R" --md

# 6. Annotate an R script with TRCE 6-point doc-comments
/home/sam/.r-env/bin/Rscript r_trce.R annotate "path/to/script.R" --out "annotated_script.R"
/home/sam/.r-env/bin/Rscript r_trce.R annotate "path/to/script.R" --inplace

# 7. Audit and check TRCE coverage and integrity
/home/sam/.r-env/bin/Rscript r_trce.R check "path/to/script.R"

# 8. Export trace graph to JSON for TRCE control plane integration
/home/sam/.r-env/bin/Rscript r_trce.R export-traces "path/to/script.R" --out "traces.json"

# 9. Run diagnostics and self-test
/home/sam/.r-env/bin/Rscript r_trce.R doctor
```

---

## Interactive Shiny Studio & Guided Walkthrough

Launch the visual walkthrough studio:

```bash
# Direct runner script:
./start_studio.sh

# Or directly with Rscript:
/home/sam/.r-env/bin/Rscript app.R
```

Open `http://127.0.0.1:8083` in your browser:
* **Tab 1: Guided Walkthrough ("Walk Me Through It"):**
  - Drop or select an R script to start a step-by-step interactive inspection.
  - Review each function, reactive node, and pipeline step one by one.
  - View syntax-highlighted code snippets, architectural dependencies, and caller/callee graphs.
  - Inspect, customize, or accept the generated 6-point TRCE annotations (`@trce-*`) as you go.
  - Actions: `[ Accept & Next ]`, `[ Skip ]`, `[ Previous ]`, `[ Annotate All Immediately ]`.
  - Progress tracker and celebration screen upon 100% completion.
* **Tab 2: Annotated Code & Traces:** Real-time view of your annotated code, TRCE audit validation badge, and download buttons (`.R` and `.json`).
* **Tab 3: Architectural Explanation:** View detected archetype, system narratives, and caller-callee dependency matrices.
* **Tab 4: AST & Parse Tokens:** Raw R AST expression coordinates and lexical token streams.

---

## Verification & Testing

Execute the automated test suite:

```bash
/home/sam/.r-env/bin/Rscript tests/test_r_trce.R
```

Verifies parser fidelity, dependency resolution, annotation synthesis, code injection idempotency, and 100% TRCE coverage against real scripts from `R Test` (`data_entry_viz.R`, `complex/R/star.R`, `complex/R/variance.R`, `complex/R/schema.R`, `app.R`).

---

## 📄 License & Proprietary Rights

Copyright © 2026 Asterov Labs. All Rights Reserved.

Licensed under the **Asterov Labs Proprietary Software License**.
* Permitted: Personal, educational, classroom instruction, and academic non-commercial study.
* Prohibited: Unauthorized commercial distribution, hosting as a paid service, reverse engineering for commercial derivation, or sublicensing without written permission.

See [`LICENSE`](LICENSE) for complete legal terms.

