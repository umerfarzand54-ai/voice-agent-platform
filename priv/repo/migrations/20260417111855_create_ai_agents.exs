defmodule MyApp.Repo.Migrations.CreateAiAgents do
  use Ecto.Migration

  def change do
    create table(:ai_agents) do
      add :name, :string, null: false
      add :description, :text
      add :voice_provider, :string, default: "elevenlabs"
      add :voice_id, :string
      add :language_code, :string, default: "en-IN"
      add :supported_languages, {:array, :string}, default: []
      add :system_prompt, :text, null: false
      add :initial_greeting, :text
      add :fallback_message, :text
      add :max_call_duration, :integer, default: 600
      add :silence_timeout, :integer, default: 5
      add :llm_model, :string, default: "claude-sonnet-4-6"
      add :llm_temperature, :float, default: 0.7
      add :active, :boolean, default: true
      add :meta, :map, default: %{}

      timestamps()
    end

    create index(:ai_agents, [:active])
  end
end
