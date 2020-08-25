defmodule Proj4.Start do
  def start_clients(args) do
    Task.start(fn -> Proj4.Server.start_link() end)
    Process.sleep(100)

    num_of_clients = String.to_integer(Enum.at(args, 0))
    num_of_msgs = String.to_integer(Enum.at(args, 1))

    :ets.new(:registry, [:set, :public, :named_table])
    main_task = Task.async(fn -> loop(num_of_clients, num_of_clients, 0) end)
    :global.register_name(:main_process, main_task.pid)

    create_clients(1, num_of_clients, num_of_msgs)
    Task.await(main_task, :infinity)
  end

  def start_clients_with_disconnection(args) do
    Task.start(fn -> Proj4.Server.start_link() end)
    Process.sleep(100)

    num_of_clients = String.to_integer(Enum.at(args, 0))
    num_of_msgs = String.to_integer(Enum.at(args, 1))
    num_of_clients_to_disconnect = String.to_integer(Enum.at(args, 2))

    :ets.new(:registry, [:set, :public, :named_table])
    main_task = Task.async(fn -> loop(num_of_clients, num_of_clients, 0) end)
    :global.register_name(:main_process, main_task.pid)

    create_clients(1, num_of_clients, num_of_msgs)
    disconnect_clients(num_of_clients, num_of_clients_to_disconnect)
    Task.await(main_task, :infinity)
  end

  def loop(num_of_clients, total_no_of_clients, client_time) do
    if num_of_clients !== 0 do
      receive do
        {:completed, t1} -> loop(num_of_clients - 1, total_no_of_clients, client_time + t1)
      end
    else
      IO.puts("Average Time taken by each clients : #{client_time / total_no_of_clients}ms")
    end
  end

  def create_clients(count, num_of_clients, num_of_subscribers) do
    client_ID = Integer.to_string(count)
    num_of_msgs = round(Float.floor(num_of_subscribers / count))
    zipf_no_of_subs = round(Float.floor(num_of_subscribers / (num_of_clients - count + 1))) - 1

    client_pid =
      spawn(fn -> Proj4.Client.start_link(client_ID, num_of_msgs, zipf_no_of_subs, false) end)

    :ets.insert(:registry, {client_ID, client_pid})

    if count != num_of_clients do
      create_clients(count + 1, num_of_clients, num_of_subscribers)
    end
  end

  def lookup(client_ID) do
    [tuple] = :ets.lookup(:registry, client_ID)
    elem(tuple, 1)
  end

  def disconnect_clients(num_of_clients, clients_to_disconnect) do
    Process.sleep(1000)
    disconnect_list = get_disconnect_list(0, num_of_clients, clients_to_disconnect, 0, [])
    Process.sleep(1000)

    Enum.each(disconnect_list, fn client_ID ->
      client_pid = spawn(fn -> Proj4.Client.start_link(client_ID, -1, -1, true) end)
      :ets.insert(:registry, {client_ID, client_pid})
    end)
  end

  def get_disconnect_list(
        count,
        num_of_clients,
        clients_to_disconnect,
        clients_disconnected,
        disconnect_list
      ) do
    if clients_disconnected < clients_to_disconnect do
      disconnect_client = :rand.uniform(num_of_clients)
      disconnect_client_ID = lookup(Integer.to_string(disconnect_client))

      if disconnect_client_ID != nil do
        client_ID = Integer.to_string(disconnect_client)
        disconnect_list = [client_ID | disconnect_list]
        send(:global.whereis_name(:Server), {:disconnect_client_atom, client_ID})
        :ets.insert(:registry, {client_ID, nil})
        Process.exit(disconnect_client_ID, :kill)
        #IO.puts("@Client_#{client_ID} has been disconnected")
        count = count + 1

        get_disconnect_list(
          count,
          num_of_clients,
          clients_to_disconnect,
          clients_disconnected + 1,
          disconnect_list
        )
      else
        get_disconnect_list(
          count,
          num_of_clients,
          clients_to_disconnect,
          clients_disconnected,
          disconnect_list
        )
      end
    else
      disconnect_list
    end
  end
end
