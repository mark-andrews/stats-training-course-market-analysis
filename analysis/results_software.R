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
    select(software, date) |>
    mutate(
      date = date_parse_f(date),
      year = year(date)
    )
}

software_df <-
  bind_rows(
    read_results(db = "NCRM") |> mutate(db = "NCRM"),
    read_results(db = "ALLSTAT") |> mutate(db = "ALLSTAT"),
    read_results(db = "TESS") |> mutate(db = "TESS")
  ) |>
  mutate(year_group = ntile(year, 5)) |>
  rowwise() |>
  filter(!is.list(software)) |>
  ungroup() |>
  unnest_wider(col = software, names_sep = "_") |>
  pivot_longer(cols = starts_with("software_")) |>
  select(year, year_group, db, software = value) |>
  mutate(software = str_trim(software) |> str_to_lower(), software = na_if(software, "")) |>
  drop_na()
# 
# software_df |> count(software) |> arrange(desc(n))
# software_df |> filter(year_group == 5) |> count(software) |> arrange(desc(n))
# software_df |> filter(year_group == 1) |> count(software) |> arrange(desc(n))
# software_df |> filter(db == 'NCRM', year_group == 1) |> count(software) |> arrange(desc(n))
# software_df |> filter(db == 'NCRM', year_group == 5) |> count(software) |> arrange(desc(n))
