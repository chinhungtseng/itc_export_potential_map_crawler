# Function to sleep between a range of inputs.
sleep_randomly <- function(min = 5, max = 10) {
  Sys.sleep(runif(1, min, max))
}
