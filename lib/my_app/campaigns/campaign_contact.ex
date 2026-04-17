defmodule MyApp.Campaigns.CampaignContact do
  use Ecto.Schema
  import Ecto.Changeset

  schema "campaign_contacts" do
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :last_attempted_at, :utc_datetime
    field :next_attempt_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :outcome, :string
    field :notes, :string

    belongs_to :campaign, MyApp.Campaigns.Campaign
    belongs_to :contact, MyApp.Contacts.Contact
    belongs_to :call, MyApp.Calls.Call

    timestamps()
  end

  @statuses ~w(pending scheduled in_progress completed failed opted_out)

  def changeset(cc, attrs) do
    cc
    |> cast(attrs, ~w(campaign_id contact_id call_id status attempts last_attempted_at
                       next_attempt_at completed_at outcome notes)a)
    |> validate_required([:campaign_id, :contact_id])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:campaign_id, :contact_id])
  end
end
