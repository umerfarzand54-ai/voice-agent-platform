defmodule MyApp.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_agents" do
    field :name, :string
    field :description, :string
    field :voice_provider, :string, default: "elevenlabs"
    field :voice_id, :string
    field :language_code, :string, default: "en-IN"
    field :supported_languages, {:array, :string}, default: []
    field :system_prompt, :string
    field :initial_greeting, :string
    field :fallback_message, :string
    field :max_call_duration, :integer, default: 600
    field :silence_timeout, :integer, default: 5
    field :llm_model, :string, default: "claude-sonnet-4-6"
    field :llm_temperature, :float, default: 0.7
    field :active, :boolean, default: true
    field :meta, :map, default: %{}

    has_many :voice_profiles, MyApp.Agents.VoiceProfile, foreign_key: :ai_agent_id
    has_many :calls, MyApp.Calls.Call, foreign_key: :ai_agent_id

    timestamps()
  end

  @required ~w(name system_prompt)a
  @optional ~w(description voice_provider voice_id language_code supported_languages
               initial_greeting fallback_message max_call_duration silence_timeout
               llm_model llm_temperature active meta)a

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 2, max: 100)
    |> validate_inclusion(:voice_provider, ["elevenlabs", "sarvam", "twilio"])
    |> validate_number(:llm_temperature, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
    |> validate_number(:max_call_duration, greater_than: 30, less_than_or_equal_to: 3600)
  end
end
