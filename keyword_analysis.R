library(ellmer)
library(tidyverse)

# helper functions -------------------------------------------------------

process_topics <- function(topics, client, backup_file) {
  # Saving the results list to RDS file on each iteration
  # requires a loop like this.
  N <- length(topics)
  results <- vector("list", length = N)
  for (i in seq(N)) {
    # We want to skip over any errors and not let them stop the flow
    tryCatch(
      {
        results[[i]] <- client$chat(topics[[i]])
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

# Get topics ------------------------------------------------------------

ncrm_df <- readRDS("data/ncrm_training_course_posts_llama_results.Rds")$data_frame

topics <- ncrm_df$topic |>
  unlist() |>
  str_trim() |>
  na.omit() |>
  str_to_lower() |>
  unique() |>
  keep(~ str_length(.) > 0)

# Instructions ------------------------------------------------------------

instructions <- readLines("keyword_instructions2.md") |> str_c(collapse = "\n")

# Process topics --------------------------------------------------------

# ncrm
client <- chat_openai(system_prompt = instructions, model = "o3")
results <- process_topics(topics, client, backup_file = "tmp/topics.Rds")

saveRDS(results, file = "data/ncrm_topics.Rds")


# Allstat -----------------------------------------------------------------


allstat_df <- readRDS("data/allstat_training_course_posts_ollama.Rds")$data_frame

topics <- allstat_df$topic |>
  unlist() |>
  str_trim() |>
  na.omit() |>
  str_to_lower() |>
  unique() |>
  keep(~ str_length(.) > 0)

client <- chat_openai(system_prompt = instructions, model = "o3")
results <- process_topics(topics, client, backup_file = "tmp/allstat_topics.Rds")

saveRDS(results, file = "data/allstat_topics.Rds")
# TESS --------------------------------------------------------------------


tess_df <- readRDS("data/tess_training_course_posts_llama_results.Rds")$data_frame

topics <- allstat_df$topic |>
  unlist() |>
  str_trim() |>
  na.omit() |>
  str_to_lower() |>
  unique() |>
  keep(~ str_length(.) > 0)

client <- chat_openai(system_prompt = instructions, model = "o3")
results <- process_topics(topics, client, backup_file = "tmp/tess_topics.Rds")
