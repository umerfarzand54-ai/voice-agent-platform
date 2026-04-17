defmodule MyAppWeb.CampaignsLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.{Campaigns, Services}

  @impl true
  def mount(_params, _session, socket) do
    campaigns = Campaigns.list_campaigns()

    socket =
      socket
      |> assign(:page_title, "Campaigns")
      |> stream(:campaigns, campaigns)

    {:ok, socket}
  end

  @impl true
  def handle_event("start", %{"id" => id}, socket) do
    campaign = Campaigns.get_campaign!(id)
    {:ok, updated} = Campaigns.start_campaign(campaign)

    Task.start(fn -> run_campaign(updated) end)

    {:noreply, stream_insert(socket, :campaigns, updated)}
  end

  @impl true
  def handle_event("pause", %{"id" => id}, socket) do
    campaign = Campaigns.get_campaign!(id)
    {:ok, updated} = Campaigns.pause_campaign(campaign)
    {:noreply, stream_insert(socket, :campaigns, updated)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    campaign = Campaigns.get_campaign!(id)
    {:ok, _} = Campaigns.delete_campaign(campaign)
    {:noreply, stream_delete(socket, :campaigns, campaign)}
  end

  defp run_campaign(campaign) do
    agent = campaign.ai_agent
    if not agent do
      :ok
    else
      contacts = Campaigns.get_next_pending_contacts(campaign.id, campaign.concurrent_calls)

      Enum.each(contacts, fn cc ->
        Campaigns.mark_contact_in_progress(cc.id)

        Task.start(fn ->
          result =
            Services.Twilio.initiate_call(
              cc.contact.phone_number,
              campaign.from_number || Application.get_env(:my_app, :twilio_from_number),
              url: "#{Application.get_env(:my_app, :base_url)}/webhooks/twilio/voice/outbound_answer",
              status_callback: "#{Application.get_env(:my_app, :base_url)}/webhooks/twilio/voice/status"
            )

          case result do
            {:ok, %{sid: sid}} ->
              {:ok, call} =
                MyApp.Calls.create_call(%{
                  direction: "outbound",
                  status: "initiated",
                  twilio_call_sid: sid,
                  from_number: campaign.from_number,
                  to_number: cc.contact.phone_number,
                  started_at: DateTime.utc_now(),
                  ai_agent_id: agent.id,
                  contact_id: cc.contact.id,
                  campaign_id: campaign.id
                })

              Campaigns.mark_contact_completed(cc.id, "answered", call.id)

            {:error, _} ->
              Campaigns.mark_contact_failed(cc.id, campaign.max_attempts)
          end
        end)
      end)
    end
  end

  defp status_color("running"), do: "bg-green-100 text-green-700"
  defp status_color("paused"), do: "bg-amber-100 text-amber-700"
  defp status_color("completed"), do: "bg-slate-100 text-slate-600"
  defp status_color("draft"), do: "bg-blue-100 text-blue-700"
  defp status_color(_), do: "bg-slate-100 text-slate-500"
end
