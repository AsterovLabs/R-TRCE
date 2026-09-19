#!/usr/bin/env Rscript
# =============================================================================
# app.R -- Interactive Shiny Studio & Guided Walkthrough for R-TRCE
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================
# WHAT   Interactive web dashboard to upload or drop an R file, walk through
#        its architecture step-by-step, review functions and reactive nodes,
#        and synthesize & inject 6-point TRCE annotations as you go.
#
# WHY    Makes understanding and documenting complex R codebases intuitive,
#        educational, and zero-friction for any developer or data scientist.
#
# HOW    Rscript app.R           (auto-launches on http://127.0.0.1:8083)
#        or: Rscript -e 'shiny::runApp("app.R", port = 8083)'
# =============================================================================

# /**
#  * @trce-id trce-rparse-010
#  * @trce-who Shiny Web Browser Client / Developer
#  * @trce-what Interactive Shiny UI and Server studio with guided walkthrough mode for step-by-step TRCE annotation
#  * @trce-where app.R -> ui & server
#  * @trce-when On HTTP request and WebSocket initialization
#  * @trce-why Enables zero-friction, interactive exploration of R ASTs, call graphs, and live step-by-step TRCE annotation
#  * @trce-how Binds reactive code inputs to parser.R, analyzer.R, annotator.R, and validator.R, displaying interactive steppers and diffs
#  */

# Verify and load Shiny
if (!requireNamespace("shiny", quietly = TRUE)) {
  message("\n==================================================================")
  message("  R-TRCE Studio requires the 'shiny' package.")
  message("  Attempting to install 'shiny' automatically into user library...")
  message("==================================================================\n")

  user_lib <- Sys.getenv("R_LIBS_USER")
  if (is.null(user_lib) || user_lib == "") {
    user_lib <- file.path(Sys.getenv("HOME"), "R", "library")
  }
  if (!dir.exists(user_lib)) {
    dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
  }
  .libPaths(unique(c(user_lib, .libPaths())))

  installed_ok <- tryCatch({
    install.packages("shiny", lib = user_lib, repos = "https://cloud.r-project.org", quiet = FALSE)
    requireNamespace("shiny", quietly = TRUE)
  }, error = function(e) {
    FALSE
  })

  if (!installed_ok) {
    cat("\n[!] Error: Unable to automatically install 'shiny'.\n\n", file = stderr())
    cat("Please install Shiny manually using one of the following methods:\n\n", file = stderr())
    cat("  Option 1 (Inside R):\n", file = stderr())
    cat("    install.packages('shiny', repos='https://cloud.r-project.org')\n\n", file = stderr())
    cat("  Option 2 (Debian / Ubuntu / Chromebook Crostini terminal):\n", file = stderr())
    cat("    sudo apt update && sudo apt install -y r-cran-shiny\n\n", file = stderr())
    stop("Package 'shiny' is required to launch R-TRCE Studio.", call. = FALSE)
  }
  message("\n[OK] 'shiny' installed successfully!\n")
}

suppressPackageStartupMessages({
  library(shiny)
})

# Locate script directory cleanly
script_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    clean_path <- gsub("~+~", " ", sub("^--file=", "", file_arg[1]), fixed = TRUE)
    normalizePath(dirname(clean_path))
  } else {
    getwd()
  }
}, error = function(e) getwd())

source(file.path(script_dir, "R", "parser.R"))
source(file.path(script_dir, "R", "analyzer.R"))
source(file.path(script_dir, "R", "annotator.R"))
source(file.path(script_dir, "R", "validator.R"))
source(file.path(script_dir, "R", "explain.R"))
source(file.path(script_dir, "R", "pedagogy.R"))

# Find available sample files from R Test if accessible
r_test_dir <- file.path(dirname(script_dir), "R Test")
sample_files <- list()
if (dir.exists(r_test_dir)) {
  all_r_files <- list.files(r_test_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  for (f in all_r_files) {
    rel <- sub(paste0("^", normalizePath(r_test_dir), "/?"), "", normalizePath(f))
    sample_files[[rel]] <- f
  }
}

# Default sample code
DEFAULT_CODE <- "# =============================================================================
# sample_pipeline.R -- Hand-entered data loader & variance summary
# =============================================================================

retype_column <- function(x, type) {
  switch(type,
    integer = suppressWarnings(as.integer(x)),
    numeric = suppressWarnings(as.numeric(x)),
    as.character(x)
  )
}

load_clean_data <- function(file_path) {
  if (!file.exists(file_path)) stop('File not found')
  df <- read.csv(file_path, stringsAsFactors = FALSE)
  df$score <- retype_column(df$score, 'numeric')
  df
}

summarize_variance <- function(df, group_col, val_col) {
  aov_fit <- aov(df[[val_col]] ~ df[[group_col]])
  summary(aov_fit)
}
"

# --- UI DEFINITION ---
ui <- fluidPage(
  title = "R-TRCE Studio & Walkthrough",
  theme = NULL,

  tags$head(
    tags$style(HTML("
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; color: #1e293b; }
      .header-bar { background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%); color: white; padding: 22px 32px; margin-bottom: 24px; border-radius: 0 0 12px 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
      .header-bar h1 { margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px; display: flex; align-items: center; gap: 10px; }
      .header-bar p { margin: 6px 0 0; color: #94a3b8; font-size: 14px; }
      .card { background: white; border-radius: 8px; border: 1px solid #e2e8f0; padding: 20px; margin-bottom: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
      .badge-success { background: #10b981; color: white; padding: 5px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; }
      .badge-info { background: #3b82f6; color: white; padding: 5px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; }
      .badge-warning { background: #f59e0b; color: white; padding: 5px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; }
      .badge-secondary { background: #64748b; color: white; padding: 5px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; }
      pre.code-view { background: #0f172a; color: #e2e8f0; padding: 16px; border-radius: 6px; font-size: 13px; max-height: 480px; overflow-y: auto; font-family: 'JetBrains Mono', 'Fira Code', Menlo, Consolas, monospace; line-height: 1.5; }
      .progress-bar-container { background: #e2e8f0; border-radius: 8px; height: 12px; width: 100%; overflow: hidden; margin: 12px 0 18px; }
      .progress-bar-fill { background: linear-gradient(90deg, #3b82f6 0%, #10b981 100%); height: 100%; transition: width 0.3s ease; }
      .step-counter { font-size: 14px; font-weight: 600; color: #475569; }
      .component-title { font-size: 20px; font-weight: 700; color: #0f172a; margin-bottom: 4px; }
      .btn-walkthrough { margin-right: 8px; font-weight: 600; padding: 8px 16px; }
      .field-label { font-size: 12px; font-weight: 700; color: #475569; margin-top: 8px; text-transform: uppercase; letter-spacing: 0.5px; }
      .table { font-size: 13px; }
    "))
  ),

  div(class = "header-bar",
    h1("R-TRCE Studio & Guided Walkthrough"),
    p("Drop or select an R file to inspect its architecture, understand every component, and add TRCE annotations as you go.")
  ),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      div(class = "card",
        h4("Source R File"),
        fileInput("file_upload", "Drop or Upload .R File:", accept = c(".R", ".r"), buttonLabel = "Browse...", placeholder = "No file chosen"),
        if (length(sample_files) > 0) {
          selectInput("sample_select", "Or Load from R Test:",
                      choices = c("--- Choose sample ---" = "", sample_files),
                      selected = "")
        },
        actionButton("btn_reset_sample", "Reset to Default Sample", class = "btn-default btn-xs", style = "margin-bottom: 15px;"),
        hr(),
        h4("Annotation Settings"),
        textInput("trce_prefix", "Trace ID Prefix:", value = "trce-r"),
        selectInput("trce_style", "Annotation Style:", choices = c("JSDoc (# /** ... */)" = "jsdoc", "Roxygen (#' ...)" = "roxygen")),
        checkboxInput("inc_header", "Include File-Level Header", value = TRUE),
        hr(),
        h4("Batch Actions"),
        actionButton("btn_batch_annotate", "Annotate All Immediately", class = "btn-primary btn-block", style = "width: 100%; font-weight: 600;"),
        p(style = "color: #64748b; font-size: 11px; margin-top: 6px;", "Or use the 'Interactive Walkthrough' tab to step through and approve each component.")
      )
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs",

        # --- TAB 1: GUIDED WALKTHROUGH ---
        tabPanel("Guided Walkthrough",
          br(),
          uiOutput("walkthrough_container")
        ),

        # --- TAB 2: LIVE CODE & TRACES ---
        tabPanel("Annotated Code & Traces",
          br(),
          div(class = "card",
            div(style = "display: flex; justify-content: space-between; align-items: center;",
              h4("Working Source Code"),
              div(
                downloadButton("download_r", "Download .R", class = "btn-success btn-sm"),
                downloadButton("download_json", "Download TRCE JSON", class = "btn-info btn-sm")
              )
            ),
            hr(),
            uiOutput("audit_status_banner"),
            br(),
            uiOutput("code_view_ui")
          ),
          div(class = "card",
            h4("Current Trace Index"),
            tableOutput("trace_index_table")
          )
        ),

        # --- TAB 3: ARCHITECTURE & CALL GRAPH ---
        tabPanel("Architectural Explanation",
          br(),
          div(class = "card",
            h4("System Narrative & Invariants"),
            uiOutput("explanation_ui")
          ),
          div(class = "card",
            h4("Component Inventory & Dependency Adjacency"),
            tableOutput("components_table")
          )
        ),

        # --- TAB 4: RAW AST & PARSE DATA ---
        tabPanel("AST & Parse Tokens",
          br(),
          div(class = "card",
            h4("Top-Level AST Expressions"),
            tableOutput("ast_expressions_table"),
            hr(),
            h4("Lexical Token Stream (First 20 tokens)"),
            tableOutput("parse_data_table")
          )
        ),

        # --- TAB 5: STUDENT STUDIO & LEARNING SUITE ---
        tabPanel("🎓 Student Studio",
          br(),
          tabsetPanel(
            id = "student_subtabs",
            tabPanel("Pitfall Sentinel",
              br(),
              uiOutput("student_pitfalls_ui")
            ),
            tabPanel("Concept Decoder & Packages",
              br(),
              uiOutput("student_concepts_ui")
            ),
            tabPanel("Data Pipelines & Formulas",
              br(),
              uiOutput("student_pipelines_ui")
            ),
            tabPanel("Self-Study Quiz",
              br(),
              uiOutput("student_quiz_ui")
            )
          )
        )
      )
    )
  )
)

# --- SERVER LOGIC ---
server <- function(input, output, session) {

  # Source code state
  initial_code <- reactiveVal(DEFAULT_CODE)
  working_code <- reactiveVal(DEFAULT_CODE)
  active_filename <- reactiveVal("sample_pipeline.R")

  # Walkthrough navigation state
  step_index <- reactiveVal(1L)
  completed_walkthrough <- reactiveVal(FALSE)

  # Observer for sample selection
  observeEvent(input$sample_select, {
    req(input$sample_select)
    if (file.exists(input$sample_select)) {
      lines <- readLines(input$sample_select, warn = FALSE)
      txt <- paste(lines, collapse = "\n")
      initial_code(txt)
      working_code(txt)
      active_filename(basename(input$sample_select))
      step_index(1L)
      completed_walkthrough(FALSE)
    }
  })

  # Observer for file upload
  observeEvent(input$file_upload, {
    req(input$file_upload)
    lines <- readLines(input$file_upload$datapath, warn = FALSE)
    txt <- paste(lines, collapse = "\n")
    initial_code(txt)
    working_code(txt)
    active_filename(input$file_upload$name)
    step_index(1L)
    completed_walkthrough(FALSE)
  })

  # Reset to default sample
  observeEvent(input$btn_reset_sample, {
    initial_code(DEFAULT_CODE)
    working_code(DEFAULT_CODE)
    active_filename("sample_pipeline.R")
    step_index(1L)
    completed_walkthrough(FALSE)
  })

  # Parsed object of working code
  parsed_data <- reactive({
    code <- working_code()
    tmp <- tempfile(fileext = ".R")
    writeLines(code, tmp)
    on.exit(unlink(tmp))

    tryCatch({
      p <- parse_r_file(tmp)
      p$file_name <- active_filename()
      p$file_path <- active_filename()
      p
    }, error = function(e) {
      NULL
    })
  })

  # Semantic analysis of working code
  analysis_data <- reactive({
    p <- parsed_data()
    req(p)
    analyze_r_file(p)
  })

  # Validation data of working code
  validation_data <- reactive({
    p <- parsed_data()
    a <- analysis_data()
    req(p, a)
    validate_r_annotations(p$file_path, p, a)
  })

  # Extract list of annotatable components
  annotatable_targets <- reactive({
    a <- analysis_data()
    req(a)
    targets <- list()
    for (comp in a$components) {
      if (comp$kind %in% c("function", "shiny_ui", "shiny_server", "schema_definition") || isTRUE(comp$is_cli_runner)) {
        targets[[length(targets) + 1L]] <- comp
      }
    }
    targets
  })

  # --- BATCH ANNOTATE BUTTON ---
  observeEvent(input$btn_batch_annotate, {
    p <- parsed_data()
    a <- analysis_data()
    req(p, a)

    inj <- inject_annotations(
      p, a,
      prefix = input$trce_prefix %||% "trce-r",
      style = input$trce_style,
      add_file_header = isTRUE(input$inc_header)
    )
    working_code(inj$annotated_code)
    completed_walkthrough(TRUE)
    showNotification(sprintf("Batch annotation complete! Added %d TRCE blocks.", inj$blocks_added), type = "message")
    updateTabsetPanel(session, "main_tabs", selected = "Annotated Code & Traces")
  })

  # --- WALKTHROUGH ACTIONS ---

  # Accept & Next
  observeEvent(input$btn_accept_step, {
    targets <- annotatable_targets()
    curr <- step_index()
    if (curr > length(targets)) return()

    comp <- targets[[curr]]
    lines <- strsplit(working_code(), "\n")[[1]]

    # Formulate annotation block from current editable fields
    block <- format_trce_block(
      id = input$step_id %||% sprintf("%s-%03d", input$trce_prefix, curr),
      who = input$step_who %||% "System Component",
      what = input$step_what %||% "Component implementation",
      where = input$step_where %||% active_filename(),
      when = input$step_when %||% "On invocation",
      why = input$step_why %||% "Architectural documentation",
      how = input$step_how %||% "Implementation handles logic",
      style = input$trce_style %||% "jsdoc"
    )

    new_lines <- inject_single_block(lines, comp$line1, block)
    working_code(paste(new_lines, collapse = "\n"))

    if (curr >= length(targets)) {
      completed_walkthrough(TRUE)
      showNotification("Walkthrough complete! All components annotated.", type = "message")
    } else {
      step_index(curr + 1L)
    }
  })

  # Skip step
  observeEvent(input$btn_skip_step, {
    targets <- annotatable_targets()
    curr <- step_index()
    if (curr >= length(targets)) {
      completed_walkthrough(TRUE)
    } else {
      step_index(curr + 1L)
    }
  })

  # Previous step
  observeEvent(input$btn_prev_step, {
    curr <- step_index()
    if (curr > 1) {
      step_index(curr - 1L)
      completed_walkthrough(FALSE)
    }
  })

  # Reset walkthrough
  observeEvent(input$btn_reset_walkthrough, {
    working_code(initial_code())
    step_index(1L)
    completed_walkthrough(FALSE)
    showNotification("Reset code to initial unannotated state.", type = "warning")
  })

  # --- RENDER WALKTHROUGH UI ---
  output$walkthrough_container <- renderUI({
    targets <- annotatable_targets()
    a <- analysis_data()
    v <- validation_data()
    req(targets, a, v)

    total_steps <- length(targets)

    if (total_steps == 0) {
      return(div(class = "card",
        h3("No Annotatable Components Found"),
        p("The uploaded R file contains no top-level functions, Shiny bindings, or schemas to annotate.")
      ))
    }

    # Completed screen
    if (isTRUE(completed_walkthrough()) || (v$coverage_pct == 100.0 && total_steps > 0)) {
      return(div(class = "card", style = "text-align: center; padding: 40px;",
        tags$div(style = "font-size: 48px; margin-bottom: 12px;", "🎉"),
        h2("File Walkthrough & Annotation Complete!"),
        p(style = "font-size: 16px; color: #475569; max-width: 600px; margin: 0 auto 20px;",
          sprintf("All %d components in '%s' have been reviewed. The file now achieves 100%% TRCE coverage with %d valid traces.",
                  total_steps, active_filename(), v$total_traces)),
        div(style = "display: flex; gap: 12px; justify-content: center; margin-bottom: 24px;",
          downloadButton("download_r_walkthrough", "Download Annotated .R File", class = "btn-success btn-lg"),
          downloadButton("download_json_walkthrough", "Download TRCE JSON", class = "btn-info btn-lg"),
          actionButton("btn_reset_walkthrough", "Start Over", class = "btn-default btn-lg")
        ),
        hr(),
        h4("Final Trace Scaffolding"),
        tableOutput("trace_index_table")
      ))
    }

    # Active walkthrough step
    curr <- min(step_index(), total_steps)
    comp <- targets[[curr]]

    # Compute default proposed annotation values for this component
    auto_id <- sprintf("%s-%03d", input$trce_prefix %||% "trce-r", curr)
    auto_who <- determine_who(comp)
    auto_what <- determine_what(comp)
    auto_where <- determine_where(comp, active_filename())
    auto_when <- determine_when(comp)
    auto_why <- determine_why(comp)
    auto_how <- determine_how(comp)

    # Progress percentage
    pct <- round(((curr - 1) / total_steps) * 100)

    div(
      div(class = "card",
        div(style = "display: flex; justify-content: space-between; align-items: center;",
          div(
            span(class = "step-counter", sprintf("COMPONENT %d OF %d", curr, total_steps)),
            h3(class = "component-title", comp$name),
            span(class = "badge-info", if (comp$kind == "function") comp$archetype else comp$kind),
            " ",
            span(class = "badge-secondary", sprintf("Lines %d–%d", comp$line1, comp$line2))
          ),
          div(
            actionButton("btn_reset_walkthrough", "Reset", class = "btn-default btn-sm")
          )
        ),

        div(class = "progress-bar-container",
          div(class = "progress-bar-fill", style = sprintf("width: %d%%;", pct))
        ),

        fluidRow(
          column(6,
            h5(style = "font-weight: 700; color: #334155;", "Component Source Code:"),
            tags$pre(class = "code-view", comp$code),
            br(),
            h5(style = "font-weight: 700; color: #334155;", "Architectural Context:"),
            tags$ul(style = "font-size: 13px; color: #475569;",
              tags$li(strong("Parameters: "), if (length(comp$args) > 0) paste(comp$args, collapse = ", ") else "none"),
              tags$li(strong("Calls Internal Routines: "), if (length(comp$calls_local) > 0) paste(comp$calls_local, collapse = ", ") else "none"),
              tags$li(strong("Called By: "), if (length(comp$called_by) > 0) paste(comp$called_by, collapse = ", ") else "top-level entrypoint"),
              tags$li(strong("Side Effects: "), if (isTRUE(comp$has_super_assign)) "Mutates parent environment (<<-)" else "Pure functional")
            )
          ),

          column(6,
            h5(style = "font-weight: 700; color: #334155;", "Synthesized 6-Point TRCE Annotation (Review & Edit):"),
            textInput("step_id", "Trace ID (@trce-id):", value = auto_id),
            textInput("step_who", "Who (@trce-who):", value = auto_who),
            textAreaInput("step_what", "What (@trce-what):", value = auto_what, rows = 2),
            textInput("step_where", "Where (@trce-where):", value = auto_where),
            textInput("step_when", "When (@trce-when):", value = auto_when),
            textAreaInput("step_why", "Why (@trce-why):", value = auto_why, rows = 2),
            textAreaInput("step_how", "How (@trce-how):", value = auto_how, rows = 2),
            hr(),
            div(style = "display: flex; gap: 8px; justify-content: flex-end;",
              if (curr > 1) actionButton("btn_prev_step", "Previous", class = "btn-default btn-walkthrough"),
              actionButton("btn_skip_step", "Skip", class = "btn-default btn-walkthrough"),
              actionButton("btn_accept_step", "Accept & Next", class = "btn-success btn-walkthrough")
            )
          )
        )
      )
    )
  })

  # --- OUTPUTS ---

  output$audit_status_banner <- renderUI({
    v <- validation_data()
    req(v)
    if (v$is_clean) {
      div(class = "badge-success", style = "display: inline-block; padding: 8px 16px;",
          sprintf("TRCE AUDIT PASSED: 100%% Coverage (%d valid traces, 0 issues detected).", v$total_traces))
    } else {
      div(class = "badge-warning", style = "display: inline-block; padding: 8px 16px;",
          sprintf("TRCE AUDIT IN PROGRESS: Coverage is %.1f%% (%d of %d targets annotated).",
                  v$coverage_pct, v$annotated_targets, v$total_targets))
    }
  })

  output$code_view_ui <- renderUI({
    tags$pre(class = "code-view", working_code())
  })

  output$trace_index_table <- renderTable({
    v <- validation_data()
    req(v)
    if (length(v$entries) == 0) {
      return(data.frame(Status = "No TRCE annotations present yet."))
    }
    rows <- list()
    for (e in v$entries) {
      f <- e$fields
      rows[[length(rows) + 1L]] <- data.frame(
        Trace_ID = e$id,
        Who = if (!is.null(f$who)) f$who else "-",
        What = if (!is.null(f$what)) f$what else "-",
        Where = if (!is.null(f$where)) f$where else "-",
        Line = as.integer(e$line),
        stringsAsFactors = FALSE
      )
    }
    do.call(rbind, rows)
  })

  output$explanation_ui <- renderUI({
    p <- parsed_data()
    a <- analysis_data()
    v <- validation_data()
    req(p, a, v)
    exp <- explain_r_file(p, a, v)
    tags$pre(class = "code-view", exp$text)
  })

  output$components_table <- renderTable({
    a <- analysis_data()
    req(a)
    rows <- list()
    for (comp in a$components) {
      if (comp$kind %in% c("function", "shiny_ui", "shiny_server", "schema_definition") || isTRUE(comp$is_cli_runner)) {
        rows[[length(rows) + 1L]] <- data.frame(
          Name = comp$name,
          Kind = if (comp$kind == "function") comp$archetype else comp$kind,
          Lines = sprintf("L%d-L%d", comp$line1, comp$line2),
          Parameters = if (!is.null(comp$args) && length(comp$args) > 0) paste(comp$args, collapse = ", ") else "-",
          Local_Calls = if (!is.null(comp$calls_local) && length(comp$calls_local) > 0) paste(comp$calls_local, collapse = ", ") else "-",
          Called_By = if (!is.null(comp$called_by) && length(comp$called_by) > 0) paste(comp$called_by, collapse = ", ") else "-",
          stringsAsFactors = FALSE
        )
      }
    }
    if (length(rows) == 0) return(data.frame(Status = "No annotatable components found"))
    do.call(rbind, rows)
  })

  output$ast_expressions_table <- renderTable({
    p <- parsed_data()
    req(p)
    rows <- list()
    for (item in p$expressions) {
      rows[[length(rows) + 1L]] <- data.frame(
        Index = item$index,
        Lines = sprintf("L%d-L%d", item$line1, item$line2),
        Code_Snippet = substr(gsub("\n", " ", item$code), 1, 60),
        stringsAsFactors = FALSE
      )
    }
    do.call(rbind, rows)
  })

  output$parse_data_table <- renderTable({
    p <- parsed_data()
    req(p)
    if (nrow(p$parse_data) == 0) return(data.frame(Status = "Empty parse data"))
    head(p$parse_data[, c("line1", "col1", "line2", "col2", "token", "text")], 20)
  })

  # File downloads
  output$download_r <- downloadHandler(
    filename = function() paste0("annotated_", active_filename()),
    content = function(file) writeLines(working_code(), file)
  )

  output$download_r_walkthrough <- downloadHandler(
    filename = function() paste0("annotated_", active_filename()),
    content = function(file) writeLines(working_code(), file)
  )

  output$download_json <- downloadHandler(
    filename = function() paste0("traces_", sub("\\.R$", "", active_filename()), ".json"),
    content = function(file) {
      tmp <- tempfile(fileext = ".R")
      writeLines(working_code(), tmp)
      on.exit(unlink(tmp))
      val <- validate_r_annotations(tmp)
      writeLines(export_trace_json(list(val)), file)
    }
  )

  output$download_json_walkthrough <- downloadHandler(
    filename = function() paste0("traces_", sub("\\.R$", "", active_filename()), ".json"),
    content = function(file) {
      tmp <- tempfile(fileext = ".R")
      writeLines(working_code(), tmp)
      on.exit(unlink(tmp))
      val <- validate_r_annotations(tmp)
      writeLines(export_trace_json(list(val)), file)
    }
  )

  # --- STUDENT STUDIO SERVER OUTPUTS ---
  output$student_pitfalls_ui <- renderUI({
    p <- parsed_data()
    a <- analysis_data()
    req(p, a)
    pitfalls <- detect_student_pitfalls(p, a)

    if (length(pitfalls) == 0) {
      return(div(class = "card", style = "border-left: 5px solid #10b981; background: #f0fdf4;",
        h3(style = "color: #166534; margin-top: 0;", "🎉 Clean Bill of Health!"),
        p(style = "color: #15803d; font-size: 15px;",
          "R-TRCE scanned this script and found zero common beginner traps, NA comparison errors, or quadratic copy-on-modify memory bottlenecks.")
      ))
    }

    cards <- lapply(seq_along(pitfalls), function(i) {
      pf <- pitfalls[[i]]
      border_col <- if (pf$severity == "warning") "#ef4444" else "#f59e0b"
      bg_col <- if (pf$severity == "warning") "#fef2f2" else "#fffbeb"
      badge_cls <- if (pf$severity == "warning") "badge-warning" else "badge-info"

      div(class = "card", style = sprintf("border-left: 5px solid %s; background: %s; margin-bottom: 16px;", border_col, bg_col),
        div(style = "display: flex; justify-content: space-between; align-items: center;",
          h4(style = "margin: 0; font-weight: 700;", sprintf("%d. %s (Line %d)", i, pf$title, pf$line)),
          span(class = badge_cls, toupper(pf$severity))
        ),
        p(style = "margin-top: 10px; color: #334155; font-size: 14px;", pf$description),
        div(style = "background: white; border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px; margin-top: 8px;",
          strong(style = "color: #0f172a;", "💡 Recommended Fix: "),
          span(style = "color: #0369a1; font-family: monospace;", pf$suggestion)
        ),
        if (nzchar(pf$code_snippet)) {
          div(style = "margin-top: 8px;",
            span(class = "field-label", "Detected Code:"),
            tags$pre(style = "background: #1e293b; color: #f8fafc; padding: 8px; border-radius: 4px; font-size: 12px; margin-top: 4px;", pf$code_snippet)
          )
        }
      )
    })

    tagList(
      div(style = "margin-bottom: 16px;",
        h3(style = "margin: 0 0 6px;", "Student Pitfall & Safety Audit"),
        p(style = "color: #64748b;", sprintf("Found %d potential conceptual or memory trap(s) to review.", length(pitfalls)))
      ),
      cards
    )
  })

  output$student_concepts_ui <- renderUI({
    p <- parsed_data()
    a <- analysis_data()
    req(p, a)
    primers <- package_primer(a$imports)

    pkg_cards <- if (length(primers) == 0) {
      div(class = "card",
        h4("Standard Base R Environment"),
        p("This script relies solely on R's core built-in standard library without external dependencies.")
      )
    } else {
      div(class = "card",
        h4("Imported Libraries & Package Primer"),
        lapply(names(primers), function(pkg) {
          info <- primers[[pkg]]
          div(style = "border-bottom: 1px solid #e2e8f0; padding: 10px 0;",
            div(style = "display: flex; gap: 10px; align-items: center;",
              strong(style = "font-size: 16px; color: #0284c7;", paste0("library(", info$name, ")")),
              span(class = "badge-info", info$domain)
            ),
            p(style = "margin: 6px 0 0; color: #475569; font-size: 14px;", info$role)
          )
        })
      )
    }

    func_cards <- div(class = "card",
      h4("Functions & Scoping Audit"),
      p(style = "color: #64748b; font-size: 13px;", "Understanding functional building blocks and side effects:"),
      lapply(a$components, function(comp) {
        if (comp$kind != "function") return(NULL)
        is_pure <- !isTRUE(comp$has_super_assign)
        div(style = "border-left: 4px solid #3b82f6; padding: 8px 12px; margin-bottom: 12px; background: #f8fafc;",
          h5(style = "margin: 0 0 4px; font-weight: 700;", sprintf("%s(%s)", comp$name, paste(comp$args, collapse = ", "))),
          div(style = "display: flex; gap: 8px;",
            span(class = if (is_pure) "badge-success" else "badge-warning", if (is_pure) "Pure Function" else "Impure (<<-)"),
            span(class = "badge-secondary", comp$archetype)
          ),
          p(style = "margin: 6px 0 0; color: #64748b; font-size: 12px;",
            sprintf("Defined on lines %d-%d.%s", comp$line1, comp$line2,
                    if (length(comp$calls_local) > 0) sprintf(" Calls local function(s): %s.", paste(comp$calls_local, collapse = ", ")) else ""))
        )
      })
    )

    trce_rubric <- div(class = "card", style = "background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); color: white;",
      h4(style = "color: white;", "The 6-Point TRCE Inquiry Rubric"),
      p(style = "color: #94a3b8; font-size: 13px;", "How to deconstruct any piece of code like a computer scientist:"),
      tags$ul(style = "line-height: 1.8; font-size: 13px;",
        tags$li(strong("WHO: "), "Who executes this code? (User script, ggplot renderer, or Shiny server)"),
        tags$li(strong("WHAT: "), "What exact mechanical operation is executed? (Filtering, joining, modeling)"),
        tags$li(strong("WHERE: "), "Where is the data flowing from and to? (Upstream table -> downstream view)"),
        tags$li(strong("WHEN: "), "When does this trigger? (On file source, button click, or iteration step)"),
        tags$li(strong("WHY: "), "Why is it designed this way? (Why avoid loops? Why vectorize?)"),
        tags$li(strong("HOW: "), "How does memory and state change? (Copy-on-modify, lexical closure)")
      )
    )

    tagList(pkg_cards, func_cards, trce_rubric)
  })

  output$student_pipelines_ui <- renderUI({
    p <- parsed_data()
    req(p)
    pipes <- deconstruct_pipes(p)
    formulas <- deconstruct_formulas(p)

    pipe_card <- if (length(pipes) == 0) {
      div(class = "card",
        h4("Data Pipelines (|>, %>%)"),
        p(style = "color: #64748b;", "No piped expressions (|>, %>%) detected in this file.")
      )
    } else {
      div(class = "card",
        h4("Data Pipeline Flow Inspector"),
        p(style = "color: #64748b; font-size: 13px;", "Step-by-step unrolling of piped operations:"),
        lapply(seq_along(pipes), function(i) {
          pipe <- pipes[[i]]
          div(style = "margin-bottom: 20px; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px;",
            h5(style = "margin: 0 0 10px; color: #1e293b;", sprintf("Pipeline #%d (starts at line %d with source: '%s')", i, pipe$line1, pipe$source)),
            lapply(seq_along(pipe$stages), function(s_idx) {
              stg <- pipe$stages[[s_idx]]
              div(style = "margin-left: 15px; border-left: 3px solid #0284c7; padding-left: 10px; margin-bottom: 8px;",
                strong(style = "color: #0369a1;", sprintf("Step %d: %s()", s_idx, stg$fn)),
                p(style = "margin: 2px 0 0; color: #475569; font-size: 13px;", stg$explanation)
              )
            })
          )
        })
      )
    }

    formula_card <- if (length(formulas) == 0) {
      div(class = "card",
        h4("Statistical Model Formulas (~)"),
        p(style = "color: #64748b;", "No statistical formula specifications (~) detected in this file.")
      )
    } else {
      div(class = "card",
        h4("Statistical Model Deconstructor"),
        p(style = "color: #64748b; font-size: 13px;", "Translating R model formulas into statistical equations:"),
        lapply(formulas, function(f) {
          div(style = "border-left: 4px solid #8b5cf6; background: #faf5ff; padding: 12px; margin-bottom: 12px; border-radius: 4px;",
            h5(style = "margin: 0 0 6px; font-family: monospace; font-size: 15px; color: #581c87;", f$formula),
            tags$ul(style = "font-size: 13px; color: #334155; margin-bottom: 0;",
              tags$li(strong("Response Variable (Y): "), f$response_variable),
              tags$li(strong("Predictors (X): "), paste(f$rhs_terms, collapse = ", ")),
              tags$li(strong("Interaction Terms: "), if (f$has_interaction) "Present (: or *)" else "None (additive effects only)"),
              tags$li(strong("Theoretical Meaning: "), f$explanation)
            )
          )
        })
      )
    }

    tagList(pipe_card, formula_card)
  })

  output$student_quiz_ui <- renderUI({
    p <- parsed_data()
    a <- analysis_data()
    req(p, a)
    questions <- generate_student_quiz(p, a)

    div(class = "card",
      h4("Self-Study Comprehension Quiz"),
      p(style = "color: #64748b; font-size: 13px;", "Test your understanding of this script's architecture, dependencies, and scoping:"),
      lapply(seq_along(questions), function(i) {
        q <- questions[[i]]
        div(style = "border-bottom: 1px solid #e2e8f0; padding: 14px 0;",
          h5(style = "font-weight: 700; color: #0f172a; margin: 0 0 8px;", sprintf("Question %d: %s", i, q$question)),
          tags$ul(style = "list-style-type: none; padding-left: 4px;",
            lapply(q$options, function(opt) {
              tags$li(style = "margin-bottom: 4px; font-size: 13px; color: #334155;", opt)
            })
          ),
          tags$details(style = "margin-top: 8px; font-size: 13px;",
            tags$summary(style = "cursor: pointer; color: #2563eb; font-weight: 600;", "👉 Show Answer & Explanation"),
            div(style = "margin-top: 6px; padding: 10px; background: #eff6ff; border-radius: 6px; color: #1e3a8a;",
              strong(sprintf("Correct Answer: %s", q$correct_answer)),
              p(style = "margin: 4px 0 0;", q$explanation)
            )
          )
        )
      })
    )
  })
}

# --- STANDALONE APP LAUNCHER ---
app <- shinyApp(ui = ui, server = server)

if (!interactive()) {
  port <- as.integer(Sys.getenv("PORT", "8083"))
  # Bind on 0.0.0.0 by default on Linux/Baguette/Crostini so container port forwarding and host access works seamlessly
  host <- Sys.getenv("HOST", "0.0.0.0")

  # Detect network interfaces to display all accessible URLs
  ip_candidates <- c("127.0.0.1", "localhost")
  try({
    # Try hostname -I on Linux
    ips_raw <- suppressWarnings(system("hostname -I 2>/dev/null", intern = TRUE))
    if (length(ips_raw) > 0 && nchar(trimws(ips_raw[1])) > 0) {
      detected_ips <- strsplit(trimws(ips_raw[1]), "\\s+")[[1]]
      ip_candidates <- unique(c(ip_candidates, detected_ips))
    }
  }, silent = TRUE)

  message("==================================================================")
  message("  R-TRCE Interactive Studio & Guided Walkthrough")
  message("==================================================================")
  message(sprintf("  Listening on: http://%s:%d", host, port))
  message("\n  Access the Studio in your browser via any of these URLs:")
  message(sprintf("   * Primary (Local):             http://localhost:%d", port))
  message(sprintf("   * Loopback:                    http://127.0.0.1:%d", port))
  for (ip in ip_candidates[!ip_candidates %in% c("127.0.0.1", "localhost")]) {
    message(sprintf("   * Container / Network IP:      http://%s:%d", ip, port))
  }
  if (dir.exists("/dev/vsock") || file.exists("/run/systemd/container") || dir.exists("/mnt/chromeos")) {
    message("\n  [Chromebook / ChromeOS / Baguette Note]:")
    message(sprintf("   * From ChromeOS browser, try:   http://penguin.linux.test:%d", port))
    message(sprintf("   * Or use container IP:          http://%s:%d", 
                    if (length(ip_candidates) > 2) ip_candidates[3] else "127.0.0.1", port))
  }
  message("==================================================================\n")

  shiny::runApp(app, host = host, port = port, launch.browser = FALSE)
} else {
  app
}

