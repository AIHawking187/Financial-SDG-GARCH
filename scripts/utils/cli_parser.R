# CLI Argument Parser for Engine Selection
# Handles --engine flag and config file parsing

parse_cli_args <- function() {
  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  
  # Default values
  config <- list(
    engine = "rugarch",  # Default to rugarch for backward compatibility
    config_file = NULL
  )
  
  # Parse arguments
  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--engine") {
      if (i + 1 <= length(args)) {
        engine <- args[i + 1]
        if (engine %in% c("rugarch", "manual")) {
          config$engine <- engine
        } else {
          stop("Invalid engine: ", engine, ". Use 'rugarch' or 'manual'")
        }
        i <- i + 2
      } else {
        stop("--engine requires a value")
      }
    } else if (args[i] == "--config") {
      if (i + 1 <= length(args)) {
        config$config_file <- args[i + 1]
        i <- i + 2
      } else {
        stop("--config requires a file path")
      }
    } else if (args[i] == "--help" || args[i] == "-h") {
      cat("Usage: Rscript script.R [options]\n")
      cat("Options:\n")
      cat("  --engine ENGINE     GARCH engine to use (rugarch|manual) [default: rugarch]\n")
      cat("  --config FILE       Configuration file path\n")
      cat("  --help, -h          Show this help message\n")
      cat("\n")
      cat("Examples:\n")
      cat("  Rscript simulate_nf_garch.R --engine manual\n")
      cat("  Rscript simulate_nf_garch.R --engine rugarch --config config.yaml\n")
      quit(status = 0)
    } else {
      warning("Unknown argument: ", args[i])
      i <- i + 1
    }
  }
  
  # Load config file if specified
  if (!is.null(config$config_file) && file.exists(config$config_file)) {
    config_from_file <- load_config_file(config$config_file)
    # CLI arguments override config file
    if (!is.null(config_from_file$engine)) {
      config$engine <- config_from_file$engine
    }
  }
  
  return(config)
}

load_config_file <- function(config_file) {
  # Load configuration from YAML file
  if (!requireNamespace("yaml", quietly = TRUE)) {
    warning("yaml package not available, skipping config file")
    return(list())
  }
  
  tryCatch({
    config <- yaml::read_yaml(config_file)
    return(config)
  }, error = function(e) {
    warning("Failed to load config file: ", conditionMessage(e))
    return(list())
  })
}

# Function to get current engine setting
get_engine <- function() {
  config <- parse_cli_args()
  return(config$engine)
}

# Function to print current configuration
print_config <- function() {
  config <- parse_cli_args()
  cat("=== Engine Configuration ===\n")
  cat("Engine:", config$engine, "\n")
  if (!is.null(config$config_file)) {
    cat("Config file:", config$config_file, "\n")
  }
  cat("===========================\n\n")
}
