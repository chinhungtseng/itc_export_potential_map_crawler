# Function to fetch data and pasred the content
fetch <- function(url) {
  counter <- 5

  while (counter >= 0) {
    print(counter)

    tryCatch({
      response <- httr::GET(
        url = url,
        httr::user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36"),
        httr::add_headers(c(
          "Accept"    = "application/json, text/plain, */*",
          "Accept-Encoding" = "gzip, deflate, br",
          "Accept-Language" = "en-US,en;q=0.9,zh-TW;q=0.8,zh;q=0.7",
          "Referer"   = "https://exportpotential.intracen.org/en/",
          "Host" = "exportpotential.intracen.org",
          "X-Context" = "epm-generic"
        )), httr::verbose()
      )

      content_parsed <- httr::content(response, "parsed")
      return(content_parsed)
    },
      error = function(cond) {
        print(cond)
        sleep_randomly()
      })

    counter <- counter - 1
  }
}

# A function factory to convert parsed data to data.frame by specified url.
get_data <- function(url) {
  force(url)

  function() {
    requese <- fetch(url)

    tmp_name <- unique(names(unlist(requese)))
    tmp_data <- matrix(unlist(requese), ncol = length(tmp_name), byrow = TRUE)
    tmp_data <- as.data.frame(tmp_data, stringsAsFactors = FALSE)
    names(tmp_data) <- tmp_name

    return(tmp_data)
  }
}

get_products <- get_data("https://exportpotential.intracen.org/api/en/products")
get_regions <- get_data("https://exportpotential.intracen.org/api/en/regions")
get_sub_regions <- get_data("https://exportpotential.intracen.org/api/en/sub-regions")
get_countries <- get_data("https://exportpotential.intracen.org/api/en/countries")
get_sub_sectors <- get_data("https://exportpotential.intracen.org/api/en/sub-sectors")
get_sectors <- get_data("https://exportpotential.intracen.org/api/en/sectors")

# Function to unnest a data.frame within a data.frame
reformat_data_frame <- function(x) {
  # extract data.frame in a data.frame
  split_data_frame <- function(x, col) {
    index <- which(names(x) == col)
    tmp_df <- x[[index]]
    names(tmp_df) <- paste0(col, ".", names(tmp_df))

    list(mother = x[-index], child = tmp_df)
  }

  repeat {
    col_types <- purrr::map_chr(x, class)

    if (!("data.frame" %in% col_types)) break

    index <- which(col_types == "data.frame")
    tmp_df <- split_data_frame(x, names(index))
    x <- Reduce(cbind, tmp_df)
  }
  x
}

# Function to download potential data by exporter and market code.
download_potential_data <- function (exporter = 490, market) {
  # assign default exporter with "Taipei Chinese" (490)
  urls <- sprintf("https://exportpotential.intracen.org/api/en/epis/products/from/i/%s/to/j/%s/what/k/all",
    exporter, market)

  tmp_data <- jsonlite::fromJSON(fetch(urls))
  tmp_data <- reformat_data_frame(tmp_data)

  # add exporter info
  tmp_data$ExporterCode <- exporter
  tmp_data$ExporterName <- country_info(exporter)$name
  tmp_data$ExporterParentCode <- country_info(exporter)$parentCode

  # add market country info
  tmp_data$CountryCode <- market
  tmp_data$CountryName <- country_info(market)$name
  tmp_data$CountryParentCode <- country_info(market)$parentCode

  tmp_data
}

# Function to get countries name and parent code by code.
country_info <- function(x) {
  tmp <- unlist(countries_data[countries_data$code == x, ])
  list(code = tmp[["code"]], name = tmp[["name"]], parentCode = tmp[["parentCode"]])
}
