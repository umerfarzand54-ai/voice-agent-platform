defmodule MyAppWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MyAppWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-slate-50">
      <%!-- Sidebar --%>
      <aside class="w-60 flex-shrink-0 bg-slate-900 flex flex-col">
        <div class="px-5 py-5 border-b border-slate-800">
          <div class="flex items-center gap-2.5">
            <div class="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center">
              <.icon name="hero-phone" class="w-4 h-4 text-white" />
            </div>
            <span class="text-white font-bold text-sm">VoiceAI Platform</span>
          </div>
        </div>

        <nav class="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
          <.nav_link href={~p"/dashboard"} icon="hero-squares-2x2" label="Dashboard" />
          <.nav_link href={~p"/agents"} icon="hero-cpu-chip" label="AI Agents" />
          <.nav_link href={~p"/voice-profiles"} icon="hero-microphone" label="Voice Profiles" />
          <div class="pt-3 pb-1 px-3">
            <p class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Outreach</p>
          </div>
          <.nav_link href={~p"/campaigns"} icon="hero-megaphone" label="Campaigns" />
          <.nav_link href={~p"/contacts"} icon="hero-users" label="Contacts" />
          <div class="pt-3 pb-1 px-3">
            <p class="text-xs font-semibold text-slate-500 uppercase tracking-wider">Activity</p>
          </div>
          <.nav_link href={~p"/calls"} icon="hero-phone-arrow-down-left" label="Call History" />
          <div class="pt-3 pb-1 px-3">
            <p class="text-xs font-semibold text-slate-500 uppercase tracking-wider">System</p>
          </div>
          <.nav_link href={~p"/settings"} icon="hero-cog-6-tooth" label="Settings" />
        </nav>

        <div class="px-3 py-4 border-t border-slate-800">
          <div class="flex items-center gap-2.5 px-3 py-2">
            <div class="w-7 h-7 rounded-full bg-indigo-600 flex items-center justify-center text-xs text-white font-bold">A</div>
            <div>
              <p class="text-xs font-medium text-slate-300">Admin</p>
              <p class="text-xs text-slate-500">Voice Agent Platform</p>
            </div>
          </div>
        </div>
      </aside>

      <%!-- Main content --%>
      <div class="flex-1 overflow-y-auto">
        {render_slot(@inner_block)}
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link navigate={@href}
      class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm text-slate-400 hover:text-white hover:bg-slate-800 transition-colors group">
      <.icon name={@icon} class="w-4 h-4 flex-shrink-0" />
      {@label}
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
