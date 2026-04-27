defmodule MyAppWeb.VoiceProfilesLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Agents

  @max_file_size 50 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    profiles = Agents.list_voice_profiles()
    agents = Agents.list_active_agents()

    socket =
      socket
      |> assign(:page_title, "Voice Profiles")
      |> assign(:agents, Enum.map(agents, &{&1.name, &1.id}))
      |> assign(:form, to_form(%{"name" => "", "provider" => "elevenlabs", "language" => "en-IN", "ai_agent_id" => ""}))
      |> assign(:cloning_status, nil)
      |> stream(:profiles, profiles)
      |> allow_upload(:audio_samples, accept: ~w(.mp3 .wav .m4a), max_entries: 5, max_file_size: @max_file_size)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("clone_voice", %{"name" => name, "language" => language, "ai_agent_id" => agent_id} = params, socket) do
    provider = Map.get(params, "provider", "elevenlabs")
    audio_paths =
      consume_uploaded_entries(socket, :audio_samples, fn %{path: path}, entry ->
        dest = Path.join(System.tmp_dir!(), entry.client_name)
        File.cp!(path, dest)
        {:ok, dest}
      end)

    socket = assign(socket, :cloning_status, "uploading")

    Task.start(fn ->
      result = MyApp.Services.ElevenLabs.add_voice(name, audio_paths, description: "Voice clone for #{name}")

      case result do
        {:ok, voice_id} ->
          Agents.create_voice_profile(%{
            name: name,
            provider: provider,
            external_voice_id: voice_id,
            language: language,
            ai_agent_id: if(agent_id == "", do: nil, else: String.to_integer(agent_id)),
            status: "ready",
            active: false
          })

        {:error, reason} ->
          require Logger
          Logger.error("Voice cloning failed: #{inspect(reason)}")
      end

      Enum.each(audio_paths, &File.rm/1)
    end)

    {:noreply,
     socket
     |> assign(:cloning_status, "processing")
     |> put_flash(:info, "Voice cloning started! Refresh shortly to see the new profile.")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    profile = Agents.get_voice_profile!(id)

    Task.start(fn ->
      if profile.external_voice_id do
        MyApp.Services.ElevenLabs.delete_voice(profile.external_voice_id)
      end
    end)

    {:ok, _} = Agents.delete_voice_profile(profile)
    {:noreply, stream_delete(socket, :profiles, profile)}
  end

  @impl true
  def handle_event("activate", %{"id" => id, "agent_id" => agent_id}, socket) do
    Agents.activate_voice_profile(String.to_integer(id), String.to_integer(agent_id))
    profiles = Agents.list_voice_profiles()
    {:noreply, stream(socket, :profiles, profiles, reset: true)}
  end

  defp status_badge("ready"), do: {"Ready", "bg-emerald-100 text-emerald-700"}
  defp status_badge("training"), do: {"Training", "bg-amber-100 text-amber-700"}
  defp status_badge("failed"), do: {"Failed", "bg-red-100 text-red-700"}
  defp status_badge(_), do: {"Pending", "bg-slate-100 text-slate-500"}
end
