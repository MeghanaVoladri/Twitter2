defmodule Proj4.Client do
  use GenServer

  def start_link(client_ID, num_of_msgs, zipf_no_of_subs, disconnected_client) do
    GenServer.start_link(__MODULE__, [
      client_ID,
      num_of_msgs,
      zipf_no_of_subs,
      disconnected_client
    ])
  end

  def init([client_ID, num_of_msgs, zipf_no_of_subs, disconnected_client]) do
    {:ok, iflist} = :inet.getif()
    split(Enum.reverse(iflist), length(iflist))
    :global.sync()

    if disconnected_client do
      #IO.puts("@Client_#{client_ID} has been reconnected")
      handle_login(client_ID)
    end

    # Register Account
    send(:global.whereis_name(:Server), {:registerClient, client_ID, self()})

    receive do
      {:registerConfirmation} -> nil #IO.puts("@Client_#{client_ID} registration Successful")
    end

    handle_main(client_ID, num_of_msgs, zipf_no_of_subs)
    receive do: (_ -> :ok)
  end

  def split([head | tail], l) do
    unless Node.alive?() do
      try do
        {ip_object, _, _} = head
        ip = to_string(:inet_parse.ntoa(ip_object))

        if ip === "127.0.0.1" do
          if l > 1 do
            split(tail, l - 1)
          else
            IO.puts("Can not split further!")
          end
        else
          server_name = String.to_atom("client@" <> ip)
          Node.start(server_name)
          Node.set_cookie(server_name, :monster)
          Node.connect(String.to_atom("server@" <> ip))
        end
      rescue
        _ -> if l > 1, do: split(tail, l - 1), else: nil #IO.puts(IO.puts("Can not split further!"))
      end
    end
  end

  def handle_login(client_ID) do
    send(:global.whereis_name(:Server), {:login_client_atom, client_ID, self()})

    send(
      :global.whereis_name(:Server),
      {:tweet, "@Client_#{client_ID} : Hello Again!", client_ID}
    )

    handle_feed(client_ID)
  end

  defp random_tweet(len) do
    characters = " abcdefghijklmnopqrstuvwxyz  0123456789 "
    list = characters |> String.split("", trim: true) |> Enum.shuffle()

    random_str =
      1..len |> Enum.reduce([], fn _, acc -> [Enum.random(list) | acc] end) |> Enum.join("")

    random_str
  end

  defp random_hashtag(len) do
    characters = "abcdefghijklmnopqrstuvwxyz0123456789"
    list = characters |> String.split("", trim: true) |> Enum.shuffle()

    random_str =
      1..len |> Enum.reduce([], fn _, acc -> [Enum.random(list) | acc] end) |> Enum.join("")

    random_str
  end

  def handle_main(client_ID, num_of_msgs, zipf_no_of_subs) do
    if zipf_no_of_subs > 0 do
      subList = get_subscribers_list(1, zipf_no_of_subs, [])
      handle_subscribe_list(client_ID, subList)
    end

    time = System.system_time(:millisecond)
    random_client = :rand.uniform(String.to_integer(client_ID))

    send(
      :global.whereis_name(:Server),
      {:tweet, "@Client_#{client_ID} : @Client_#{random_client} #{random_tweet(15)}", client_ID}
    )

    hashtag = random_hashtag(8)

    send(
      :global.whereis_name(:Server),
      {:tweet, "@Client_#{client_ID} : ##{hashtag} #{random_tweet(15)}", client_ID}
    )

    for _ <- 1..num_of_msgs do
      send(
        :global.whereis_name(:Server),
        {:tweet, "@Client_#{client_ID} : #{random_tweet(15)}", client_ID}
      )
    end

    retweet(client_ID)
    handle_subscribed_to(client_ID)
    handle_hashtag("##{hashtag}", client_ID)
    handle_mention(client_ID)
    handle_all_tweets(client_ID)
    time_taken = System.system_time(:millisecond) - time
    send(:global.whereis_name(:main_process), {:completed, time_taken})
    handle_feed(client_ID)
  end

  def handle_feed(client_ID) do
    receive do
      {:live, tweet_string} -> nil #IO.inspect(tweet_string, label: "@Client_#{client_ID} Feed :")
    end

    handle_feed(client_ID)
  end

  def get_subscribers_list(count, no_of_subs, list) do
    if(count == no_of_subs) do
      [count | list]
    else
      get_subscribers_list(count + 1, no_of_subs, [count | list])
    end
  end

  def handle_subscribe_list(client_ID, subscribeToList) do
    Enum.each(subscribeToList, fn accountId ->
      send(
        :global.whereis_name(:Server),
        {:add_subscriber_atom, client_ID, Integer.to_string(accountId)}
      )
    end)
  end

  def retweet(client_ID) do
    send(:global.whereis_name(:Server), {:subscribed_tweet_atom, client_ID})

    list =
      receive do
        {:handle_subscribed_atom, list} -> list
      end

    if list != [] do
      ret = hd(list)
      send(:global.whereis_name(:Server), {:tweet, ret <> " -RT", client_ID})
    end
  end

  def handle_all_tweets(client_ID) do
    send(:global.whereis_name(:Server), {:my_tweet_atom, client_ID})

    receive do
      {:handle_my_tweets_atom, list} -> nil #IO.inspect(list, label: "Client #{client_ID} all Tweets :")
    end
  end

  def handle_subscribed_to(client_ID) do
    send(:global.whereis_name(:Server), {:subscribed_tweet_atom, client_ID})

    receive do
      {:handle_subscribed_atom, list} ->
        if list != [], do: nil #IO.inspect(list, label: "@Client_#{client_ID} Tweets Subscribed :")
    end
  end

  def handle_hashtag(hashtag, client_ID) do
    send(:global.whereis_name(:Server), {:hashtag_tweet_atom, hashtag, client_ID})

    receive do
      {:handle_hashtag_atom, list} ->
        if list != [],
          do: nil #IO.inspect(list, label: "@Client_#{client_ID} Tweets containing #{hashtag} :")
    end
  end

  def handle_mention(client_ID) do
    send(:global.whereis_name(:Server), {:mention_tweet_atom, client_ID})

    receive do
      {:handle_mention_atom, list} ->
        if list != [],
          do: nil #IO.inspect(list, label: "@Client_#{client_ID} Tweets mentioning @#{client_ID} :")
    end
  end
end
