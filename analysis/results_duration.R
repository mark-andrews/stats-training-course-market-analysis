library(tidyverse)
library(lubridate)

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

  readRDS(RESULTS_FILE)$data_frame |>
    select(duration, date) |>
    mutate(
      date = date_parse_f(date),
      year = year(date),
      duration = as.list(duration)
    )
}

duration_df <-
  bind_rows(
    read_results(db = "NCRM") |> mutate(db = "NCRM"),
    read_results(db = "ALLSTAT") |> mutate(db = "ALLSTAT"),
    read_results(db = "TESS") |> mutate(db = "TESS")
  ) |>
  mutate(year_group = ntile(year, 5)) |> 
  rowwise() |>
  filter(!is.list(duration)) |>
  ungroup() |>
  unnest_wider(col = duration, names_sep = "_") |> 
  pivot_longer(cols = starts_with("duration_")) |> 
  select(year, year_group, db, duration = value) |>
  mutate(duration = str_trim(duration) |> str_to_lower(), duration = na_if(duration, "")) |>
  drop_na() |> 
  mutate(duration = str_replace_all(duration, '-', ' '),
         duration = str_replace_all(duration, 'days', 'day'),
         duration = str_replace_all(duration, '^1 ', 'one '),
         duration = str_replace_all(duration, '^2 ', 'two '),
         duration = str_replace_all(duration, '^3 ', 'three '),
         duration = str_replace_all(duration, '^4 ', 'four '),
         duration = str_replace_all(duration, '^5 ', 'five '))

duration_df |> count(duration) |> arrange(desc(n))
duration_df |> filter(year_group == 5) |> count(duration) |> arrange(desc(n))
duration_df |> filter(year_group == 1) |> count(duration) |> arrange(desc(n))

