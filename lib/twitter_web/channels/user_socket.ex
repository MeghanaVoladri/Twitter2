defmodule TwitterCloneWeb.UserSocket do
  use Phoenix.Socket

  channel "lobby", TwitterClone.SimulatorChannel

  transport :websocket, Phoenix.Transports.WebSocket

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
  
end
