defmodule MyAppWeb.MediaStreamChannel do
  use Phoenix.Channel

  alias MyApp.{Calls, Agents, Contacts}
  alias MyApp.Calls.{CallSupervisor, CallSession}
  alias MyApp.Services.{SarvamAI, ElevenLabs, Twilio}

  # VAD settings
  @silence_threshold 200
  @silence_frames_required 20
  @min_speech_frames 8

  @impl true
  def join("media:" <> _stream_sid, _payload, socket) do
    {:ok, assign(socket, %{
      call_sid: nil,
      call_id: nil,
      agent: nil,
      contact: nil,
      audio_buffer: [],
      speech_frames: 0,
      silence_frames: 0,
      is_speaking: false,
      stream_sid: nil
    })}
  end

  @impl true
  def handle_in("message", %{"event" => "connected"}, socket) do
    {:noreply, socket}
  end

  def handle_in("message", %{"event" => "start", "start" => start_data, "streamSid" => stream_sid}, socket) do
    call_sid = start_data["callSid"]
    call = Calls.get_call_by_sid(call_sid)

    socket =
      if call do
        agent = call.ai_agent_id && Agents.get_agent!(call.ai_agent_id)
        contact = call.contact_id && Contacts.get_contact!(call.contact_id)

        assign(socket, %{
          call_sid: call_sid,
          call_id: call.id,
          agent: agent,
          contact: contact,
          stream_sid: stream_sid
        })
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_in("message", %{"event" => "media", "media" => %{"payload" => payload}}, socket) do
    if socket.assigns.call_id == nil do
      {:noreply, socket}
    else
      audio_chunk = Base.decode64!(payload)
      rms = compute_rms(audio_chunk)

      socket =
        if rms > @silence_threshold do
          socket
          |> assign(:audio_buffer, socket.assigns.audio_buffer ++ [audio_chunk])
          |> assign(:speech_frames, socket.assigns.speech_frames + 1)
          |> assign(:silence_frames, 0)
          |> assign(:is_speaking, true)
        else
          silence_frames = socket.assigns.silence_frames + 1

          if socket.assigns.is_speaking && silence_frames >= @silence_frames_required &&
               socket.assigns.speech_frames >= @min_speech_frames do
            process_speech(socket)
            assign(socket, %{audio_buffer: [], speech_frames: 0, silence_frames: 0, is_speaking: false})
          else
            assign(socket, :silence_frames, silence_frames)
          end
        end

      {:noreply, socket}
    end
  end

  def handle_in("message", %{"event" => "stop"}, socket) do
    {:noreply, socket}
  end

  def handle_in("message", _payload, socket) do
    {:noreply, socket}
  end

  defp process_speech(socket) do
    audio_bytes = Enum.join(socket.assigns.audio_buffer)
    call_id = socket.assigns.call_id
    agent = socket.assigns.agent
    call_sid = socket.assigns.call_sid

    Task.start(fn ->
      with {:ok, text} <- transcribe(audio_bytes, agent),
           text when text != "" <- String.trim(text),
           {:ok, result} <- CallSession.process_turn(call_id, text) do
        handle_result(result, call_sid, agent, call_id)
      else
        _ -> :ok
      end
    end)
  end

  defp transcribe(audio_bytes, agent) do
    language = agent && agent.language_code || "en-IN"
    SarvamAI.transcribe(audio_bytes, language: language)
  end

  defp handle_result({:continue, nil, text}, call_sid, agent, _call_id) do
    inject_say(call_sid, text, agent.language_code)
  end

  defp handle_result({:continue, audio_url, _text}, call_sid, _agent, _call_id) do
    base_url = System.get_env("APP_BASE_URL")
    inject_play(call_sid, "#{base_url}#{audio_url}")
  end

  defp handle_result({:hangup, nil, text}, call_sid, agent, _call_id) do
    inject_say(call_sid, text || "Thank you. Goodbye.", agent.language_code)
    Twilio.end_call(call_sid)
  end

  defp handle_result({:hangup, audio_url, _text}, call_sid, _agent, _call_id) do
    base_url = System.get_env("APP_BASE_URL")
    inject_play(call_sid, "#{base_url}#{audio_url}")
    Process.sleep(4000)
    Twilio.end_call(call_sid)
  end

  defp inject_play(call_sid, url) do
    twiml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
      <Play>#{url}</Play>
      <Connect><Stream url="#{stream_url()}" /></Connect>
    </Response>
    """
    Twilio.update_call(call_sid, twiml)
  end

  defp inject_say(call_sid, text, language) do
    twiml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
      <Say language="#{language}">#{text}</Say>
      <Connect><Stream url="#{stream_url()}" /></Connect>
    </Response>
    """
    Twilio.update_call(call_sid, twiml)
  end

  defp stream_url do
    base = System.get_env("APP_BASE_URL") || ""
    ws_url = String.replace(base, "https://", "wss://") |> String.replace("http://", "ws://")
    "#{ws_url}/media-stream/websocket"
  end

  # Decode mulaw bytes and compute RMS energy for VAD
  defp compute_rms(mulaw_bytes) do
    samples =
      for <<byte <- mulaw_bytes>> do
        decode_mulaw(byte)
      end

    n = length(samples)
    if n == 0 do
      0
    else
      sum_sq = Enum.reduce(samples, 0, fn s, acc -> acc + s * s end)
      :math.sqrt(sum_sq / n) |> round()
    end
  end

  defp decode_mulaw(byte) do
    byte = Bitwise.bxor(byte, 0xFF)
    sign = Bitwise.band(byte, 0x80)
    exponent = Bitwise.band(Bitwise.bsr(byte, 4), 0x07)
    mantissa = Bitwise.band(byte, 0x0F)
    sample = Bitwise.bsl(Bitwise.bor(mantissa, 0x10), exponent + 1) - 33
    if sign != 0, do: -sample, else: sample
  end
end
