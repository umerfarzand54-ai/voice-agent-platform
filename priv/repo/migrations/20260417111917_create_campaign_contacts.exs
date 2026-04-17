defmodule MyApp.Repo.Migrations.CreateCampaignContacts do
  use Ecto.Migration

  def change do
    create table(:campaign_contacts) do
      add :campaign_id, references(:campaigns, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false
      add :call_id, references(:calls, on_delete: :nilify_all)
      add :status, :string, default: "pending"
      add :attempts, :integer, default: 0
      add :last_attempted_at, :utc_datetime
      add :next_attempt_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :outcome, :string
      add :notes, :text

      timestamps()
    end

    create unique_index(:campaign_contacts, [:campaign_id, :contact_id])
    create index(:campaign_contacts, [:status])
    create index(:campaign_contacts, [:next_attempt_at])
    create index(:campaign_contacts, [:campaign_id])
  end
end
