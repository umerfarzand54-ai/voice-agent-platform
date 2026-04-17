defmodule MyApp.Contacts do
  import Ecto.Query
  alias MyApp.Repo
  alias MyApp.Contacts.Contact

  def list_contacts(opts \\ []) do
    query =
      Contact
      |> order_by([c], desc: c.inserted_at)

    query =
      case Keyword.get(opts, :search) do
        nil -> query
        "" -> query
        search ->
          pattern = "%#{search}%"
          where(query, [c], ilike(c.name, ^pattern) or ilike(c.phone_number, ^pattern) or ilike(c.email, ^pattern))
      end

    query =
      case Keyword.get(opts, :opted_out) do
        nil -> query
        value -> where(query, [c], c.opted_out == ^value)
      end

    Repo.all(query)
  end

  def get_contact!(id), do: Repo.get!(Contact, id)

  def find_by_phone(phone_number) do
    Repo.get_by(Contact, phone_number: phone_number)
  end

  def find_or_create_by_phone(phone_number, attrs \\ %{}) do
    case find_by_phone(phone_number) do
      nil ->
        create_contact(Map.put(attrs, :phone_number, phone_number))

      contact ->
        {:ok, contact}
    end
  end

  def create_contact(attrs) do
    %Contact{}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  def delete_contact(%Contact{} = contact), do: Repo.delete(contact)

  def change_contact(%Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end

  def opt_out(%Contact{} = contact) do
    update_contact(contact, %{opted_out: true, opted_out_at: DateTime.utc_now()})
  end

  def count_contacts, do: Repo.aggregate(Contact, :count)

  def import_contacts(contacts_list) do
    Enum.reduce(contacts_list, {0, 0}, fn attrs, {ok_count, err_count} ->
      case create_contact(attrs) do
        {:ok, _} -> {ok_count + 1, err_count}
        {:error, _} -> {ok_count, err_count + 1}
      end
    end)
  end
end
