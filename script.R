# Program
#   Download ITC Export Potential Map Data

# Install require packages
packages <- c("httr", "rvest", "tidyverse", "jsonlite", "foreach", "doParallel")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE))
    install.packages(pkg, character.only = TRUE)
}

### BEGIN the program ###
library(httr)
library(rvest)
library(tidyverse)
library(jsonlite)
library(foreach)
library(doParallel)

# Source helper functions
purrr::walk(fs::dir_ls("R", regexp = "*.R"), source, encoding = "UTF-8")

# Create output directories
output_dir <- c("data", "data/sub_potential_data")
lapply(output_dir, function(x) {
  if (!fs::dir_exists(x))
    fs::dir_create(x)
})

### BEGIN download meta data ###
readr::write_excel_csv(get_products(),    "data/products.csv",    na = "")
readr::write_excel_csv(get_countries(),   "data/countries.csv",   na = "")
readr::write_excel_csv(get_regions(),     "data/regions.csv",     na = "")
readr::write_excel_csv(get_sub_regions(), "data/sub_regions.csv", na = "")
readr::write_excel_csv(get_sectors(),     "data/sectors.csv",     na = "")
readr::write_excel_csv(get_sub_sectors(), "data/sub_sectors.csv", na = "")
### END download meta data ###

### BEGIN download potential data ###
countries_data <- get_countries()
countries_data <- dplyr::arrange(countries_data, as.numeric(code))
countries_code <- as.numeric(countries_data$code)

# set exporter to "Taipei Chinese"
code_tw <- countries_code[which(countries_data$name == "Taipei, Chinese")]
batchs <- split(countries_code, cut(seq_len(length(countries_code)), 20, labels = FALSE))

for (batch in batchs) {
  # TODO need to fix parallel downloadings failed!
  doParallel::registerDoParallel(cores = parallel::detectCores() - 1)

  register_pkgs <- c("httr", "rvest", "jsonlite", "tidyverse")
  register_funs <- c("download_potential_data", "sleep_randomly", "countries_data",
    "reformat_data_frame", "get_data", "fetch", "code_tw")

  potential_data <- foreach::foreach(i = unlist(batch),
    .export = register_funs, .packages = register_pkgs,
    .combine = dplyr::bind_rows, .verbose = TRUE
  ) %do% {
    sleep_randomly()
    download_potential_data(exporter = code_tw, market = i)
  }

  readr::write_excel_csv(potential_data, paste0("data/sub_potential_data/potential_data_", min(batch), "_", max(batch), ".csv"), na = "")
  sleep_randomly()
}
### END download potential data ###

### BEGIN bind sub-potential data ###
potential_data <- purrr::map(fs::dir_ls("data/sub_potential_data/"), readr::read_csv,
  col_types = paste0(rep("c", 30), collapse = ""))

potential_data <- purrr::reduce(potential_data, dplyr::bind_rows)
readr::write_excel_csv(potential_data, "data/potential_data_all.csv", na = "")
### END bind sub-potential data ###

### END the program ###
