defmodule MyAppWeb.MediaStreamHandler do
  @behaviour WebSock

  alias MyApp.{Calls, Agents, Contacts}
  alias MyApp.Calls.{CallSupervisor, CallSession}
  alias MyApp.Services.{Whisper, Twilio}

  @silence_threshold 200
  @silence_frames_required 20
  @min_speech_frames 8

  @impl true
  def init(_opts) do
    {:ok, %{
      call_sid: nil,
      call_id: nil,
      agent: nil,
      stream_sid: nil,
      audio_buffer: [],
      speech_frames: 0,
      silence_frames: 0,
      is_speaking: false
    }}
  end

  @impl true
  def handle_in({text, [opcode: :text]}, state) do
    case Jason.decode(text) do
      {:ok, msg} -> handle_message(msg, state)
      _ -> {:ok, state}
    end
  end

  def handle_in(_frame, state), do: {:ok, state}

  @impl true
  def handle_info(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok

  defp handle_message(%{"event" => "connected"}, state), do: {:ok, state}

  defp handle_message(%{"event" => "start", "start" => start_data, "streamSid" => stream_sid}, state) do
    call_sid = start_data["callSid"]
    call = Calls.get_call_by_sid(call_sid)

    state =
      if call do
        agent = call.ai_agent_id && Agents.get_agent!(call.ai_agent_id)
        %{state | call_sid: call_sid, call_id: call.id, agent: agent, stream_sid: stream_sid}
      else
        state
      end

    {:ok, state}
  end

  defp handle_message(%{"event" => "media", "media" => %{"payload" => payload}}, state) do
    if state.call_id == nil do
      {:ok, state}
    else
      audio_chunk = Base.decode64!(payload)
      rms = compute_rms(audio_chunk)

      state =
        if rms > @silence_threshold do
          %{state |
            audio_buffer: state.audio_buffer ++ [audio_chunk],
            speech_frames: state.speech_frames + 1,
            silence_frames: 0,
            is_speaking: true
          }
        else
          silence_frames = state.silence_frames + 1

          if state.is_speaking &&
               silence_frames >= @silence_frames_required &&
               state.speech_frames >= @min_speech_frames do
            process_speech(state)
            %{state | audio_buffer: [], speech_frames: 0, silence_frames: 0, is_speaking: false}
          else
            %{state | silence_frames: silence_frames}
          end
        end

      {:ok, state}
    end
  end

  defp handle_message(%{"event" => "stop"}, state), do: {:ok, state}
  defp handle_message(_msg, state), do: {:ok, state}

  defp process_speech(state) do
    audio_bytes = Enum.join(state.audio_buffer)
    call_id = state.call_id
    agent = state.agent
    call_sid = state.call_sid

    Task.start(fn ->
      language = (agent && agent.language_code) || "en-IN"

      result = Whisper.transcribe(audio_bytes, language: language, mulaw: true)

      case result do
        {:ok, %{text: text}} when text != "" ->
          text = String.trim(text)
          case CallSession.process_turn(call_id, text) do
            {:ok, turn_result} -> handle_result(turn_result, call_sid, agent)
            {:error, reason} -> require Logger; Logger.error("CallSession error: #{inspect(reason)}")
          end

        {:ok, _} ->
          :ok

        {:error, reason} ->
          require Logger
          Logger.error("STT failed: #{inspect(reason)}")
      end
    end)
  end

  defp handle_result({:continue, nil, text}, call_sid, agent) do
    language = (agent && agent.language_code) || "en-IN"
    inject_twiml(call_sid, say_twiml(text, language))
  end

  defp handle_result({:continue, audio_url, _text}, call_sid, _agent) do
    base_url = System.get_env("APP_BASE_URL")
    inject_twiml(call_sid, play_twiml("#{base_url}#{audio_url}"))
  end

  defp handle_result({:hangup, nil, text}, call_sid, agent) do
    language = (agent && agent.language_code) || "en-IN"
    inject_twiml(call_sid, hangup_twiml(text || "Thank you. Goodbye.", language: language))
  end

  defp handle_result({:hangup, audio_url, _text}, call_sid, _agent) do
    base_url = System.get_env("APP_BASE_URL")
    inject_twiml(call_sid, hangup_twiml(nil, play_url: "#{base_url}#{audio_url}"))
  end

  defp inject_twiml(call_sid, twiml) do
    Twilio.update_call(call_sid, twiml)
  end

  defp stream_url do
    base = System.get_env("APP_BASE_URL") || ""
    ws = base |> String.replace("https://", "wss://") |> String.replace("http://", "ws://")
    "#{ws}/media-stream/websocket"
  end

  defp play_twiml(url) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
      <Play>#{url}</Play>
      <Connect><Stream url="#{stream_url()}" /></Connect>
    </Response>
    """
  end

  defp say_twiml(text, language) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
      <Say language="#{language}">#{text}</Say>
      <Connect><Stream url="#{stream_url()}" /></Connect>
    </Response>
    """
  end

  defp hangup_twiml(text, opts) do
    play_url = Keyword.get(opts, :play_url)
    language = Keyword.get(opts, :language, "en-IN")

    content =
      if play_url,
        do: "<Play>#{play_url}</Play>",
        else: "<Say language=\"#{language}\">#{text}</Say>"

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
      #{content}
      <Hangup/>
    </Response>
    """
  end

  defp compute_rms(mulaw_bytes) do
    samples = for <<byte <- mulaw_bytes>>, do: decode_mulaw(byte)
    n = length(samples)
    if n == 0 do
      0
    else
      sum_sq = Enum.reduce(samples, 0, fn s, acc -> acc + s * s end)
      :math.sqrt(sum_sq / n) |> round()
    end
  end

  defp decode_mulaw(byte) do
    import Bitwise
    byte = bxor(byte, 0xFF)
    sign = band(byte, 0x80)
    exponent = band(bsr(byte, 4), 0x07)
    mantissa = band(byte, 0x0F)
    sample = bsl(bor(mantissa, 0x10), exponent + 1) - 33
    if sign != 0, do: -sample, else: sample
  end
end
