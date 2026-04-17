defmodule MyAppWeb.AgentsLive.Form do
  use MyAppWeb, :live_view

  alias MyApp.Agents
  alias MyApp.Agents.Agent

  @language_options [
    {"English (India)", "en-IN"},
    {"Hindi", "hi-IN"},
    {"Tamil", "ta-IN"},
    {"Telugu", "te-IN"},
    {"Kannada", "kn-IN"},
    {"Malayalam", "ml-IN"},
    {"Bengali", "bn-IN"},
    {"Gujarati", "gu-IN"},
    {"Marathi", "mr-IN"},
    {"Punjabi", "pa-IN"}
  ]

  @model_options [
    {"Claude Sonnet 4.6 (Recommended)", "claude-sonnet-4-6"},
    {"Claude Opus 4.7 (Most Capable)", "claude-opus-4-7"},
    {"Claude Haiku 4.5 (Fastest)", "claude-haiku-4-5-20251001"}
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    agent = Agents.get_agent!(id)
    form = to_form(Agents.change_agent(agent))

    {:ok,
     socket
     |> assign(:agent, agent)
     |> assign(:form, form)
     |> assign(:language_options, @language_options)
     |> assign(:model_options, @model_options)
     |> assign(:page_title, "Edit Agent")}
  end

  def mount(_params, _session, socket) do
    agent = %Agent{}
    form = to_form(Agents.change_agent(agent))

    {:ok,
     socket
     |> assign(:agent, agent)
     |> assign(:form, form)
     |> assign(:language_options, @language_options)
     |> assign(:model_options, @model_options)
     |> assign(:page_title, "New Agent")}
  end

  @impl true
  def handle_event("validate", %{"agent" => params}, socket) do
    form =
      socket.assigns.agent
      |> Agents.change_agent(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"agent" => params}, socket) do
    save_agent(socket, socket.assigns.live_action, params)
  end

  defp save_agent(socket, :new, params) do
    case Agents.create_agent(params) do
      {:ok, agent} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent \"#{agent.name}\" created successfully!")
         |> push_navigate(to: ~p"/agents")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_agent(socket, :edit, params) do
    case Agents.update_agent(socket.assigns.agent, params) do
      {:ok, agent} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent \"#{agent.name}\" updated!")
         |> push_navigate(to: ~p"/agents")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
