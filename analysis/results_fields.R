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
    select(field, date) |>
    mutate(
      date = date_parse_f(date),
      year = year(date)
    )
}

fields_df <-
  bind_rows(
    read_results(db = "NCRM") |> mutate(db = "NCRM"),
    read_results(db = "ALLSTAT") |> mutate(db = "ALLSTAT"),
    read_results(db = "TESS") |> mutate(db = "TESS")
  ) |>
  mutate(year_group = ntile(year, 5)) |>
  rowwise() |>
  filter(!is.list(field)) |>
  ungroup() |>
  unnest_wider(col = field, names_sep = "_") |>
  pivot_longer(cols = starts_with("field_")) |>
  select(year, year_group, db, field = value) |>
  mutate(field = str_trim(field), field = na_if(field, '')) |> 
  drop_na()

# 
# fields_df |> count(field) |> arrange(desc(n))
# fields_df |> filter(db == 'ALLSTAT') |> count(field) |> arrange(desc(n))
# fields_df |> filter(db == 'TESS') |> count(field) |> arrange(desc(n))
# fields_df |> filter(db == 'NCRM') |> count(field) |> arrange(desc(n))
# 
# fields_df |> filter(year_group == 1, db == 'ALLSTAT') |> count(field) |> arrange(desc(n))
# fields_df |> filter(year_group == 5, db == 'ALLSTAT') |> count(field) |> arrange(desc(n))
