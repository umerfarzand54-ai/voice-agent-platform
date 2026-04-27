defmodule MyApp.Services.ElevenLabs do
  @moduledoc """
  ElevenLabs API client for voice cloning and text-to-speech synthesis.
  """

  @base_url "https://api.elevenlabs.io/v1"

  def synthesize(text, voice_id, opts \\ []) do
    model_id = Keyword.get(opts, :model_id, "eleven_turbo_v2_5")
    stability = Keyword.get(opts, :stability, 0.5)
    similarity_boost = Keyword.get(opts, :similarity_boost, 0.75)

    body = %{
      text: text,
      model_id: model_id,
      voice_settings: %{
        stability: stability,
        similarity_boost: similarity_boost
      }
    }

    case request(:post, "/text-to-speech/#{voice_id}", body, raw_response: true) do
      {:ok, audio_bytes} ->
        filename = "tts_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}.mp3"
        path = Path.join(audio_dir(), filename)
        File.write!(path, audio_bytes)
        {:ok, "/audio/#{filename}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_voices do
    case request(:get, "/voices") do
      {:ok, %{"voices" => voices}} ->
        {:ok, Enum.map(voices, &parse_voice/1)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_voice(voice_id) do
    case request(:get, "/voices/#{voice_id}") do
      {:ok, voice} -> {:ok, parse_voice(voice)}
      error -> error
    end
  end

  def add_voice(name, audio_file_paths, opts \\ []) do
    description = Keyword.get(opts, :description, "")
    labels = Keyword.get(opts, :labels, %{})

    form_data =
      [
        {"name", name},
        {"description", description},
        {"labels", Jason.encode!(labels)}
      ] ++
        Enum.map(audio_file_paths, fn path ->
          {"files", {File.read!(path), filename: Path.basename(path), content_type: "audio/mpeg"}}
        end)

    case request_multipart(:post, "/voices/add", form_data) do
      {:ok, %{"voice_id" => voice_id}} -> {:ok, voice_id}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_voice(voice_id) do
    case request(:delete, "/voices/#{voice_id}") do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp parse_voice(v) do
    %{
      voice_id: v["voice_id"],
      name: v["name"],
      category: v["category"],
      description: v["description"],
      preview_url: v["preview_url"],
      labels: v["labels"] || %{}
    }
  end

  defp audio_dir do
    dir = Path.join([:code.priv_dir(:my_app), "static", "audio"])
    File.mkdir_p!(dir)
    dir
  end

  defp request(method, path, body \\ nil, opts \\ []) do
    api_key = Application.get_env(:my_app, :elevenlabs_api_key) || System.get_env("ELEVENLABS_API_KEY")

    headers = [
      {"xi-api-key", api_key},
      {"accept", "application/json"},
      {"content-type", "application/json"}
    ]

    req_opts = [headers: headers]
    req_opts = if body, do: Keyword.put(req_opts, :json, body), else: req_opts

    raw = Keyword.get(opts, :raw_response, false)

    case apply(Req, method, ["#{@base_url}#{path}", req_opts]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        if raw, do: {:ok, body}, else: {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "ElevenLabs error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp request_multipart(method, path, form_data) do
    api_key = Application.get_env(:my_app, :elevenlabs_api_key) || System.get_env("ELEVENLABS_API_KEY")

    headers = [{"xi-api-key", api_key}]

    case apply(Req, method, ["#{@base_url}#{path}", [headers: headers, form_multipart: form_data]]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "ElevenLabs error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
