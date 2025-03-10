#' @examples
#' chat <- new_chat()
#' chat$chat("What is the difference between a tibble and a data frame?")
#' chat$chat("Please summarise into a very concise bulleted list.")
#'
#' chat <- new_chat()
#' chat$add_tool(rnorm)
#' chat$chat("Give me five numbers from a random normal distribution. Briefly explain your work.")
new_chat <- function(system_prompt = NULL,
                     base_url = "https://api.openai.com/v1",
                     api_key = open_ai_key(),
                     model = "gpt-4o-mini") {


  system_prompt <- system_prompt %||%
    "You are a helpful assistant from New Zealand who is an experienced R programmer"

  chat <- Chat$new(
    base_url = base_url,
    model = model,
    api_key = api_key
  )
  chat$add_message(list(
    role = "system",
    content = system_prompt
  ))
  chat
}

Chat <- R6::R6Class("Chat", public = list(
  base_url = NULL,
  model = NULL,
  api_key = NULL,

  messages = NULL,
  tools = NULL,

  initialize = function(base_url, model, api_key) {
    self$base_url <- base_url
    self$model <- model
    self$api_key <- api_key
  },

  add_message = function(message) {
    self$messages <- c(self$messages, list(message))
    invisible(self)
  },

  add_tool = function(tool) {
    self$tools <- c(self$tools, list(tool))
    invisible(self)
  },

  register_tool = function(name, description, arguments, strict = TRUE) {
    tool <- tool_def(
      name = name,
      description = description,
      arguments = arguments,
      strict = strict
    )
    self$add_tool(tool)
  },

  chat = function(text, stream = TRUE) {
    self$add_message(list(role = "user", content = text))
    self$submit_messages(stream = stream)
    self$tool_loop()
    invisible(self)
  },

  submit_messages = function(stream = TRUE) {
    result <- open_ai_chat(
      messages = self$messages,
      tools = self$tools,
      base_url = self$base_url,
      model = self$model,
      stream = TRUE,
      api_key = self$api_key
    )
    self$add_message(result$choices[[1]]$delta)
    invisible(self)
  },

  tool_loop = function() {
    if (is.null(self$tools)) {
      return()
    }

    last_message <- self$messages[[length(self$messages)]]
    tool_message <- call_tools(last_message)

    if (is.null(tool_message)) {
      return()
    }
    self$messages <- c(self$messages, tool_message)
    self$submit_messages(stream = FALSE)
  }
))
