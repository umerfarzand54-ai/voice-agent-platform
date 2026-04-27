defmodule MyApp.Services.Whisper do
  @base_url "https://api.openai.com/v1"

  def transcribe(audio_binary, opts \\ []) do
    language = Keyword.get(opts, :language, nil)
    is_mulaw = Keyword.get(opts, :mulaw, false)

    wav_bytes = if is_mulaw, do: mulaw_to_wav(audio_binary), else: audio_binary

    api_key = System.get_env("OPENAI_API_KEY")

    boundary = "boundary#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"

    parts =
      [{"file", {wav_bytes, filename: "audio.wav", content_type: "audio/wav"}},
       {"model", "whisper-1"}] ++
        if(language, do: [{"language", language_code(language)}], else: [])

    {body, content_type} = encode_multipart(parts, boundary)

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", content_type}
    ]

    case Req.post("#{@base_url}/audio/transcriptions", headers: headers, body: body) do
      {:ok, %{status: status, body: %{"text" => text}}} when status in 200..299 ->
        {:ok, %{text: text, language: language || "en"}}

      {:ok, %{status: status, body: body}} ->
        {:error, "Whisper error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp language_code("en-IN"), do: "en"
  defp language_code("hi-IN"), do: "hi"
  defp language_code("ta-IN"), do: "ta"
  defp language_code("te-IN"), do: "te"
  defp language_code("kn-IN"), do: "kn"
  defp language_code("ml-IN"), do: "ml"
  defp language_code("bn-IN"), do: "bn"
  defp language_code("gu-IN"), do: "gu"
  defp language_code("mr-IN"), do: "mr"
  defp language_code("pa-IN"), do: "pa"
  defp language_code(lang), do: lang

  defp encode_multipart(parts, boundary) do
    body =
      Enum.map_join(parts, "", fn
        {name, {binary, opts}} when is_binary(binary) ->
          filename = Keyword.get(opts, :filename, "file")
          content_type = Keyword.get(opts, :content_type, "application/octet-stream")
          "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\"\r\nContent-Type: #{content_type}\r\n\r\n" <>
            binary <> "\r\n"

        {name, value} ->
          "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n"
      end) <> "--#{boundary}--\r\n"

    {body, "multipart/form-data; boundary=#{boundary}"}
  end

  defp mulaw_to_wav(mulaw_bytes) do
    sample_rate = 8000
    num_channels = 1
    bits_per_sample = 8
    audio_format = 7
    byte_rate = sample_rate * num_channels * div(bits_per_sample, 8)
    block_align = num_channels * div(bits_per_sample, 8)
    data_size = byte_size(mulaw_bytes)
    chunk_size = 36 + data_size

    <<
      "RIFF",
      chunk_size::little-32,
      "WAVE",
      "fmt ",
      16::little-32,
      audio_format::little-16,
      num_channels::little-16,
      sample_rate::little-32,
      byte_rate::little-32,
      block_align::little-16,
      bits_per_sample::little-16,
      "data",
      data_size::little-32,
      mulaw_bytes::binary
    >>
  end
end
