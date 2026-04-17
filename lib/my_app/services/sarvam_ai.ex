defmodule MyApp.Services.SarvamAI do
  @moduledoc """
  Sarvam AI client for Indian language speech-to-text and text-to-speech.
  Supports: Hindi (hi-IN), Tamil (ta-IN), Telugu (te-IN), Kannada (kn-IN),
            Malayalam (ml-IN), Bengali (bn-IN), Gujarati (gu-IN), Marathi (mr-IN)
  """

  @base_url "https://api.sarvam.ai"

  @supported_languages ~w(hi-IN ta-IN te-IN kn-IN ml-IN bn-IN gu-IN mr-IN pa-IN)

  def supported_languages, do: @supported_languages

  def transcribe(audio_binary, opts \\ []) do
    language = Keyword.get(opts, :language, "hi-IN")
    model = Keyword.get(opts, :model, "saarika:v1")

    form_data = [
      {"file", {audio_binary, filename: "audio.wav", content_type: "audio/wav"}},
      {"language_code", language},
      {"model", model}
    ]

    case request_multipart(:post, "/speech-to-text", form_data) do
      {:ok, %{"transcript" => transcript, "language_code" => detected_lang}} ->
        {:ok, %{text: transcript, language: detected_lang}}

      {:ok, %{"transcript" => transcript}} ->
        {:ok, %{text: transcript, language: language}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def synthesize(text, opts \\ []) do
    language = Keyword.get(opts, :language, "hi-IN")
    speaker = Keyword.get(opts, :speaker, "meera")
    pitch = Keyword.get(opts, :pitch, 0)
    pace = Keyword.get(opts, :pace, 1.0)
    loudness = Keyword.get(opts, :loudness, 1.5)
    model = Keyword.get(opts, :model, "bulbul:v1")

    body = %{
      inputs: [text],
      target_language_code: language,
      speaker: speaker,
      pitch: pitch,
      pace: pace,
      loudness: loudness,
      speech_sample_rate: 8000,
      enable_preprocessing: true,
      model: model
    }

    case request(:post, "/text-to-speech", body) do
      {:ok, %{"audios" => [audio_base64 | _]}} ->
        audio_bytes = Base.decode64!(audio_base64)
        filename = "sarvam_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}.wav"
        path = Path.join(audio_dir(), filename)
        File.write!(path, audio_bytes)
        {:ok, "/audio/#{filename}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def detect_language(text) do
    body = %{input: text}

    case request(:post, "/text-lid", body) do
      {:ok, %{"language_code" => lang}} -> {:ok, lang}
      {:error, reason} -> {:error, reason}
    end
  end

  def translate(text, source_language, target_language \\ "en-IN") do
    body = %{
      input: text,
      source_language_code: source_language,
      target_language_code: target_language,
      speaker_gender: "Female",
      mode: "formal",
      enable_preprocessing: true
    }

    case request(:post, "/translate", body) do
      {:ok, %{"translated_text" => translated}} -> {:ok, translated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp audio_dir do
    dir = Path.join([:code.priv_dir(:my_app), "static", "audio"])
    File.mkdir_p!(dir)
    dir
  end

  defp request(method, path, body \\ nil) do
    api_key = Application.get_env(:my_app, :sarvam_api_key) || System.get_env("SARVAM_API_KEY")

    headers = [
      {"api-subscription-key", api_key},
      {"content-type", "application/json"}
    ]

    req_opts = [headers: headers]
    req_opts = if body, do: Keyword.put(req_opts, :json, body), else: req_opts

    case apply(Req, method, ["#{@base_url}#{path}", req_opts]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "Sarvam error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp request_multipart(method, path, form_data) do
    api_key = Application.get_env(:my_app, :sarvam_api_key) || System.get_env("SARVAM_API_KEY")

    headers = [{"api-subscription-key", api_key}]

    case apply(Req, method, ["#{@base_url}#{path}", [headers: headers, form: form_data]]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "Sarvam error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
