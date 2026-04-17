defmodule MyAppWeb.CampaignsLive.Show do
  use MyAppWeb, :live_view

  alias MyApp.Campaigns

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    campaign = Campaigns.get_campaign!(id)
    stats = Campaigns.campaign_stats(campaign)
    contacts = Campaigns.list_campaign_contacts(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "campaign:#{id}")
    end

    socket =
      socket
      |> assign(:page_title, campaign.name)
      |> assign(:campaign, campaign)
      |> assign(:stats, stats)
      |> stream(:contacts, contacts)

    {:ok, socket}
  end

  @impl true
  def handle_info({:progress_updated, stats}, socket) do
    {:noreply, assign(socket, :stats, stats)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status = if status == "", do: nil, else: status
    contacts = Campaigns.list_campaign_contacts(socket.assigns.campaign.id, status: status)
    {:noreply, stream(socket, :contacts, contacts, reset: true)}
  end

  defp progress_pct(stats) do
    if stats.total > 0, do: round((stats.completed + stats.failed) / stats.total * 100), else: 0
  end

  defp status_color("completed"), do: "bg-emerald-100 text-emerald-700"
  defp status_color("in_progress"), do: "bg-blue-100 text-blue-700"
  defp status_color("failed"), do: "bg-red-100 text-red-700"
  defp status_color("opted_out"), do: "bg-slate-100 text-slate-500"
  defp status_color(_), do: "bg-amber-100 text-amber-700"
end
