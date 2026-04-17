defmodule MyApp.Campaigns.Campaign do
  use Ecto.Schema
  import Ecto.Changeset

  schema "campaigns" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "draft"
    field :from_number, :string
    field :schedule_start, :utc_datetime
    field :schedule_end, :utc_datetime
    field :calling_window_start, :time
    field :calling_window_end, :time
    field :max_attempts, :integer, default: 3
    field :retry_delay_minutes, :integer, default: 60
    field :concurrent_calls, :integer, default: 5
    field :goal_prompt, :string
    field :total_contacts, :integer, default: 0

    belongs_to :ai_agent, MyApp.Agents.Agent
    has_many :campaign_contacts, MyApp.Campaigns.CampaignContact

    timestamps()
  end

  @statuses ~w(draft scheduled running paused completed cancelled)

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, ~w(name description status from_number schedule_start schedule_end
                       calling_window_start calling_window_end max_attempts retry_delay_minutes
                       concurrent_calls goal_prompt total_contacts ai_agent_id)a)
    |> validate_required([:name])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:max_attempts, greater_than: 0, less_than_or_equal_to: 10)
    |> validate_number(:concurrent_calls, greater_than: 0, less_than_or_equal_to: 50)
  end
end
