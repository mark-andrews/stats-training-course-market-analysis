library(tidyverse)
library(ellmer)

# LLM <- "Llama" # or LLM <- 'ChatGPT'
LLM <- "ChatGPT"

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
  client$chat(format_post(post, database = database))
}

format_post <- function(post, database = "allstat") {
  if (database == "ncrm") {
    title <- post$event
    description <- post$description
  } else if (database == "tess") {
    title <- post$name
    description <- post$description
  } else if (database == "allstat") {
    title <- post$title
    description <- post$text
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
        results[[i]] <- chat(posts[[i]], instructions = instructions, llm = llm, database = database)
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

postprocess_results <- function(results, posts, database) {
  stopifnot(length(results) == length(posts))
  N <- length(results)
  processed_results <- vector(mode = "list", length = N)
  for (i in seq(N)) {
    processed_results[[i]] <- tryCatch(
      {
        result <- jsonlite::fromJSON(results[[i]], simplifyVector = TRUE)
        # the event date is specified in different ways in each database
        # also, ncrm and tess posts have some extra attributes that we can store
        if (database == "ncrm") {
          result$date <- posts[[i]][["event-date"]]
          result$keywords2 <- unlist(posts[[i]][["Keywords"]])
          result$level2 <- posts[[i]][["Level"]]
        } else if (database == "ncrm") {
          result$date <- posts[[i]][["startDate"]]
          result$keywords2 <- unlist(posts[[i]][["keywords"]])
        } else if (database == "allstat") {
          result$date <- posts[[i]][["month"]]
        }
        result
      },
      error = function(e) NULL
    )
  }
  processed_results |>
    discard(is.null) |>
    # make each value a list to allow for concatenation
    map(~ map(., list) |> as_tibble()) |>
    bind_rows() |>
    # unlist everything that can be unlisted
    mutate(across(where(~ length(safe_unlist(.)) == length(.)), safe_unlist))
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

write_results <- function(results, results_df, database, llm) {
  fname <- sprintf("data/%s_training_course_posts_%s_results.Rds", database, llm)
  saveRDS(list(raw = results, data_frame = results_df), fname)
}

# Read in instructions and posts from file --------------------------------

instructions <- readLines("instructions.md") |>
  str_c(collapse = "\n")

N <- 330

allstat_posts <- read_json_bz2("data/allstat_training_course_posts.json.bz2")[1:N]
ncrm_posts <- read_json_bz2("data/ncrm_events.json.bz2")[1:N]
tess_posts <- read_json_bz2("data/tess_courses.json.bz2")[1:N]


# Process allstat posts ---------------------------------------------------

allstat_results <- process_posts(allstat_posts,
  instructions = instructions,
  llm = LLM,
  database = "allstat",
  backup_file = "tmp/allstat_results_backup.Rds"
)
allstat_results_df <- postprocess_results(allstat_results,
  allstat_posts,
  database = "allstat"
)
write_results(allstat_results, allstat_results_df, "allstat", LLM)

# Process TESS posts ------------------------------------------------------

# For TESS, we first filter out posts that do not appear at all related to statistics
tess_first_pass_instructions <- str_c(
  'I am going to give you a text that is a post to a mailing list.
  The title of the post is the first line, indicated by the # symbol.
  Is this text describing a statistics training course or not?
  Answer "Yes" or "No" or "Not Sure" only.',
  collapse = "\n"
)
first_pass_tess_results <- process_posts(tess_posts,
  instructions = tess_first_pass_instructions,
  llm = LLM,
  database = "tess",
  backup_file = "tmp/tess_first_pass_results_backup.Rds"
)

tess_posts_filtered <- tess_posts[
  map_lgl(first_pass_tess_results, ~ str_detect(., "^Yes.*"))
]

tess_results <- process_posts(tess_posts_filtered,
  instructions = instructions,
  llm = LLM,
  database = "tess",
  backup_file = "tmp/tess_results_backup.Rds"
)
tess_results_df <- postprocess_results(tess_results,
  tess_posts_filtered,
  database = "tess"
)
write_results(tess_results, tess_results_df, "tess", LLM)


# Process NCRM ------------------------------------------------------------

ncrm_results <- process_posts(ncrm_posts, instructions = instructions, llm = LLM, database = "ncrm", backup_file = "tmp/results_backup.Rds")
ncrm_results_df <- postprocess_results(ncrm_results, ncrm_posts, database = "ncrm")
write_results(ncrm_results, ncrm_results_df, "tess", LLM)
