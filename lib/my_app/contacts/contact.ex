defmodule MyApp.Contacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  schema "contacts" do
    field :phone_number, :string
    field :name, :string
    field :email, :string
    field :language_pref, :string, default: "en-IN"
    field :timezone, :string, default: "Asia/Kolkata"
    field :tags, {:array, :string}, default: []
    field :crm_source, :string
    field :crm_id, :string
    field :meta, :map, default: %{}
    field :opted_out, :boolean, default: false
    field :opted_out_at, :utc_datetime

    has_many :calls, MyApp.Calls.Call
    has_many :campaign_contacts, MyApp.Campaigns.CampaignContact

    timestamps()
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, ~w(phone_number name email language_pref timezone tags crm_source crm_id meta opted_out opted_out_at)a)
    |> validate_required([:phone_number])
    |> validate_format(:phone_number, ~r/^\+[1-9]\d{6,14}$/, message: "must be E.164 format (e.g. +919876543210)")
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> unique_constraint(:phone_number)
  end
end
