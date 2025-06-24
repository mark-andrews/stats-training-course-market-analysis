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
    select(delivery, date) |>
    mutate(
      date = date_parse_f(date),
      year = year(date),
      delivery = as.list(delivery)
    )
}

delivery_df <-
  bind_rows(
    read_results(db = "NCRM") |> mutate(db = "NCRM"),
    read_results(db = "ALLSTAT") |> mutate(db = "ALLSTAT"),
    read_results(db = "TESS") |> mutate(db = "TESS")
  ) |>
  mutate(year_group = ntile(year, 5))  |> 
  rowwise() |>
  filter(!is.list(delivery)) |>
  ungroup() |>
  unnest_wider(col = delivery, names_sep = "_")  |> 
  pivot_longer(cols = starts_with("delivery")) |> 
  select(year, year_group, db, delivery = value) |>
  mutate(delivery = str_trim(delivery) |> str_to_lower(), 
         delivery = str_replace_all(delivery, '-', ' '),
         delivery = na_if(delivery, "")) |>
  drop_na()  
# 
# delivery_df |> count(delivery) |> arrange(desc(n))
# delivery_df |> filter(year_group == 5) |> count(delivery) |> arrange(desc(n))
# duration_df |> filter(year_group == 5) |> count(duration) |> arrange(desc(n))
# duration_df |> filter(year_group == 1) |> count(duration) |> arrange(desc(n))

