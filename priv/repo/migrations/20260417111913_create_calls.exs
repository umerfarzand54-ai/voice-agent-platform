defmodule MyApp.Repo.Migrations.CreateCalls do
  use Ecto.Migration

  def change do
    create table(:calls) do
      add :ai_agent_id, references(:ai_agents, on_delete: :nilify_all)
      add :contact_id, references(:contacts, on_delete: :nilify_all)
      add :campaign_id, :bigint
      add :direction, :string, null: false
      add :status, :string, default: "initiated"
      add :twilio_call_sid, :string
      add :from_number, :string
      add :to_number, :string
      add :started_at, :utc_datetime
      add :answered_at, :utc_datetime
      add :ended_at, :utc_datetime
      add :duration_seconds, :integer
      add :recording_url, :string
      add :recording_sid, :string
      add :sentiment, :string
      add :outcome, :string
      add :outcome_notes, :text
      add :crm_synced, :boolean, default: false
      add :crm_synced_at, :utc_datetime
      add :detected_language, :string

      timestamps()
    end

    create unique_index(:calls, [:twilio_call_sid])
    create index(:calls, [:ai_agent_id])
    create index(:calls, [:contact_id])
    create index(:calls, [:campaign_id])
    create index(:calls, [:status])
    create index(:calls, [:direction])
    create index(:calls, [:inserted_at])
  end
end
