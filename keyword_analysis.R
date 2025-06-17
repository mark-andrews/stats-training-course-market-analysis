library(ellmer)

instructions <- readLines("keyword_instructions.md") |> str_c(collapse = "\n")

client <- chat_openai(system_prompt = instructions, model = "o3")

keywords <- readLines("data/example_keywords.txt")

results <- map(keywords[1:10], client$chat)

keywords
