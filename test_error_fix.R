# Test script to verify error handling fix
cat("Testing error handling fix...\n")

# Test the conditionMessage function
test_error <- function() {
  tryCatch({
    # This will cause an error
    stop("Test error message")
  }, error = function(e) {
    cat("Error caught with conditionMessage:", conditionMessage(e), "\n")
    cat("Error caught with e$message:", tryCatch(e$message, error = function(e2) "e$message failed"), "\n")
  })
}

test_error()

cat("Test completed.\n")
