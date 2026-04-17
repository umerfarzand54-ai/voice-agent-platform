defmodule MyApp.Calls.ConversationTurn do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "conversation_turns" do
    field :turn_index, :integer
    field :role, :string
    field :content, :string
    field :language, :string
    field :confidence, :float
    field :audio_url, :string
    field :latency_ms, :integer
    field :tokens_used, :integer
    field :inserted_at, :utc_datetime

    belongs_to :call, MyApp.Calls.Call
  end

  def changeset(turn, attrs) do
    turn
    |> cast(attrs, ~w(call_id turn_index role content language confidence audio_url latency_ms tokens_used inserted_at)a)
    |> validate_required([:call_id, :turn_index, :role, :content])
    |> validate_inclusion(:role, ~w(user assistant system))
    |> unique_constraint([:call_id, :turn_index])
  end
end
