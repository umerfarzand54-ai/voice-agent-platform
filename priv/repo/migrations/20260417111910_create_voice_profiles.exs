defmodule MyApp.Repo.Migrations.CreateVoiceProfiles do
  use Ecto.Migration

  def change do
    create table(:voice_profiles) do
      add :ai_agent_id, references(:ai_agents, on_delete: :nilify_all)
      add :name, :string, null: false
      add :provider, :string, null: false
      add :external_voice_id, :string
      add :status, :string, default: "pending"
      add :sample_audio_urls, {:array, :string}, default: []
      add :language, :string, default: "en-IN"
      add :active, :boolean, default: false

      timestamps()
    end

    create index(:voice_profiles, [:ai_agent_id])
    create index(:voice_profiles, [:status])
  end
end
