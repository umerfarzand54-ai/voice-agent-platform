defmodule MyAppWeb.AgentsLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Agents

  @impl true
  def mount(_params, _session, socket) do
    agents = Agents.list_agents()

    socket =
      socket
      |> assign(:page_title, "AI Agents")
      |> stream(:agents, agents)

    {:ok, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    agent = Agents.get_agent!(id)
    {:ok, _} = Agents.delete_agent(agent)

    {:noreply, stream_delete(socket, :agents, agent)}
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    agent = Agents.get_agent!(id)
    {:ok, updated} = Agents.update_agent(agent, %{active: !agent.active})
    {:noreply, stream_insert(socket, :agents, updated)}
  end

  defp language_label("en-IN"), do: "English (India)"
  defp language_label("hi-IN"), do: "Hindi"
  defp language_label("ta-IN"), do: "Tamil"
  defp language_label("te-IN"), do: "Telugu"
  defp language_label("kn-IN"), do: "Kannada"
  defp language_label("ml-IN"), do: "Malayalam"
  defp language_label("bn-IN"), do: "Bengali"
  defp language_label("gu-IN"), do: "Gujarati"
  defp language_label("mr-IN"), do: "Marathi"
  defp language_label(code), do: code
end
