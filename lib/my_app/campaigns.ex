defmodule MyApp.Campaigns do
  import Ecto.Query
  alias MyApp.Repo
  alias MyApp.Campaigns.{Campaign, CampaignContact}

  def list_campaigns do
    Campaign
    |> order_by([c], desc: c.inserted_at)
    |> preload(:ai_agent)
    |> Repo.all()
  end

  def get_campaign!(id) do
    Campaign
    |> Repo.get!(id)
    |> Repo.preload(:ai_agent)
  end

  def create_campaign(attrs) do
    %Campaign{}
    |> Campaign.changeset(attrs)
    |> Repo.insert()
  end

  def update_campaign(%Campaign{} = campaign, attrs) do
    campaign
    |> Campaign.changeset(attrs)
    |> Repo.update()
  end

  def delete_campaign(%Campaign{} = campaign), do: Repo.delete(campaign)

  def change_campaign(%Campaign{} = campaign, attrs \\ %{}) do
    Campaign.changeset(campaign, attrs)
  end

  def start_campaign(%Campaign{} = campaign) do
    update_campaign(campaign, %{status: "running"})
  end

  def pause_campaign(%Campaign{} = campaign) do
    update_campaign(campaign, %{status: "paused"})
  end

  def complete_campaign(%Campaign{} = campaign) do
    update_campaign(campaign, %{status: "completed"})
  end

  def campaign_stats(%Campaign{} = campaign) do
    stats =
      CampaignContact
      |> where([cc], cc.campaign_id == ^campaign.id)
      |> group_by([cc], cc.status)
      |> select([cc], {cc.status, count(cc.id)})
      |> Repo.all()
      |> Map.new()

    total = Repo.aggregate(from(cc in CampaignContact, where: cc.campaign_id == ^campaign.id), :count)

    %{
      total: total,
      pending: Map.get(stats, "pending", 0),
      in_progress: Map.get(stats, "in_progress", 0),
      completed: Map.get(stats, "completed", 0),
      failed: Map.get(stats, "failed", 0),
      opted_out: Map.get(stats, "opted_out", 0)
    }
  end

  # Campaign Contacts

  def list_campaign_contacts(campaign_id, opts \\ []) do
    query =
      CampaignContact
      |> where([cc], cc.campaign_id == ^campaign_id)
      |> order_by([cc], desc: cc.inserted_at)
      |> preload(:contact)

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, [cc], cc.status == ^status)
      end

    Repo.all(query)
  end

  def add_contact_to_campaign(campaign_id, contact_id) do
    %CampaignContact{}
    |> CampaignContact.changeset(%{campaign_id: campaign_id, contact_id: contact_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def get_next_pending_contacts(campaign_id, limit \\ 5) do
    now = DateTime.utc_now()

    CampaignContact
    |> where([cc], cc.campaign_id == ^campaign_id and cc.status == "pending")
    |> where([cc], is_nil(cc.next_attempt_at) or cc.next_attempt_at <= ^now)
    |> order_by([cc], asc: cc.inserted_at)
    |> limit(^limit)
    |> preload(:contact)
    |> Repo.all()
  end

  def mark_contact_in_progress(campaign_contact_id) do
    CampaignContact
    |> Repo.get!(campaign_contact_id)
    |> CampaignContact.changeset(%{
      status: "in_progress",
      last_attempted_at: DateTime.utc_now(),
      attempts: Ecto.Changeset.get_field(Repo.get!(CampaignContact, campaign_contact_id), :attempts) + 1
    })
    |> Repo.update()
  end

  def mark_contact_completed(campaign_contact_id, outcome, call_id \\ nil) do
    cc = Repo.get!(CampaignContact, campaign_contact_id)

    updates = %{
      status: "completed",
      completed_at: DateTime.utc_now(),
      outcome: outcome
    }

    updates = if call_id, do: Map.put(updates, :call_id, call_id), else: updates

    cc
    |> CampaignContact.changeset(updates)
    |> Repo.update()
  end

  def mark_contact_failed(campaign_contact_id, max_attempts) do
    cc = Repo.get!(CampaignContact, campaign_contact_id)

    cond do
      cc.attempts >= max_attempts ->
        cc |> CampaignContact.changeset(%{status: "failed"}) |> Repo.update()

      true ->
        retry_at = DateTime.add(DateTime.utc_now(), 60 * 60, :second)

        cc
        |> CampaignContact.changeset(%{status: "pending", next_attempt_at: retry_at})
        |> Repo.update()
    end
  end
end
