#!/usr/bin/env Rscript
# =============================================================================
# test_r_trce.R -- Automated Verification Suite for R-TRCE
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Executes comprehensive regression and functional tests across all R-TRCE
#        modules, verifying parser fidelity, semantic analysis, annotation
#        synthesis, code injection, and validation using corpus from R Test.
#
# WHY    Guarantees correctness, syntactic preservation, and 100% compliance with
#        TRCE control plane standards.
#
# HOW    Rscript tests/test_r_trce.R
# =============================================================================

# /**
#  * @trce-id trce-rparse-011
#  * @trce-who Test Suite Runner / CI Verifier
#  * @trce-what Automated test harness verifying AST parsing, semantic analysis, annotation injection, and trace validation
#  * @trce-where tests/test_r_trce.R -> run_all_tests()
#  * @trce-when Invoked during development validation and pre-commit checks
#  * @trce-why Ensures zero regressions and structural fidelity across all R code archetypes
#  * @trce-how Executes sequential assertion blocks against real-world scripts from R Test and reports pass/fail counts
#  */

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    clean_path <- gsub("~+~", " ", sub("^--file=", "", file_arg[1]), fixed = TRUE)
    return(normalizePath(dirname(clean_path)))
  }
  getwd()
}

tests_dir <- get_script_dir()
root_dir <- dirname(tests_dir)

source(file.path(root_dir, "R", "parser.R"))
source(file.path(root_dir, "R", "analyzer.R"))
source(file.path(root_dir, "R", "annotator.R"))
source(file.path(root_dir, "R", "validator.R"))
source(file.path(root_dir, "R", "explain.R"))
source(file.path(root_dir, "R", "pedagogy.R"))

# Test harness helpers
pass_count <- 0
fail_count <- 0

assert <- function(desc, condition) {
  if (isTRUE(condition)) {
    cat(sprintf("  [PASS] %s\n", desc))
    pass_count <<- pass_count + 1
  } else {
    cat(sprintf("  [FAIL] %s\n", desc))
    fail_count <<- fail_count + 1
  }
}

cat("================================================================================\n")
cat("  R-TRCE AUTOMATED TEST SUITE\n")
cat("================================================================================\n\n")

# ------------------------------------------------------------------------------
# Test 1: Parser unit tests
# ------------------------------------------------------------------------------
cat("--- 1. Testing Core Parser (R/parser.R) ---\n")

dummy_code <- "
# Leading comment for helper
add_two <- function(x) {
  x + 2
}

multiply <- function(a, b = 10) {
  add_two(a) * b
}
"
dummy_file <- tempfile(fileext = ".R")
writeLines(dummy_code, dummy_file)

parsed <- parse_r_file(dummy_file)
assert("Parser reads and parses synthetic R code", length(parsed$expressions) == 2)
assert("Parser extracts line numbers correctly", parsed$expressions[[1]]$line1 == 3)
assert("Parser extracts preceding comments", length(parsed$expressions[[1]]$preceding_comments) > 0)
assert("Parse data tokens extracted", nrow(parsed$parse_data) > 0)

# ------------------------------------------------------------------------------
# Test 2: Semantic Analyzer unit tests
# ------------------------------------------------------------------------------
cat("\n--- 2. Testing Semantic Analyzer (R/analyzer.R) ---\n")

analysis <- analyze_r_file(parsed)
assert("Defined functions detected correctly", setequal(analysis$defined_functions, c("add_two", "multiply")))
assert("multiply calls add_two locally", "add_two" %in% analysis$components[[2]]$calls_local)
assert("add_two called_by contains multiply", "multiply" %in% analysis$components[[1]]$called_by)

# ------------------------------------------------------------------------------
# Test 3: Annotation Synthesizer & Code Injector (R/annotator.R)
# ------------------------------------------------------------------------------
cat("\n--- 3. Testing Annotation Synthesizer & Injector (R/annotator.R) ---\n")

inj <- inject_annotations(parsed, analysis, prefix = "trce-test", style = "jsdoc", add_file_header = TRUE)
assert("Annotations synthesized for functions and header", inj$blocks_added == 3)

annotated_temp <- tempfile(fileext = ".R")
writeLines(inj$annotated_code, annotated_temp)

# Syntax check on annotated file
annotated_ast <- tryCatch(parse(annotated_temp), error = function(e) NULL)
assert("Annotated code preserves 100% valid R syntax", !is.null(annotated_ast))

# Test idempotency: re-annotating should add 0 new blocks
parsed2 <- parse_r_file(annotated_temp)
analysis2 <- analyze_r_file(parsed2)
inj2 <- inject_annotations(parsed2, analysis2, prefix = "trce-test")
assert("Annotation injection is idempotent (blocks_added == 0 on re-run)", inj2$blocks_added == 0)

# ------------------------------------------------------------------------------
# Test 4: Validator (R/validator.R)
# ------------------------------------------------------------------------------
cat("\n--- 4. Testing Trace Validator (R/validator.R) ---\n")

val <- validate_r_annotations(annotated_temp, parsed2, analysis2)
assert("Validation detects all generated traces", val$total_traces == 3)
assert("Validation confirms 100% valid ID pattern", val$valid_traces == 3)
assert("Validation reports 100% component coverage", val$coverage_pct == 100.0)
assert("Validation reports clean status with no issues", val$is_clean == TRUE)

# ------------------------------------------------------------------------------
# Test 5: Real-World Corpus Verification from R Test
# ------------------------------------------------------------------------------
cat("\n--- 5. Testing Against Real-World Files from R Test ---\n")

r_test_root <- file.path(dirname(root_dir), "R Test")
test_targets <- c(
  "data_entry_viz.R",
  "app.R",
  file.path("complex", "R", "star.R"),
  file.path("complex", "R", "variance.R"),
  file.path("complex", "R", "schema.R")
)

for (rel in test_targets) {
  full_path <- file.path(r_test_root, rel)
  if (!file.exists(full_path)) {
    cat(sprintf("  [SKIP] '%s' not found\n", rel))
    next
  }

  p <- parse_r_file(full_path)
  a <- analyze_r_file(p)
  inj <- inject_annotations(p, a, prefix = "trce-corpus")
  
  tmp_out <- tempfile(fileext = ".R")
  writeLines(inj$annotated_code, tmp_out)

  # Check that annotated output is valid syntax
  chk_ast <- tryCatch(parse(tmp_out), error = function(e) NULL)
  assert(sprintf("Real file '%s' parses and re-parses with valid syntax", basename(rel)), !is.null(chk_ast))

  # Check validation
  p_ann <- parse_r_file(tmp_out)
  a_ann <- analyze_r_file(p_ann)
  val_ann <- validate_r_annotations(tmp_out, p_ann, a_ann)
  assert(sprintf("Real file '%s' achieves 100%% TRCE coverage (%d traces)", basename(rel), val_ann$total_traces),
         val_ann$coverage_pct == 100.0)

  unlink(tmp_out)
}

# ------------------------------------------------------------------------------
cat("\n--- 6. Testing Pedagogical Engine & Student Tutor (R/pedagogy.R) ---\n")

# Synthetic code with student traps
bad_code <- "
bad_func <- function(x, df) {
  res <- c()
  for (i in 1:length(x)) {
    if (x[i] == NA) next
    res <- c(res, x[i])
  }
  attach(df)
  num <- as.numeric(factor_var)
  global_state <<- res
  res
}
"
bad_tmp <- tempfile(fileext = ".R")
writeLines(bad_code, bad_tmp)
p_bad <- parse_r_file(bad_tmp)
a_bad <- analyze_r_file(p_bad)
pf_list <- detect_student_pitfalls(p_bad, a_bad)
unlink(bad_tmp)

assert("Pitfall Sentinel flags 1:length(x)", any(sapply(pf_list, function(x) x$type == "empty_vector_colon")))
assert("Pitfall Sentinel flags == NA comparison", any(sapply(pf_list, function(x) x$type == "na_equality_check")))
assert("Pitfall Sentinel flags attach()", any(sapply(pf_list, function(x) x$type == "attach_usage")))
assert("Pitfall Sentinel flags factor to numeric conversion", any(sapply(pf_list, function(x) x$type == "factor_to_numeric")))
assert("Pitfall Sentinel flags global <<- assignment", any(sapply(pf_list, function(x) x$type == "super_assignment")))

# Test pipeline deconstruction
pipe_code <- "
library(dplyr)
transform_data <- function(df) {
  df |>
    filter(val > 10) |>
    mutate(status = 'active') |>
    summarise(total = sum(val))
}
"
pipe_tmp <- tempfile(fileext = ".R")
writeLines(pipe_code, pipe_tmp)
p_pipe <- parse_r_file(pipe_tmp)
pipes <- deconstruct_pipes(p_pipe)
unlink(pipe_tmp)

assert("Pipeline deconstructor identifies pipeline with 3 stages", length(pipes) >= 1 && length(pipes[[1]]$stages) == 3)
assert("Pipeline deconstructor identifies filter, mutate, summarise",
       all(c("filter", "mutate", "summarise") %in% sapply(pipes[[1]]$stages, function(s) s$fn)))

# Test formula deconstruction
stat_code <- "
fit_model <- function(df) {
  lm(y ~ x1 + x2 * x3, data = df)
}
"
stat_tmp <- tempfile(fileext = ".R")
writeLines(stat_code, stat_tmp)
p_stat <- parse_r_file(stat_tmp)
formulas <- deconstruct_formulas(p_stat)
unlink(stat_tmp)

assert("Formula deconstructor detects formula", length(formulas) >= 1)
assert("Formula deconstructor extracts response variable 'y'", formulas[[1]]$response_variable == "y")
assert("Formula deconstructor detects interaction terms", isTRUE(formulas[[1]]$has_interaction))

# Test student quiz generator
quiz <- generate_student_quiz(p_stat, analyze_r_file(p_stat))
assert("Quiz generator synthesizes comprehension questions", length(quiz) >= 3)
assert("Quiz question 1 has question, options, and correct answer",
       !is.null(quiz[[1]]$question) && length(quiz[[1]]$options) >= 2 && !is.null(quiz[[1]]$correct_answer))

# Test student explanation output
tutor_text <- generate_student_explanation(p_stat, analyze_r_file(p_stat))
assert("Student explanation generates comprehensive text walkthrough",
       grepl("STUDENT TUTOR", tutor_text) && grepl("PACKAGE TOOLKIT", tutor_text) && grepl("TRCE RUBRIC", tutor_text))

# ------------------------------------------------------------------------------
# Test Summary
# ------------------------------------------------------------------------------
cat("\n================================================================================\n")
cat(sprintf("  TEST RESULTS: %d PASSED, %d FAILED\n", pass_count, fail_count))
cat("================================================================================\n")

unlink(dummy_file)
unlink(annotated_temp)

if (fail_count > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
