defmodule MyApp.Agents do
  import Ecto.Query
  alias MyApp.Repo
  alias MyApp.Agents.{Agent, VoiceProfile}

  def list_agents do
    Agent
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  def list_active_agents do
    Agent
    |> where([a], a.active == true)
    |> order_by([a], asc: a.name)
    |> Repo.all()
  end

  def get_agent!(id), do: Repo.get!(Agent, id)

  def get_agent_with_profiles!(id) do
    Agent
    |> Repo.get!(id)
    |> Repo.preload(:voice_profiles)
  end

  def create_agent(attrs) do
    %Agent{}
    |> Agent.changeset(attrs)
    |> Repo.insert()
  end

  def update_agent(%Agent{} = agent, attrs) do
    agent
    |> Agent.changeset(attrs)
    |> Repo.update()
  end

  def delete_agent(%Agent{} = agent), do: Repo.delete(agent)

  def change_agent(%Agent{} = agent, attrs \\ %{}) do
    Agent.changeset(agent, attrs)
  end

  # Voice Profiles

  def list_voice_profiles do
    VoiceProfile
    |> order_by([v], desc: v.inserted_at)
    |> preload(:ai_agent)
    |> Repo.all()
  end

  def get_voice_profile!(id), do: Repo.get!(VoiceProfile, id)

  def create_voice_profile(attrs) do
    %VoiceProfile{}
    |> VoiceProfile.changeset(attrs)
    |> Repo.insert()
  end

  def update_voice_profile(%VoiceProfile{} = profile, attrs) do
    profile
    |> VoiceProfile.changeset(attrs)
    |> Repo.update()
  end

  def delete_voice_profile(%VoiceProfile{} = profile), do: Repo.delete(profile)

  def change_voice_profile(%VoiceProfile{} = profile, attrs \\ %{}) do
    VoiceProfile.changeset(profile, attrs)
  end

  def activate_voice_profile(profile_id, agent_id) do
    Repo.transaction(fn ->
      VoiceProfile
      |> where([v], v.ai_agent_id == ^agent_id)
      |> Repo.update_all(set: [active: false])

      profile = get_voice_profile!(profile_id)
      {:ok, updated_profile} = update_voice_profile(profile, %{active: true})

      agent = get_agent!(agent_id)
      update_agent(agent, %{voice_id: updated_profile.external_voice_id})

      updated_profile
    end)
  end
end
