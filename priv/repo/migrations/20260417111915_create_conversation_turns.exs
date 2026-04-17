defmodule MyApp.Repo.Migrations.CreateConversationTurns do
  use Ecto.Migration

  def change do
    create table(:conversation_turns) do
      add :call_id, references(:calls, on_delete: :delete_all), null: false
      add :turn_index, :integer, null: false
      add :role, :string, null: false
      add :content, :text, null: false
      add :language, :string
      add :confidence, :float
      add :audio_url, :string
      add :latency_ms, :integer
      add :tokens_used, :integer

      add :inserted_at, :utc_datetime, null: false
    end

    create unique_index(:conversation_turns, [:call_id, :turn_index])
    create index(:conversation_turns, [:call_id])
  end
end
