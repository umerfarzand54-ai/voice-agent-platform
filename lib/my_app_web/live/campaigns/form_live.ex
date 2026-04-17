defmodule MyAppWeb.CampaignsLive.Form do
  use MyAppWeb, :live_view

  alias MyApp.{Agents, Campaigns}
  alias MyApp.Campaigns.Campaign

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    campaign = Campaigns.get_campaign!(id)
    agents = Agents.list_active_agents()

    {:ok,
     socket
     |> assign(:campaign, campaign)
     |> assign(:form, to_form(Campaigns.change_campaign(campaign)))
     |> assign(:agents, Enum.map(agents, &{&1.name, &1.id}))
     |> assign(:page_title, "Edit Campaign")}
  end

  def mount(_params, _session, socket) do
    agents = Agents.list_active_agents()

    {:ok,
     socket
     |> assign(:campaign, %Campaign{})
     |> assign(:form, to_form(Campaigns.change_campaign(%Campaign{})))
     |> assign(:agents, Enum.map(agents, &{&1.name, &1.id}))
     |> assign(:page_title, "New Campaign")}
  end

  @impl true
  def handle_event("validate", %{"campaign" => params}, socket) do
    form =
      socket.assigns.campaign
      |> Campaigns.change_campaign(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"campaign" => params}, socket) do
    save_campaign(socket, socket.assigns.live_action, params)
  end

  defp save_campaign(socket, :new, params) do
    case Campaigns.create_campaign(params) do
      {:ok, campaign} ->
        {:noreply,
         socket
         |> put_flash(:info, "Campaign \"#{campaign.name}\" created!")
         |> push_navigate(to: ~p"/campaigns")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_campaign(socket, :edit, params) do
    case Campaigns.update_campaign(socket.assigns.campaign, params) do
      {:ok, _campaign} ->
        {:noreply,
         socket
         |> put_flash(:info, "Campaign updated!")
         |> push_navigate(to: ~p"/campaigns")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
