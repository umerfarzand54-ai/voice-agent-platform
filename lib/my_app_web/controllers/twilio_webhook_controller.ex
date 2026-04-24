defmodule MyAppWeb.TwilioWebhookController do
  use MyAppWeb, :controller

  alias MyApp.{Agents, Calls, Contacts}
  alias MyApp.Calls.{CallSupervisor, CallSession}
  alias MyApp.Services.Twilio

  @doc "Handles inbound calls from Twilio"
  def inbound_voice(conn, params) do
    call_sid = params["CallSid"]
    from = normalize_phone(params["From"])
    to = normalize_phone(params["To"])

    agent = Agents.list_active_agents() |> List.first()

    {:ok, contact} = Contacts.find_or_create_by_phone(from, %{name: params["CallerName"]})

    {:ok, call} =
      Calls.create_call(%{
        direction: "inbound",
        status: "in_progress",
        twilio_call_sid: call_sid,
        from_number: from,
        to_number: to,
        started_at: DateTime.utc_now(),
        ai_agent_id: agent && agent.id,
        contact_id: contact.id
      })

    call = MyApp.Repo.preload(call, [:contact, :ai_agent])
    Phoenix.PubSub.broadcast(MyApp.PubSub, "calls:active", {:call_started, call})

    twiml =
      if agent do
        CallSupervisor.start_call_session(call.id, call_sid, agent, contact)

        greeting = agent.initial_greeting || "Hello! How can I help you today?"
        action_url = "#{base_url(conn)}/webhooks/twilio/voice/gather?call_id=#{call.id}"

        {greeting_audio_url, _} = MyApp.Calls.CallSession.synthesize_greeting(call.id, greeting, agent)

        greeting_opt =
          if greeting_audio_url,
            do: [play_url: "#{base_url(conn)}#{greeting_audio_url}"],
            else: [say_text: greeting]

        Twilio.twiml_gather(
          [{:action, action_url}, {:language, agent.language_code}] ++ greeting_opt
        )
      else
        Twilio.twiml_voicemail("We're sorry, no agents are available. Please call back later.")
      end

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, twiml)
  end

  @doc "Handles outbound call answer (when callee picks up)"
  def outbound_answer(conn, params) do
    call_sid = params["CallSid"]
    answered_by = params["AnsweredBy"]
    call = Calls.get_call_by_sid(call_sid)

    if call do
      Calls.update_call(call, %{status: "in_progress", answered_at: DateTime.utc_now()})
    end

    twiml =
      cond do
        answered_by in ["machine_start", "machine_end_beep", "machine_end_silence"] ->
          agent = call && call.ai_agent_id && Agents.get_agent!(call.ai_agent_id)
          msg = (agent && agent.meta["voicemail_message"]) || "Hi, we tried to reach you. Please call us back."
          Twilio.twiml_voicemail(msg)

        call ->
          agent = Agents.get_agent!(call.ai_agent_id)
          contact = Contacts.get_contact!(call.contact_id)

          CallSupervisor.start_call_session(call.id, call_sid, agent, contact)

          greeting = agent.initial_greeting || "Hello! This is an automated call. How can I help you?"
          action_url = "#{base_url(conn)}/webhooks/twilio/voice/gather?call_id=#{call.id}"

          Twilio.twiml_gather(
            action: action_url,
            language: agent.language_code,
            say_text: greeting
          )

        true ->
          Twilio.twiml_reject()
      end

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, twiml)
  end

  @doc "Handles speech input from Gather and generates AI response"
  def gather(conn, params) do
    call_sid = params["CallSid"]
    speech_result = params["SpeechResult"] || ""
    _confidence = params["Confidence"] && String.to_float(params["Confidence"])
    call_id = params["call_id"]

    action_url = "#{base_url(conn)}/webhooks/twilio/voice/gather?call_id=#{call_id}"

    call = if call_id, do: Calls.get_call!(call_id), else: Calls.get_call_by_sid(call_sid)

    if call do
      agent_language = call.ai_agent && call.ai_agent.language_code || "en-IN"

      result = CallSession.process_turn(call_sid, speech_result, language: agent_language)

      twiml =
        case result do
          {:continue, nil, text} ->
            Twilio.twiml_gather(action: action_url, language: agent_language, say_text: text || "I'm sorry, I couldn't generate a response. Please try again.")

          {:continue, audio_url, _text} ->
            full_audio_url = "#{base_url(conn)}#{audio_url}"
            Twilio.twiml_gather(action: action_url, language: agent_language, play_url: full_audio_url)

          {:hangup, nil, text} ->
            Twilio.twiml_voicemail(text || "Thank you for calling. Goodbye.")

          {:hangup, audio_url, _text} ->
            full_audio_url = "#{base_url(conn)}#{audio_url}"
            Twilio.twiml_gather(farewell: true, language: agent_language, play_url: full_audio_url)

          {:error, :session_not_found} ->
            Twilio.twiml_voicemail("Your call session has expired. Please call again.")
        end

      conn
      |> put_resp_content_type("text/xml")
      |> send_resp(200, twiml)
    else
      conn
      |> put_resp_content_type("text/xml")
      |> send_resp(200, Twilio.twiml_reject())
    end
  end

  @doc "Handles call status updates from Twilio"
  def call_status(conn, params) do
    call_sid = params["CallSid"]
    twilio_status = params["CallStatus"]
    duration = params["CallDuration"] && String.to_integer(params["CallDuration"])
    recording_url = params["RecordingUrl"]

    status = map_twilio_status(twilio_status)
    call = Calls.get_call_by_sid(call_sid)

    if call do
      updates = %{status: status}

      updates =
        if twilio_status == "completed" do
          Map.merge(updates, %{
            ended_at: DateTime.utc_now(),
            duration_seconds: duration,
            recording_url: recording_url
          })
        else
          updates
        end

      {:ok, updated_call} = Calls.update_call(call, updates)

      if twilio_status == "completed" do
        case CallSession.finalize(call_sid) do
          {:ok, result} ->
            Calls.update_call(updated_call, %{
              sentiment: result.sentiment,
              outcome: result.outcome,
              detected_language: result.detected_language
            })

          _ ->
            :ok
        end

        CallSupervisor.stop_call_session(call_sid)

        Task.start(fn -> sync_to_crm(updated_call) end)
      end

      Phoenix.PubSub.broadcast(MyApp.PubSub, "calls:active", {:call_updated, updated_call})
      Phoenix.PubSub.broadcast(MyApp.PubSub, "call:#{call.id}", {:call_updated, updated_call})
    end

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, Twilio.twiml_empty())
  end

  @doc "Handles recording completion callback"
  def recording_complete(conn, params) do
    call_sid = params["CallSid"]
    recording_url = params["RecordingUrl"]

    call = Calls.get_call_by_sid(call_sid)

    if call && recording_url do
      Calls.update_call(call, %{recording_url: "#{recording_url}.mp3"})
      Phoenix.PubSub.broadcast(MyApp.PubSub, "call:#{call.id}", {:recording_ready, "#{recording_url}.mp3"})
    end

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, Twilio.twiml_empty())
  end

  defp map_twilio_status("queued"), do: "initiated"
  defp map_twilio_status("initiated"), do: "initiated"
  defp map_twilio_status("ringing"), do: "ringing"
  defp map_twilio_status("in-progress"), do: "in_progress"
  defp map_twilio_status("completed"), do: "completed"
  defp map_twilio_status("busy"), do: "busy"
  defp map_twilio_status("no-answer"), do: "no_answer"
  defp map_twilio_status("failed"), do: "failed"
  defp map_twilio_status("canceled"), do: "cancelled"
  defp map_twilio_status(_), do: "initiated"

  defp sync_to_crm(call) do
    if call.contact_id do
      contact = Contacts.get_contact!(call.contact_id)

      cond do
        Application.get_env(:my_app, :zoho_refresh_token) ->
          MyApp.Services.ZohoCRM.sync_call(call, contact)

        Application.get_env(:my_app, :bitrix24_webhook_url) ->
          MyApp.Services.Bitrix24.sync_call(call, contact)

        true ->
          :ok
      end
    end
  end

  defp normalize_phone(nil), do: nil
  defp normalize_phone(phone) do
    trimmed = String.trim(phone)
    if String.starts_with?(trimmed, "+"), do: trimmed, else: "+" <> trimmed
  end

  defp base_url(conn) do
    case System.get_env("APP_BASE_URL") do
      nil ->
        scheme = case Plug.Conn.get_req_header(conn, "x-forwarded-proto") do
          [proto | _] -> proto
          _ -> if conn.scheme == :https, do: "https", else: "http"
        end
        host = case Plug.Conn.get_req_header(conn, "x-forwarded-host") do
          [h | _] -> h
          _ -> conn.host
        end
        "#{scheme}://#{host}"
      url -> url
    end
  end
end
