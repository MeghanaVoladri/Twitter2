defmodule Proj4.Main do
    def start_main(args) do
      cond do
        Enum.count(args) === 3 ->
          Task.async(fn -> Proj4.Start.start_clients_with_disconnection(args) end)
  
        Enum.count(args) === 2 ->
          Task.async(fn -> Proj4.Start.start_clients(args) end)
  
        true ->
          IO.puts("Invalid number of arguments")
      end
    end
  end
  