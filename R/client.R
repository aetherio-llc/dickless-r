# Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Create a dickless.io API client
#'
#' @param api_key Your dickless.io API key
#' @param base_url Base URL (default: "https://dickless.io")
#' @param default_gateway_mode Default AI gateway mode (NULL, "byok", "pooled", or "dedicated")
#' @return A dickless client object
#' @export
dickless_client <- function(api_key, base_url = "https://dickless.io", default_gateway_mode = NULL) {
  structure(
    list(api_key = api_key, base_url = base_url, default_gateway_mode = default_gateway_mode),
    class = "dickless_client"
  )
}

# Private helper
.dickless_request <- function(client, method, path, body = NULL) {
  url <- paste0(client$base_url, path)
  req <- httr2::request(url) |>
    httr2::req_headers(
      Authorization = paste("Bearer", client$api_key),
      `Content-Type` = "application/json"
    ) |>
    httr2::req_method(method)

  if (!is.null(body)) {
    req <- req |> httr2::req_body_json(body, auto_unbox = TRUE)
  }

  resp <- req |> httr2::req_perform()
  result <- httr2::resp_body_json(resp)

  if (!isTRUE(result$success)) {
    stop(paste0("dickless API error (", result$error$code, "): ", result$error$message), call. = FALSE)
  }

  result$data
}

#' Moderate text for harmful content
#'
#' @param client A dickless client
#' @param text Text to moderate (1-10000 chars)
#' @return List with safe, categories, overallScore
#' @export
moderate_text <- function(client, text) {
  .dickless_request(client, "POST", "/api/v1/moderate/text", list(text = text))
}

#' Moderate an image for NSFW content
#'
#' @param client A dickless client
#' @param image Base64-encoded image
#' @param format Image format ("png", "jpeg", or "webp")
#' @return List with safe, categories, overallScore
#' @export
moderate_image <- function(client, image, format = NULL) {
  body <- list(image = image)
  if (!is.null(format)) body$format <- format
  .dickless_request(client, "POST", "/api/v1/moderate/image", body)
}

#' Redact PII from text
#'
#' @param client A dickless client
#' @param text Text containing PII
#' @param entities Character vector of entity types to target (NULL for all)
#' @return List with redacted, entities, entityCount
#' @export
redact <- function(client, text, entities = NULL) {
  body <- list(text = text)
  if (!is.null(entities)) body$entities <- entities
  .dickless_request(client, "POST", "/api/v1/redact", body)
}

#' Send a chat request through the AI gateway
#'
#' @param client A dickless client
#' @param model Model name (e.g. "gpt-4o", "claude-sonnet-4-5", "gemini-2.0-flash")
#' @param messages List of message lists with role and content
#' @param provider Provider override (NULL for auto-detect)
#' @param temperature Sampling temperature (0-2)
#' @param max_tokens Maximum tokens
#' @param gateway_mode Gateway mode ("byok", "pooled", or "dedicated")
#' @return List with id, model, provider, choices, usage
#' @export
chat <- function(client, model, messages, provider = NULL, temperature = NULL,
                 max_tokens = NULL, gateway_mode = NULL) {
  body <- list(model = model, messages = messages)
  if (!is.null(provider)) body$provider <- provider
  if (!is.null(temperature)) body$temperature <- temperature
  if (!is.null(max_tokens)) body$max_tokens <- max_tokens
  gm <- gateway_mode %||% client$default_gateway_mode
  if (!is.null(gm)) body$gateway_mode <- gm
  .dickless_request(client, "POST", "/api/v1/ai/chat", body)
}

#' Get AI gateway credit balance
#'
#' @param client A dickless client
#' @return List with balanceCents, lifetimePurchasedCents, etc.
#' @export
get_credit_balance <- function(client) {
  .dickless_request(client, "GET", "/api/v1/ai/manage/credits/balance")
}

#' Get AI gateway credit transactions
#'
#' @param client A dickless client
#' @return List of transaction records
#' @export
get_credit_transactions <- function(client) {
  .dickless_request(client, "GET", "/api/v1/ai/manage/credits/transactions")
}

#' Sanitize a prompt for injection attacks
#'
#' @param client A dickless client
#' @param prompt The prompt to check
#' @param strict If TRUE, strip detected threats
#' @return List with clean, sanitized, threatScore, threats
#' @export
sanitize <- function(client, prompt, strict = FALSE) {
  .dickless_request(client, "POST", "/api/v1/sanitize", list(prompt = prompt, strict = strict))
}

#' Create a short URL
#'
#' @param client A dickless client
#' @param url Target URL
#' @param custom_code Optional custom short code
#' @return List with code, shortUrl, targetUrl, qrCode
#' @export
shorten <- function(client, url, custom_code = NULL) {
  body <- list(url = url)
  if (!is.null(custom_code)) body$customCode <- custom_code
  .dickless_request(client, "POST", "/api/v1/shorten", body)
}

#' Get short URL click statistics
#'
#' @param client A dickless client
#' @param code Short URL code
#' @return List with code, targetUrl, clicks, createdAt
#' @export
get_short_url_stats <- function(client, code) {
  .dickless_request(client, "GET", paste0("/api/v1/shorten/", code, "/stats"))
}

#' Validate a value against a type
#'
#' @param client A dickless client
#' @param type Validation type (e.g. "email", "url", "phone")
#' @param value The value to validate
#' @param deep Optional deep validation flag (NULL for API default)
#' @return List with valid, type, value, errors
#' @export
validate <- function(client, type, value, deep = NULL) {
  body <- list(type = type, value = value)
  if (!is.null(deep)) body$deep <- deep
  .dickless_request(client, "POST", "/api/v1/validate", body)
}

#' Extract text from an image using OCR
#'
#' @param client A dickless client
#' @param image Base64-encoded image or URL
#' @param format Optional image format hint ("png", "jpeg", "webp")
#' @param language Optional language hint
#' @return List with text, confidence, language, pageCount
#' @export
ocr <- function(client, image, format = NULL, language = NULL) {
  body <- list(image = image)
  if (!is.null(format)) body$format <- format
  if (!is.null(language)) body$language <- language
  .dickless_request(client, "POST", "/api/v1/ocr", body)
}

#' Translate text to a target language
#'
#' @param client A dickless client
#' @param text Text to translate
#' @param to Target language code (e.g. "es", "fr", "de")
#' @param from Optional source language code (NULL for auto-detection)
#' @param model Optional translation model
#' @return List with translatedText, detectedLanguage, targetLanguage, model
#' @export
translate <- function(client, text, to, from = NULL, model = NULL) {
  body <- list(text = text, to = to)
  if (!is.null(from)) body$from <- from
  if (!is.null(model)) body$model <- model
  .dickless_request(client, "POST", "/api/v1/translate", body)
}

#' Capture a screenshot of a web page
#'
#' @param client A dickless client
#' @param url The URL to capture
#' @param format Optional image format ("png", "jpeg")
#' @param width Optional viewport width
#' @param height Optional viewport height
#' @param full_page Optional full-page capture flag
#' @param wait_for Optional wait time in milliseconds
#' @return List with image, format, width, height, url
#' @export
screenshot <- function(client, url, format = NULL, width = NULL, height = NULL,
                       full_page = NULL, wait_for = NULL) {
  body <- list(url = url)
  if (!is.null(format)) body$format <- format
  if (!is.null(width)) body$width <- width
  if (!is.null(height)) body$height <- height
  if (!is.null(full_page)) body$fullPage <- full_page
  if (!is.null(wait_for)) body$waitFor <- wait_for
  .dickless_request(client, "POST", "/api/v1/screenshot", body)
}

#' Analyse text for sentiment
#'
#' @param client A dickless client
#' @param text Text to analyse
#' @param granularity Optional granularity ("sentence", "paragraph")
#' @return List with sentiment, score, positive, negative, neutral
#' @export
sentiment <- function(client, text, granularity = NULL) {
  body <- list(text = text)
  if (!is.null(granularity)) body$granularity <- granularity
  .dickless_request(client, "POST", "/api/v1/sentiment", body)
}

#' Summarize text or a web page
#'
#' @param client A dickless client
#' @param text Optional text to summarize
#' @param url Optional URL to summarize
#' @param max_length Optional maximum summary length
#' @param format Optional output format
#' @return List with summary, originalLength, summaryLength, format
#' @export
summarize <- function(client, text = NULL, url = NULL, max_length = NULL, format = NULL) {
  body <- list()
  if (!is.null(text)) body$text <- text
  if (!is.null(url)) body$url <- url
  if (!is.null(max_length)) body$maxLength <- max_length
  if (!is.null(format)) body$format <- format
  .dickless_request(client, "POST", "/api/v1/summarize", body)
}

#' Generate an AI roast
#'
#' @param client A dickless client
#' @param text Content to roast
#' @param type Roast type: "resume", "landing_page", "code", "linkedin", or "general"
#' @param severity Roast severity: "mild", "medium", or "brutal"
#' @return List with roast, type, severity
#' @export
roast <- function(client, text, type = "general", severity = "brutal") {
  .dickless_request(client, "POST", "/api/v1/roast",
    list(text = text, type = type, severity = severity))
}
