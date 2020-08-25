defmodule Proj4.Server do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:ok, iflist} = :inet.getif()
    split(Enum.reverse(iflist), length(iflist))

    :ets.new(:clients_directory, [:set, :public, :named_table])
    :ets.new(:tweets, [:set, :public, :named_table])
    :ets.new(:mentions, [:set, :public, :named_table])
    :ets.new(:subscribed, [:set, :public, :named_table])
    :ets.new(:followers, [:set, :public, :named_table])
    server_id = spawn_link(fn -> loop() end)
    :global.register_name(:Server, server_id)

    IO.puts("Server Started")
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
          server_name = String.to_atom("server@" <> ip)
          Node.start(server_name)
          Node.set_cookie(server_name, :monster)
        end
      rescue
        _ -> if l > 1, do: split(tail, l - 1), else: IO.puts("Can not split further!")
      end
    end
  end

  def lookup(client_ID) do
    if :ets.lookup(:clients_directory, client_ID) == [] do
      nil
    else
      [tuple] = :ets.lookup(:clients_directory, client_ID)
      elem(tuple, 1)
    end
  end

  def loop() do
    receive do
      {:registerClient, client_ID, pid} ->
        register(client_ID, pid)

      {:tweet, tweetString, client_ID} ->
        handle_tweet(tweetString, client_ID)

      {:subscribed_tweet_atom, client_ID} ->
        Task.start(fn -> handle_subscribed_tweets(client_ID) end)

      {:hashtag_tweet_atom, hashtag, client_ID} ->
        Task.start(fn -> handle_tweet_hashtags(hashtag, client_ID) end)

      {:mention_tweet_atom, client_ID} ->
        Task.start(fn -> handle_tweet_mentions(client_ID) end)

      {:my_tweet_atom, client_ID} ->
        Task.start(fn -> handle_my_tweets(client_ID) end)

      {:add_subscriber_atom, client_ID, subscriber_ID} ->
        handle_subscribers(client_ID, subscriber_ID)
        handle_add_subscriber(subscriber_ID, client_ID)

      {:disconnect_client_atom, client_ID} ->
        handle_disconnect_client(client_ID)

      {:login_client_atom, client_ID, pid} ->
        :ets.insert(:clients_directory, {client_ID, pid})
    end

    loop()
  end

  def register(client_ID, pid) do
    :ets.insert(:clients_directory, {client_ID, pid})
    :ets.insert(:tweets, {client_ID, []})
    :ets.insert(:subscribed, {client_ID, []})
    if :ets.lookup(:followers, client_ID) == [], do: :ets.insert(:followers, {client_ID, []})
    send(pid, {:registerConfirmation})
  end

  def handle_tweet(tweetString, client_ID) do
    [tuple] = :ets.lookup(:tweets, client_ID)
    list = elem(tuple, 1)
    list = [tweetString | list]
    :ets.insert(:tweets, {client_ID, list})

    hashtagsList = Regex.scan(~r/\B#[a-zA-Z0-9_]+/, tweetString) |> Enum.concat()

    Enum.each(hashtagsList, fn hashtag ->
      insert_hashtags(hashtag, tweetString)
    end)

    mentionsList = Regex.scan(~r/\B@[a-zA-Z0-9_]+/, tweetString) |> Enum.concat()

    Enum.each(mentionsList, fn mention ->
      insert_hashtags(mention, tweetString)
      clientName = String.slice(mention, 1, String.length(mention) - 1)
      if lookup(clientName) != nil, do: send(lookup(clientName), {:live, tweetString})
    end)

    [{_, subscribersList}] = :ets.lookup(:followers, client_ID)

    Enum.each(subscribersList, fn subscriber ->
      if lookup(subscriber) != nil, do: send(lookup(subscriber), {:live, tweetString})
    end)
  end

  def handle_subscribed_tweets(client_ID) do
    subscribedTo = get_subscribed_to(client_ID)
    list = get_tweets_list(subscribedTo, [])
    send(lookup(client_ID), {:handle_subscribed_atom, list})
  end

  def handle_tweet_hashtags(hashtag, client_ID) do
    [tuple] =
      if :ets.lookup(:mentions, hashtag) != [] do
        :ets.lookup(:mentions, hashtag)
      else
        [{"#", []}]
      end

    list = elem(tuple, 1)
    send(lookup(client_ID), {:handle_hashtag_atom, list})
  end

  def handle_tweet_mentions(client_ID) do
    [tuple] =
      if :ets.lookup(:mentions, "@Client_" <> client_ID) != [] do
        :ets.lookup(:mentions, "@Client_" <> client_ID)
      else
        [{"#", []}]
      end

    list = elem(tuple, 1)
    send(lookup(client_ID), {:handle_mention_atom, list})
  end

  def handle_my_tweets(client_ID) do
    [tuple] = :ets.lookup(:tweets, client_ID)
    list = elem(tuple, 1)
    send(lookup(client_ID), {:handle_my_tweets_atom, list})
  end

  def handle_subscribers(client_ID, sub) do
    [tuple] = :ets.lookup(:subscribed, client_ID)
    list = elem(tuple, 1)
    list = [sub | list]
    :ets.insert(:subscribed, {client_ID, list})
  end

  def handle_add_subscriber(client_ID, subscriber) do
    if :ets.lookup(:followers, client_ID) == [], do: :ets.insert(:followers, {client_ID, []})
    [tuple] = :ets.lookup(:followers, client_ID)
    list = elem(tuple, 1)
    list = [subscriber | list]
    :ets.insert(:followers, {client_ID, list})
  end

  def handle_disconnect_client(client_ID) do
    :ets.insert(:clients_directory, {client_ID, nil})
  end

  def get_subscribed_to(client_ID) do
    [tuple] = :ets.lookup(:subscribed, client_ID)
    elem(tuple, 1)
  end

  def get_subscribers(client_ID) do
    [tuple] = :ets.lookup(:followers, client_ID)
    elem(tuple, 1)
  end

  def insert_hashtags(hashtag, tweetString) do
    [tuple] =
      if :ets.lookup(:mentions, hashtag) != [] do
        :ets.lookup(:mentions, hashtag)
      else
        [nil]
      end

    if tuple == nil do
      :ets.insert(:mentions, {hashtag, [tweetString]})
    else
      list = elem(tuple, 1)
      list = [tweetString | list]
      :ets.insert(:mentions, {hashtag, list})
    end
  end

  def get_tweets_list([head | tail], tweet_list) do
    tweet_list = get_tweets_by_client(head) ++ tweet_list
    get_tweets_list(tail, tweet_list)
  end

  def get_tweets_list([], tweet_list), do: tweet_list

  def get_tweets_by_client(client_ID) do
    if :ets.lookup(:tweets, client_ID) == [] do
      []
    else
      [tuple] = :ets.lookup(:tweets, client_ID)
      elem(tuple, 1)
    end
  end
end