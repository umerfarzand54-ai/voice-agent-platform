defmodule MyApp.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts) do
      add :phone_number, :string, null: false
      add :name, :string
      add :email, :string
      add :language_pref, :string, default: "en-IN"
      add :timezone, :string, default: "Asia/Kolkata"
      add :tags, {:array, :string}, default: []
      add :crm_source, :string
      add :crm_id, :string
      add :meta, :map, default: %{}
      add :opted_out, :boolean, default: false
      add :opted_out_at, :utc_datetime

      timestamps()
    end

    create unique_index(:contacts, [:phone_number])
    create index(:contacts, [:crm_source, :crm_id])
    create index(:contacts, [:opted_out])
  end
end
