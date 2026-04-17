defmodule MyApp.Agents.VoiceProfile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "voice_profiles" do
    field :name, :string
    field :provider, :string
    field :external_voice_id, :string
    field :status, :string, default: "pending"
    field :sample_audio_urls, {:array, :string}, default: []
    field :language, :string, default: "en-IN"
    field :active, :boolean, default: false

    belongs_to :ai_agent, MyApp.Agents.Agent

    timestamps()
  end

  @statuses ~w(pending training ready failed)

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, ~w(name provider external_voice_id status sample_audio_urls language active ai_agent_id)a)
    |> validate_required(~w(name provider)a)
    |> validate_inclusion(:provider, ["elevenlabs", "sarvam"])
    |> validate_inclusion(:status, @statuses)
  end
end
