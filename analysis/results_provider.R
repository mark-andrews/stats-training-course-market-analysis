library(tidyverse)
library(lubridate)
library(here)

read_results <- function(db) {
  if (db == "ALLSTAT") {
    RESULTS_FILE <- "data/allstat_training_course_posts_ollama.Rds"
    date_parse_f <- lubridate::my
  } else if (db == "NCRM") {
    RESULTS_FILE <- "data/ncrm_training_course_posts_llama_results.Rds"
    date_parse_f <- lubridate::dmy
  } else if (db == "TESS") {
    RESULTS_FILE <- "data/tess_training_course_posts_llama_results.Rds"
    date_parse_f <- lubridate::ymd_hms
  }

  readRDS(here(RESULTS_FILE))$data_frame |>
    select(provider, date) |>
    mutate(
      date = date_parse_f(date),
      year = year(date)
    )
}

provider_df <-
  bind_rows(
    read_results(db = "NCRM") |> mutate(db = "NCRM"),
    read_results(db = "ALLSTAT") |> mutate(db = "ALLSTAT"),
    read_results(db = "TESS") |> mutate(db = "TESS")
  ) |>
  mutate(year_group = ntile(year, 5)) |> 
  rowwise() |>
  filter(!is.list(provider)) |>
  ungroup() |>
  unnest_wider(col = provider, names_sep = "_") |> 
  pivot_longer(cols = starts_with("provider_")) |>
  select(year, year_group, db, provider = value) |>
  mutate(provider = str_trim(provider) |> str_to_lower(), provider = na_if(provider, "")) |>
  drop_na()

