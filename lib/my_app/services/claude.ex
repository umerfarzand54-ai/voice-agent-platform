defmodule MyApp.Services.Claude do
  @moduledoc """
  Claude API client for AI conversation generation.
  """

  @base_url "https://api.anthropic.com/v1"
  @api_version "2023-06-01"
  @voice_max_tokens 256

  def complete(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "claude-haiku-4-5-20251001")
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, @voice_max_tokens)
    system = Keyword.get(opts, :system)

    body =
      %{
        model: model,
        max_tokens: max_tokens,
        temperature: temperature,
        messages: messages
      }

    body = if system, do: Map.put(body, :system, system), else: body

    case request(:post, "/messages", body) do
      {:ok, %{"content" => [%{"text" => text} | _], "usage" => usage}} ->
        {:ok, %{text: text, tokens: usage["input_tokens"] + usage["output_tokens"]}}

      {:ok, response} ->
        {:error, "Unexpected response: #{inspect(response)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def generate_response(system_prompt, conversation_history, user_message, opts \\ []) do
    messages = conversation_history ++ [%{role: "user", content: user_message}]
    complete(messages, Keyword.put(opts, :system, system_prompt))
  end

  def detect_sentiment(text) do
    prompt = """
    Analyze the sentiment of this conversation text and respond with only one word: positive, neutral, or negative.

    Text: #{text}
    """

    case complete([%{role: "user", content: prompt}], max_tokens: 10, temperature: 0) do
      {:ok, %{text: sentiment}} ->
        sentiment = String.trim(sentiment) |> String.downcase()

        cond do
          sentiment in ["positive", "neutral", "negative"] -> {:ok, sentiment}
          true -> {:ok, "neutral"}
        end

      error ->
        error
    end
  end

  def classify_outcome(system_prompt, conversation_history) do
    prompt = """
    Based on the following conversation goal and transcript, classify the outcome.
    Respond with only one of: goal_achieved, partial, not_achieved, no_answer, voicemail

    Goal: #{system_prompt}

    Conversation:
    #{format_history(conversation_history)}
    """

    case complete([%{role: "user", content: prompt}], max_tokens: 20, temperature: 0) do
      {:ok, %{text: outcome}} ->
        outcome = String.trim(outcome) |> String.downcase()
        valid = ~w(goal_achieved partial not_achieved no_answer voicemail)

        if outcome in valid, do: {:ok, outcome}, else: {:ok, "partial"}

      error ->
        error
    end
  end

  defp format_history(history) do
    Enum.map_join(history, "\n", fn %{role: role, content: content} ->
      "#{String.capitalize(role)}: #{content}"
    end)
  end

  defp request(method, path, body \\ nil) do
    api_key = Application.get_env(:my_app, :claude_api_key) || System.get_env("CLAUDE_API_KEY")

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", @api_version},
      {"content-type", "application/json"}
    ]

    opts = [headers: headers]
    opts = if body, do: Keyword.put(opts, :json, body), else: opts

    case apply(Req, method, ["#{@base_url}#{path}", opts]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
end
