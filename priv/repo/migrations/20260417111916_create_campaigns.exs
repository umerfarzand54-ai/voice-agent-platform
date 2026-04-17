defmodule MyApp.Repo.Migrations.CreateCampaigns do
  use Ecto.Migration

  def change do
    create table(:campaigns) do
      add :ai_agent_id, references(:ai_agents, on_delete: :nilify_all)
      add :name, :string, null: false
      add :description, :text
      add :status, :string, default: "draft"
      add :from_number, :string
      add :schedule_start, :utc_datetime
      add :schedule_end, :utc_datetime
      add :calling_window_start, :time
      add :calling_window_end, :time
      add :max_attempts, :integer, default: 3
      add :retry_delay_minutes, :integer, default: 60
      add :concurrent_calls, :integer, default: 5
      add :goal_prompt, :text
      add :total_contacts, :integer, default: 0

      timestamps()
    end

    create index(:campaigns, [:status])
    create index(:campaigns, [:ai_agent_id])
  end
end
