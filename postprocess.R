ncrm_df <- readRDS("data/ncrm_training_course_posts_llama_results.Rds")$data_frame |>
  select(topic, field, level, software, delivery, duration, date) |>
  mutate(
    date = dmy(date),
    year = year(date),
    post_covid = date < dmy("1/3/2020")
  )

ncrm_df |>
  mutate(delivery = na_if(delivery, "")) |>
  na.omit() |>
  group_by(post_covid) |>
  count(delivery)

# Software ----------------------------------------------------------------


# What software is used?
# Top five, ignoring nvivo, are R, Stata, Python, Mplus, Spss
ncrm_df |>
  pull(software) |>
  unlist() |>
  str_to_lower() |>
  enframe() |>
  mutate(value = na_if(value, "")) |>
  drop_na() |>
  count(value) |>
  arrange(desc(n)) |>
  slice_head(n = 10)

clean_software <- function(software) {
  if (is.list(software)) {
    return(NA_character_)
  }
  if (is.null(software)) {
    return(NA_character_)
  }
  if (is.character(software) & all(software == "")) {
    return(NA_character_)
  }

  software
}

ncrm_df$software <- map(ncrm_df$software, clean_software)

xx <-
  ncrm_df |>
  mutate(year_group = ntile(year, 5)) |>
  select(year_group, software) |>
  na.omit() |>
  group_by(year_group) |>
  nest(data = software)


top_software <- function(software) {
  unlist(software[[1]]) |>
    str_to_lower() |>
    enframe() |>
    mutate(value = na_if(value, "")) |>
    drop_na() |>
    count(value) |>
    arrange(desc(n)) |>
    slice_head(n = 10) |>
    mutate(n = round(100 * n / sum(n)))
}
map_dfr(xx$data, top_software, .id = "i") |> print(n = Inf)


# topics ------------------------------------------------------------------
ncrm_topics <- ncrm_df$topic |>
  unlist() |>
  str_trim() |>
  na.omit() |>
  str_to_lower() |>
  unique() |>
  keep(~ str_length(.) > 0)

topic_categories <-
  tibble(
    topic = ncrm_topics,
    topic_categories = readRDS("data/ncrm_topics.Rds") |> str_extract("(?<=category: ).*?(?=\\s*\\n)")
  )

ncrm_df |>
  select(topic, year) |>
  mutate(topic = na_if(topic, "")) |>
  drop_na() |>
  mutate(topic = str_trim(topic) |> str_to_lower()) |>
  left_join(topic_categories, by = "topic") |>
  count(topic_categories) |>
  arrange(desc(n))

ncrm_df |>
  select(topic, year) |>
  mutate(topic = na_if(topic, "")) |>
  drop_na() |>
  mutate(topic = str_trim(topic) |> str_to_lower()) |>
  left_join(topic_categories, by = "topic") |>
  mutate(categories = str_split(topic_categories, pattern = "; ")) |>
  pull(categories) |>
  unlist() |>
  enframe() |>
  count(value) |>
  arrange(desc(n))
