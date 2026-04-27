defmodule MyAppWeb.MediaStreamController do
  use MyAppWeb, :controller

  def connect(conn, _params) do
    conn
    |> WebSockAdapter.upgrade(MyAppWeb.MediaStreamHandler, %{}, timeout: 300_000)
    |> halt()
  end
end
