library(tidyverse)
library(lubridate)
library(here)

read_results <- function(db) {
  if (db == "ALLSTAT") {
    RESULTS_FILE <- "data/allstat_training_course_posts_ollama.Rds"
    TOPICS_FILE <- "data/allstat_topics.Rds"
    date_parse_f <- lubridate::my
  } else if (db == "NCRM") {
    RESULTS_FILE <- "data/ncrm_training_course_posts_llama_results.Rds"
    TOPICS_FILE <- "data/ncrm_topics.Rds"
    date_parse_f <- lubridate::dmy
  } else if (db == "TESS") {
    RESULTS_FILE <- "data/tess_training_course_posts_llama_results.Rds"
    TOPICS_FILE <- "data/tess_topics.Rds"
    date_parse_f <- lubridate::ymd_hms
  }

  data_df <- readRDS(here(RESULTS_FILE))$data_frame |>
    select(topic, date) |>
    mutate(
      date = date_parse_f(date),
      year = year(date)
    )

  topics <- data_df$topic |>
    unlist() |>
    str_trim() |>
    na.omit() |>
    str_to_lower() |>
    unique() |>
    keep(~ str_length(.) > 0)

  topic_categories <- tibble(
    topic = topics,
    topic_categories = readRDS(here(TOPICS_FILE)) |> str_extract("(?<=category: ).*?(?=\\s*\\n)")
  )

  data_df |>
    mutate(topic = na_if(topic, "")) |>
    drop_na() |>
    mutate(topic = str_trim(topic) |> str_to_lower()) |>
    left_join(topic_categories, by = "topic")
}

topics_df <-
  bind_rows(
    read_results(db = "NCRM") |> mutate(db = "NCRM"),
    read_results(db = "ALLSTAT") |> mutate(db = "ALLSTAT")
    ) |> 
    mutate(year_group = ntile(year, 5))

# Major topics ------------------------------------------------------------
top_categories <- function(data_df) {
  data_df |>
    mutate(categories = str_split(topic_categories, pattern = "; ")) |>
    pull(categories) |>
    unlist() |>
    enframe() |>
    mutate(
      value = str_remove(value, "^Category [0-9]+( – |\\. )")
    ) |>
    count(value) |>
    arrange(desc(n))
}


inspect_category <- function(category_label) {
  topics_df |>
    mutate(categories = str_split(topic_categories, pattern = "; ")) |>
    select(topic, categories) |>
    unnest_wider(col = categories, names_sep = "_") |>
    pivot_longer(cols = -topic) |>
    drop_na() |>
    select(topic, category = value) |>
    filter(str_detect(category, category_label)) |>
    count(topic) |>
    arrange(desc(n))
}

# look at "Core Statistical Methods"
# inspect_category("^Core Statistical Methods")

# look at "Causal Inference & Evaluation"
# inspect_category("^Causal Inference & Evaluation")
