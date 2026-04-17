defmodule MyApp.Calls.CallSession do
  @moduledoc """
  GenServer managing live call state. One process per active call.
  Holds conversation context, processes speech turns, and orchestrates AI/TTS.
  """
  use GenServer, restart: :temporary

  alias MyApp.Calls
  alias MyApp.Services.{Claude, ElevenLabs, SarvamAI}

  @max_context_turns 20
  @sarvam_languages ~w(hi-IN ta-IN te-IN kn-IN ml-IN bn-IN gu-IN mr-IN pa-IN)

  defstruct [
    :call_id,
    :call_sid,
    :agent,
    :contact,
    :detected_language,
    :turn_count,
    :silence_count,
    :context_window,
    :should_hangup,
    :started_at
  ]

  def start_link({call_id, call_sid, agent, contact}) do
    GenServer.start_link(__MODULE__, {call_id, call_sid, agent, contact},
      name: via_registry(call_sid)
    )
  end

  def whereis(call_sid) do
    case Registry.lookup(MyApp.Calls.CallRegistry, call_sid) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  def process_turn(call_sid, speech_text, opts \\ []) do
    case whereis(call_sid) do
      nil -> {:error, :session_not_found}
      pid -> GenServer.call(pid, {:process_turn, speech_text, opts}, 30_000)
    end
  end

  def get_state(call_sid) do
    case whereis(call_sid) do
      nil -> nil
      pid -> GenServer.call(pid, :get_state)
    end
  end

  def finalize(call_sid) do
    case whereis(call_sid) do
      nil -> {:ok, %{}}
      pid -> GenServer.call(pid, :finalize)
    end
  end

  # Server callbacks

  @impl true
  def init({call_id, call_sid, agent, contact}) do
    state = %__MODULE__{
      call_id: call_id,
      call_sid: call_sid,
      agent: agent,
      contact: contact,
      detected_language: agent.language_code,
      turn_count: 0,
      silence_count: 0,
      context_window: [],
      should_hangup: false,
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:process_turn, "", _opts}, _from, state) do
    new_silence = state.silence_count + 1
    state = %{state | silence_count: new_silence}

    if new_silence >= 3 do
      {:reply, {:hangup, nil}, %{state | should_hangup: true}}
    else
      fallback = state.agent.fallback_message || "I didn't catch that. Could you please repeat?"

      {audio_url, _latency} = synthesize(fallback, state)

      {:reply, {:continue, audio_url}, state}
    end
  end

  @impl true
  def handle_call({:process_turn, speech_text, opts}, _from, state) do
    language = Keyword.get(opts, :language, state.detected_language)
    start_time = System.monotonic_time(:millisecond)

    detected_lang = detect_language(speech_text, language, state.agent.supported_languages)
    state = %{state | detected_language: detected_lang, silence_count: 0}

    user_turn = %{role: "user", content: speech_text}
    context = append_turn(state.context_window, user_turn)

    Calls.add_conversation_turn(state.call_id, %{
      role: "user",
      content: speech_text,
      language: detected_lang
    })

    Phoenix.PubSub.broadcast(MyApp.PubSub, "call:#{state.call_id}", {:turn_added, %{role: "user", content: speech_text, language: detected_lang}})

    system_prompt = build_system_prompt(state)

    case Claude.generate_response(system_prompt, context, speech_text, model: state.agent.llm_model, temperature: state.agent.llm_temperature) do
      {:ok, %{text: response_text, tokens: tokens}} ->
        latency = System.monotonic_time(:millisecond) - start_time

        {audio_url, _synth_latency} = synthesize(response_text, state)

        Calls.add_conversation_turn(state.call_id, %{
          role: "assistant",
          content: response_text,
          language: detected_lang,
          audio_url: audio_url,
          latency_ms: latency,
          tokens_used: tokens
        })

        Phoenix.PubSub.broadcast(MyApp.PubSub, "call:#{state.call_id}", {:turn_added, %{role: "assistant", content: response_text, language: detected_lang, audio_url: audio_url}})

        assistant_turn = %{role: "assistant", content: response_text}
        updated_context = append_turn(context, assistant_turn)

        turn_count = state.turn_count + 1
        max_turns = div(state.agent.max_call_duration, 30)
        should_hangup = turn_count >= max_turns or String.contains?(response_text, "[END_CALL]")

        new_state = %{state | context_window: updated_context, turn_count: turn_count, should_hangup: should_hangup}

        if should_hangup do
          {:reply, {:hangup, audio_url}, new_state}
        else
          {:reply, {:continue, audio_url}, new_state}
        end

      {:error, reason} ->
        fallback = state.agent.fallback_message || "I'm having technical difficulties. Please try again."
        {audio_url, _} = synthesize(fallback, state)
        {:reply, {:continue, audio_url}, state}
        _ = reason
    end
  end

  @impl true
  def handle_call(:finalize, _from, state) do
    full_text =
      state.context_window
      |> Enum.map_join(" ", & &1.content)

    sentiment =
      case Claude.detect_sentiment(full_text) do
        {:ok, s} -> s
        _ -> "neutral"
      end

    outcome =
      case Claude.classify_outcome(state.agent.system_prompt, state.context_window) do
        {:ok, o} -> o
        _ -> "partial"
      end

    result = %{
      sentiment: sentiment,
      outcome: outcome,
      turn_count: state.turn_count,
      detected_language: state.detected_language
    }

    {:reply, {:ok, result}, state}
  end

  defp via_registry(call_sid) do
    {:via, Registry, {MyApp.Calls.CallRegistry, call_sid}}
  end

  defp append_turn(context, turn) do
    context = context ++ [turn]
    if length(context) > @max_context_turns do
      Enum.drop(context, length(context) - @max_context_turns)
    else
      context
    end
  end

  defp build_system_prompt(state) do
    contact_info =
      if state.contact do
        "You are speaking with #{state.contact.name || "the customer"} at #{state.contact.phone_number}."
      else
        "You are speaking with a caller."
      end

    """
    #{state.agent.system_prompt}

    #{contact_info}
    Current language: #{state.detected_language}
    Turn #{state.turn_count + 1} of the conversation.

    If you determine the call goal is achieved or the conversation should end naturally, include [END_CALL] at the end of your response.
    Respond naturally and concisely as this is a phone call. Keep responses under 50 words unless necessary.
    """
  end

  defp detect_language(text, current_lang, supported_languages) do
    if current_lang in @sarvam_languages do
      case SarvamAI.detect_language(text) do
        {:ok, lang} ->
          if lang in (supported_languages ++ [current_lang]), do: lang, else: current_lang

        _ ->
          current_lang
      end
    else
      current_lang
    end
  end

  defp synthesize(text, state) do
    start = System.monotonic_time(:millisecond)

    result =
      cond do
        state.detected_language in @sarvam_languages ->
          speaker = Map.get(state.agent.meta || %{}, "sarvam_speaker", "meera")
          SarvamAI.synthesize(text, language: state.detected_language, speaker: speaker)

        state.agent.voice_id ->
          ElevenLabs.synthesize(text, state.agent.voice_id)

        true ->
          {:error, "No voice configured"}
      end

    latency = System.monotonic_time(:millisecond) - start

    case result do
      {:ok, url} -> {url, latency}
      {:error, _} -> {nil, latency}
    end
  end
end
