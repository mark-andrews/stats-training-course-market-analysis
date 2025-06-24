set.seed(1010101)
read_json_bz2 <- function(json_bz2_path) {
  temp_file <- tempfile()
  R.utils::bunzip2(filename = json_bz2_path, destname = temp_file, remove = FALSE)
  jsonlite::read_json(temp_file)
}


posts <- read_json_bz2("data/allstat_training_course_posts.json.bz2")
results <- readRDS("data/allstat_training_course_posts_ollama.Rds")[[1]]
K <- 25
I <- sample(seq(length(posts)), size = K)

cat_post <- function(k) {
  post <- posts[[I[k]]]

  example <- sprintf("# Example post %d", k)
  month <- stringr::str_c("* Month: ", post[["month"]], "\n* Title: *", post[["title"]], "*")
  text <- stringr::str_c("```\n", post[["text"]], "\n```\n")
  result <- stringr::str_c("## LLM Analysis\n\n```\n", results[[I[k]]], "\n```\n")
  stringr::str_c(c(example, month, text, result), collapse = "\n\n")
}

purrr::map(seq(K), cat_post) |> stringr::str_c(collapse='\n\\newpage\n') |> writeLines(con='analysis_validation.md')
