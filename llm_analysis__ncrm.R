library(tidyverse)
library(ellmer)

# helper functions -------------------------------------------------------

chat <- function(post, instructions, llm = "Llama", database) {
  if (llm == "Llama") {
    client <- chat_ollama(system_prompt = instructions, model = "llama3.3.65536")
  } else if (llm == "ChatGPT") {
    # requires OPENAI_API_KEY environment variable
    client <- chat_openai(system_prompt = instructions)
  } else {
    stop("Unknown LLM")
  }
  client$chat(format_post(post, database=database))
}

format_post <- function(post, database='allstat') {
  
  if (database == 'ncrm'){
    title <- post$event
    description <- post$description
  }
  
  str_c(
    str_c("# ", title, "\n\n"),
    description,
    collapse = "\n"
  )
}

process_posts <- function(posts, instructions, llm, database, backup_file) {
  # This function is largely equivalent to something like
  # purrr::map(posts, chat, instructions = instructions, llm = 'Llama')
  # However, saving the results list to RDS file on each iteration
  # requires a loop like this.
  N <- length(posts)
  results <- vector("list", length = N)
  for (i in seq(N)) {
    # We want to skip over any errors and not let them stop the flow
    tryCatch(
      {
        results[[i]] <- chat(posts[[i]], instructions = instructions, llm = llm, database=database)
      },
      error = function(e) {
        message("An error happened: ", e$message)
      },
      warning = function(w) {
        message("A warning occurred: ", w$message)
      }
    )

    saveRDS(results, file = backup_file)
  }
  results
}

postprocess_results <- function(results, posts) {
  stopifnot(length(results) == length(posts))
  N <- length(results)
  processed_results <- vector(mode = "list", length = N)
  for (i in seq(N)) {
    processed_results[[i]] <- tryCatch(
      {
        result <- jsonlite::fromJSON(results[[i]], simplifyVector = TRUE)
        result$date <- posts[[i]][['event-date']]
        result$keywords2 <- unlist(posts[[i]][['Keywords']])
        result$level2 <- posts[[i]][['Level']]
        result
      },
      error = function(e) NULL
    )
  }
  processed_results
}

# this is used to unlist list-columns
safe_unlist <- function(v) {
  map(v, function(s) {
    if (is.null(s)) {
      NA
    } else {
      s
    }
  }) |> unlist()
}

# use this to read bzip2 compressed json files
read_json_bz2 <- function(json_bz2_path) {
  temp_file <- tempfile(fileext = ".json")
  R.utils::bunzip2(filename = json_bz2_path, destname = temp_file, remove = FALSE)
  jsonlite::read_json(temp_file)
}


# Read in instructions and posts from file --------------------------------

instructions <- readLines("instructions.md") |>
  str_c(collapse = "\n")

allstat_posts <- read_json_bz2("data/allstat_training_course_posts.json.bz2")
ncrm_posts <- read_json_bz2("data/ncrm_events.json.bz2")

# Process the posts ------------------------------------------------------

results <- process_posts(ncrm_posts, instructions = instructions, llm = "Llama", database='ncrm', backup_file = "results_backup.Rds")

# convert results to a data-frame
# tricky because of the values that are lists
results_df <- postprocess_results(results, ncrm_posts) |>
  discard(is.null) |>
  # make each value a list to allow for concatenation
  map(~ map(., list) |> as_tibble()) |>
  bind_rows() |>
  # unlist everything that can be unlisted
  mutate(across(where(~ length(safe_unlist(.)) == length(.)), safe_unlist))

# Save results -----------------------------------------------------------

# save raw results as-is and save the data frame
saveRDS(list(raw = results, data_frame = results_df), "data/ncrm_training_course_posts_llama_results.Rds")
