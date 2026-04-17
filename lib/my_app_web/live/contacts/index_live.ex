defmodule MyAppWeb.ContactsLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Contacts

  @impl true
  def mount(_params, _session, socket) do
    contacts = Contacts.list_contacts()

    socket =
      socket
      |> assign(:page_title, "Contacts")
      |> assign(:search, "")
      |> stream(:contacts, contacts)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    contacts = Contacts.list_contacts(search: search)
    {:noreply, socket |> assign(:search, search) |> stream(:contacts, contacts, reset: true)}
  end

  @impl true
  def handle_event("opt_out", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(id)
    {:ok, updated} = Contacts.opt_out(contact)
    {:noreply, stream_insert(socket, :contacts, updated)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(id)
    {:ok, _} = Contacts.delete_contact(contact)
    {:noreply, stream_delete(socket, :contacts, contact)}
  end
end
