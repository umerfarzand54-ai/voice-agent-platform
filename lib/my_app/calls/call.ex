defmodule MyApp.Calls.Call do
  use Ecto.Schema
  import Ecto.Changeset

  schema "calls" do
    field :direction, :string
    field :status, :string, default: "initiated"
    field :twilio_call_sid, :string
    field :from_number, :string
    field :to_number, :string
    field :started_at, :utc_datetime
    field :answered_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :duration_seconds, :integer
    field :recording_url, :string
    field :recording_sid, :string
    field :sentiment, :string
    field :outcome, :string
    field :outcome_notes, :string
    field :crm_synced, :boolean, default: false
    field :crm_synced_at, :utc_datetime
    field :detected_language, :string
    field :campaign_id, :integer

    belongs_to :ai_agent, MyApp.Agents.Agent
    belongs_to :contact, MyApp.Contacts.Contact
    has_many :conversation_turns, MyApp.Calls.ConversationTurn, preload_order: [asc: :turn_index]

    timestamps()
  end

  @statuses ~w(initiated ringing in_progress completed failed busy no_answer cancelled)
  @directions ~w(inbound outbound)
  @sentiments ~w(positive neutral negative)
  @outcomes ~w(goal_achieved partial not_achieved no_answer voicemail)

  def changeset(call, attrs) do
    call
    |> cast(attrs, ~w(direction status twilio_call_sid from_number to_number started_at
                       answered_at ended_at duration_seconds recording_url recording_sid
                       sentiment outcome outcome_notes crm_synced crm_synced_at
                       detected_language campaign_id ai_agent_id contact_id)a)
    |> validate_required([:direction, :status])
    |> validate_inclusion(:direction, @directions)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:sentiment, @sentiments ++ [nil])
    |> validate_inclusion(:outcome, @outcomes ++ [nil])
    |> unique_constraint(:twilio_call_sid)
  end
end
