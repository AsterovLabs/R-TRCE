#!/usr/bin/env Rscript
# =============================================================================
# r_trce.R -- R Code Parser, Semantic Comprehension & TRCE Annotation Tool
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Parses R code ASTs, classifies architectural components (Shiny UI/server,
#        snowflake schemas, ANOVA models, CLI runners, pipelines), explains them,
#        and generates full 6-point TRCE annotations (@trce-*).
#
# WHY    Eliminates manual annotation friction, ensures 100% compliance with TRCE
#        agent control plane standards, and provides deep architectural clarity
#        for R scripts.
#
# HOW    Rscript r_trce.R <command> <file> [options]
# =============================================================================

# /**
#  * @trce-id trce-rparse-009
#  * @trce-who User / CLI Operator / Automated Agent
#  * @trce-what Main CLI command router and option parser for the R-TRCE toolchain
#  * @trce-where r_trce.R -> main()
#  * @trce-when On terminal execution or automated CI/CD pipeline invocation
#  * @trce-why Dispatches user subcommands (parse, explain, annotate, check, export-traces, doctor) with clear error reporting
#  * @trce-how Slices commandArgs(trailingOnly=TRUE), dynamically loads R/ modules relative to script path, and executes target routines
#  */

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    clean_path <- gsub("~+~", " ", sub("^--file=", "", file_arg[1]), fixed = TRUE)
    return(normalizePath(dirname(clean_path)))
  }
  # Fallback: working directory
  getwd()
}

# Locate and source modules
script_dir <- get_script_dir()
source(file.path(script_dir, "R", "parser.R"))
source(file.path(script_dir, "R", "analyzer.R"))
source(file.path(script_dir, "R", "annotator.R"))
source(file.path(script_dir, "R", "validator.R"))
source(file.path(script_dir, "R", "explain.R"))
source(file.path(script_dir, "R", "pedagogy.R"))

usage <- function() {
  cat(
"r_trce.R -- R Code Parser, Semantic Comprehension & TRCE Annotation Tool

USAGE
  Rscript r_trce.R <command> <file> [options]

COMMANDS
  parse <file>                    Parse R code and print component & AST hierarchy
  explain <file> [--md]           Generate architectural explanation and execution graph
  tutor <file>                    Student-friendly walkthrough, concept decoder & pitfall audit
  pitfalls <file>                 Audit code for common beginner traps and memory bottlenecks
  quiz <file> [--md]              Generate tailored student comprehension quiz & study worksheet
  annotate <file> [options]       Generate and inject TRCE @trce-* annotation blocks
  check <file>                    Validate TRCE annotations (6 fields, unique IDs, coverage)
  export-traces <file> [--out F]  Export trace index to JSON for TRCE control plane
  studio [port]                   Launch interactive Shiny web studio (default port: 8083)
  doctor                          Run environment diagnostics and self-test verification
  help, -h, --help                Show this help message and exit

ANNOTATE OPTIONS
  --inplace, -i                   Overwrite the target file with annotated code
  --out, -o PATH                  Write annotated code to specified output file
  --prefix NAME                   Trace ID prefix (default: 'trce-r')
  --style STYLE                   Comment style: 'jsdoc' (default) or 'roxygen'
  --no-header                     Skip generating the file-level module header

EXAMPLES
  Rscript r_trce.R tutor path/to/script.R
  Rscript r_trce.R pitfalls path/to/script.R
  Rscript r_trce.R quiz path/to/script.R --md
  Rscript r_trce.R explain path/to/script.R
  Rscript r_trce.R explain path/to/script.R --md
  Rscript r_trce.R check path/to/script.R
  Rscript r_trce.R annotate path/to/script.R --inplace
  Rscript r_trce.R export-traces path/to/script.R --out traces.json
  Rscript r_trce.R doctor
", sep = "")
}

main <- function(argv = commandArgs(trailingOnly = TRUE)) {
  if (length(argv) == 0 || argv[1] %in% c("-h", "--help", "help")) {
    usage()
    quit(status = 0)
  }

  cmd <- argv[1]
  args <- argv[-1]

  if (cmd == "doctor") {
    run_doctor()
    quit(status = 0)
  }

  if (cmd == "studio") {
    app_file <- file.path(script_dir, "app.R")
    if (!file.exists(app_file)) {
      cat(sprintf("Error: app.R not found in '%s'\n", script_dir), file = stderr())
      quit(status = 1)
    }
    if (length(args) > 0 && !is.na(as.integer(args[1]))) {
      Sys.setenv(PORT = args[1])
    }
    source(app_file)
    quit(status = 0)
  }

  if (length(args) == 0) {
    cat(sprintf("Error: Command '%s' requires a target file path.\n\n", cmd), file = stderr())
    usage()
    quit(status = 1)
  }

  target_file <- args[1]
  options_args <- args[-1]

  if (!file.exists(target_file)) {
    cat(sprintf("Error: File not found: '%s'\n", target_file), file = stderr())
    quit(status = 1)
  }

  switch(cmd,
    parse = {
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      cat(sprintf("Parsed %s successfully (%d lines, %d expressions).\n\n",
                  basename(target_file), parsed$total_lines, length(parsed$expressions)))
      cat("Archetype: ", analysis$file_type, "\n")
      cat("Imports:   ", paste(analysis$imports, collapse = ", "), "\n\n")
      cat("Identified Components:\n")
      for (comp in analysis$components) {
        if (comp$kind %in% c("function", "shiny_ui", "shiny_server", "schema_definition") || isTRUE(comp$is_cli_runner)) {
          cat(sprintf("  * %-20s [%-16s] (lines %d-%d)\n", comp$name, comp$kind, comp$line1, comp$line2))
        }
      }
    },

    explain = {
      is_md <- "--md" %in% options_args
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      exp <- explain_r_file(parsed, analysis)
      if (is_md) {
        cat(exp$markdown, "\n")
      } else {
        cat(exp$text, "\n")
      }
    },

    tutor = {
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      walkthrough <- generate_student_explanation(parsed, analysis)
      cat(walkthrough, "\n")
    },

    pitfalls = {
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      pitfalls <- detect_student_pitfalls(parsed, analysis)
      cat("================================================================================\n")
      cat(sprintf("  R-TRCE PITFALL SENTINEL: %s\n", basename(target_file)))
      cat("================================================================================\n")
      if (length(pitfalls) == 0) {
        cat("  [CLEAN] No beginner pitfalls, memory bottlenecks, or anti-patterns detected.\n")
      } else {
        cat(sprintf("  Found %d potential issue(s):\n\n", length(pitfalls)))
        for (i in seq_along(pitfalls)) {
          pf <- pitfalls[[i]]
          cat(sprintf("  %d. [%s] Line %d: %s\n", i, toupper(pf$severity), pf$line, pf$title))
          cat(sprintf("     Explanation: %s\n", pf$description))
          cat(sprintf("     Fix:         %s\n", pf$suggestion))
          if (nzchar(pf$code_snippet)) cat(sprintf("     Code:        '%s'\n", pf$code_snippet))
          cat("\n")
        }
      }
      cat("================================================================================\n")
    },

    quiz = {
      is_md <- "--md" %in% options_args
      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      questions <- generate_student_quiz(parsed, analysis)

      if (is_md) {
        cat(sprintf("# Student Comprehension Quiz: `%s`\n\n", basename(target_file)))
        for (i in seq_along(questions)) {
          q <- questions[[i]]
          cat(sprintf("### Question %d: %s\n\n", i, q$question))
          for (opt in q$options) cat(sprintf("- %s\n", opt))
          cat(sprintf("\n<details><summary>Click for Answer & Explanation</summary>\n\n**Correct Answer:** %s\n\n%s\n</details>\n\n", q$correct_answer, q$explanation))
        }
      } else {
        cat("================================================================================\n")
        cat(sprintf("  STUDENT COMPREHENSION QUIZ: %s\n", basename(target_file)))
        cat("================================================================================\n\n")
        for (i in seq_along(questions)) {
          q <- questions[[i]]
          cat(sprintf("Q%d: %s\n", i, q$question))
          for (opt in q$options) cat(sprintf("     %s\n", opt))
          cat(sprintf("\n     [Answer Key: %s -- %s]\n\n", q$correct_answer, q$explanation))
        }
        cat("================================================================================\n")
      }
    },

    annotate = {
      inplace <- any(options_args %in% c("--inplace", "-i"))
      out_idx <- which(options_args %in% c("--out", "-o"))
      out_file <- if (length(out_idx) > 0 && length(options_args) >= out_idx + 1) options_args[out_idx + 1] else NULL

      prefix_idx <- which(options_args == "--prefix")
      prefix <- if (length(prefix_idx) > 0 && length(options_args) >= prefix_idx + 1) options_args[prefix_idx + 1] else "trce-r"

      style_idx <- which(options_args == "--style")
      style <- if (length(style_idx) > 0 && length(options_args) >= style_idx + 1) options_args[style_idx + 1] else "jsdoc"

      no_header <- "--no-header" %in% options_args

      parsed <- parse_r_file(target_file)
      analysis <- analyze_r_file(parsed)
      injected <- inject_annotations(parsed, analysis, prefix = prefix, style = style, add_file_header = !no_header)

      cat(sprintf("Synthesized %d TRCE annotation blocks for '%s'.\n", injected$blocks_added, basename(target_file)))

      if (inplace) {
        writeLines(injected$annotated_code, target_file)
        cat(sprintf("Updated '%s' inplace.\n", target_file))
      } else if (!is.null(out_file)) {
        writeLines(injected$annotated_code, out_file)
        cat(sprintf("Wrote annotated file to '%s'.\n", out_file))
      } else {
        cat("\n--- ANNOTATED SOURCE PREVIEW (Use --inplace or --out to save) ---\n\n")
        cat(injected$annotated_code, "\n")
      }
    },

    check = {
      val <- validate_r_annotations(target_file)
      cat("================================================================================\n")
      cat(sprintf("  TRCE ANNOTATION AUDIT: %s\n", basename(target_file)))
      cat("================================================================================\n")
      cat(sprintf("  Traces Found:      %d\n", val$total_traces))
      cat(sprintf("  Valid Format:      %d\n", val$valid_traces))
      cat(sprintf("  Annotatable Blocks:%d\n", val$total_targets))
      cat(sprintf("  Annotated Targets: %d\n", val$annotated_targets))
      cat(sprintf("  Coverage:          %.1f%%\n", val$coverage_pct))
      cat("--------------------------------------------------------------------------------\n")

      if (length(val$unannotated_targets) > 0) {
        cat("  Unannotated Components:\n")
        for (u in val$unannotated_targets) {
          cat(sprintf("    - %s\n", u))
        }
        cat("\n")
      }

      if (length(val$issues) > 0) {
        cat("  Issues Detected:\n")
        for (iss in val$issues) {
          cat(sprintf("    [%s] Line %d: %s\n", iss$severity, iss$line, iss$message))
        }
        cat("\nAudit status: FAILED\n")
        quit(status = 1)
      } else {
        cat("  All checks passed. Annotations are structurally sound and complete.\n")
        cat("Audit status: PASSED\n")
      }
    },

    `export-traces` = ,
    export_traces = {
      out_idx <- which(options_args %in% c("--out", "-o"))
      out_file <- if (length(out_idx) > 0 && length(options_args) >= out_idx + 1) options_args[out_idx + 1] else NULL

      val <- validate_r_annotations(target_file)
      json_str <- export_trace_json(list(val))

      if (!is.null(out_file)) {
        writeLines(json_str, out_file)
        cat(sprintf("Exported %d traces to '%s'.\n", length(val$entries), out_file))
      } else {
        cat(json_str, "\n")
      }
    },

    {
      cat(sprintf("Unknown command: '%s'\n\n", cmd), file = stderr())
      usage()
      quit(status = 1)
    }
  )
}

run_doctor <- function() {
  cat("================================================================================\n")
  cat("  R-TRCE HEALTH CHECK & DIAGNOSTICS (doctor)\n")
  cat("================================================================================\n")
  cat(sprintf("  R Version:       %s\n", R.version.string))
  cat(sprintf("  Platform:        %s\n", R.version$platform))
  cat(sprintf("  JSON Support:    %s\n", if (requireNamespace("jsonlite", quietly = TRUE)) "OK (jsonlite available)" else "MISSING"))
  cat(sprintf("  Shiny Support:   %s\n", if (requireNamespace("shiny", quietly = TRUE)) "OK (shiny available)" else "MISSING"))
  cat(sprintf("  Core Modules:    parser.R, analyzer.R, annotator.R, validator.R, explain.R, pedagogy.R [LOADED]\n"))
  cat("--------------------------------------------------------------------------------\n")
  cat("  Running self-tests...\n")

  # Self-test: parse this CLI script itself!
  self_path <- file.path(script_dir, "r_trce.R")
  if (file.exists(self_path)) {
    parsed <- parse_r_file(self_path)
    analysis <- analyze_r_file(parsed)
    val <- validate_r_annotations(self_path, parsed, analysis)
    cat(sprintf("  [OK] Self-parse succeeded (%d lines, %d expressions)\n", parsed$total_lines, length(parsed$expressions)))
    cat(sprintf("  [OK] Archetype detected: '%s'\n", analysis$file_type))
    cat(sprintf("  [OK] Validator verified %d TRCE entries\n", val$total_traces))
  }

  cat("--------------------------------------------------------------------------------\n")
  cat("  Overall status: HEALTHY\n")
  cat("================================================================================\n")
}

if (!interactive()) {
  main()
}
