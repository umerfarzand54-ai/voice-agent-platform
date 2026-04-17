defmodule MyAppWeb.ContactsLive.Form do
  use MyAppWeb, :live_view

  alias MyApp.Contacts
  alias MyApp.Contacts.Contact

  @language_options [
    {"English (India)", "en-IN"},
    {"Hindi", "hi-IN"},
    {"Tamil", "ta-IN"},
    {"Telugu", "te-IN"},
    {"Kannada", "kn-IN"},
    {"Malayalam", "ml-IN"},
    {"Bengali", "bn-IN"},
    {"Gujarati", "gu-IN"},
    {"Marathi", "mr-IN"}
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    contact = Contacts.get_contact!(id)

    {:ok,
     socket
     |> assign(:contact, contact)
     |> assign(:form, to_form(Contacts.change_contact(contact)))
     |> assign(:language_options, @language_options)
     |> assign(:page_title, "Edit Contact")}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:contact, %Contact{})
     |> assign(:form, to_form(Contacts.change_contact(%Contact{})))
     |> assign(:language_options, @language_options)
     |> assign(:page_title, "New Contact")}
  end

  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    form =
      socket.assigns.contact
      |> Contacts.change_contact(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"contact" => params}, socket) do
    case socket.assigns.live_action do
      :new ->
        case Contacts.create_contact(params) do
          {:ok, _} ->
            {:noreply, socket |> put_flash(:info, "Contact created!") |> push_navigate(to: ~p"/contacts")}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      :edit ->
        case Contacts.update_contact(socket.assigns.contact, params) do
          {:ok, _} ->
            {:noreply, socket |> put_flash(:info, "Contact updated!") |> push_navigate(to: ~p"/contacts")}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end
end
