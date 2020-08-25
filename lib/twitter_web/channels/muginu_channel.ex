defmodule TwitterClone.SimulatorChannel do
  use Phoenix.Channel

  def join("lobby", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("registerAccount", payload, socket) do
      user_name = payload["username"]
      password = payload["password"]
      :ets.insert_new(:users, {user_name, password})
      {:noreply, socket}
  end

  def handle_in("login", payload, socket) do
      user_name = payload["username"]
      password = payload["password"]
      login_pwd = if :ets.lookup(:users, user_name) != [] do
          elem(List.first(:ets.lookup(:users, user_name)), 1)
      else
          ""
      end
      
      if login_pwd == password do
          :ets.insert(:map_of_sockets, {user_name, socket})
          push socket, "Login", %{login_status: "Login successful" , user_name: user_name }
      else 
          push socket, "Login", %{login_status: "Login unsuccessful" , user_name: user_name}
      end
      {:noreply, socket}
  end

  def handle_in("updateScoket", payload, socket) do
      username = Map.get(payload, "username")
      :ets.insert(:map_of_sockets, {username, socket})
      {:noreply, socket}
  end

  def handle_in("subscribed", payload, socket) do
      username = Map.get(payload, "username2")
      selfId = Map.get(payload, "selfId")
      :ets.insert(:map_of_sockets, {selfId, socket})
      
      mapSet =
        if :ets.lookup(:followersTable, username) == [] do
            MapSet.new
        else
            [{_, set}] = :ets.lookup(:followersTable, username)
            set
        end
  
        mapSet = MapSet.put(mapSet, selfId)
  
        :ets.insert(:followersTable, {username, mapSet})
  
        mapSet2 = 
        if :ets.lookup(:followsTable, selfId) == [] do
          MapSet.new
        else
         [{_, set}] = :ets.lookup(:followsTable, selfId)
         set
        end 
  
        mapSet2 = MapSet.put(mapSet2, username)

        :ets.insert(:followsTable, {selfId, mapSet2})

      push socket, "AddToFollowsList", %{follows: mapSet2} 
      {:noreply, socket}
    end

    def handle_in("reTweet", payload, socket) do
      IO.inspect "RETWEETING!"
      nextID = :ets.info(:tweetsDB)[:size]

      username = Map.get(payload, "username")
      content = Map.get(payload, "tweet")
      user1 = Map.get(payload, "org")

      :ets.insert(:map_of_sockets, {username, socket})
      {hashtags, mentions} = extractMentionsAndHashtags(content)

      :ets.insert(:tweetsDB, {nextID, username, content, true, user1})

      updateMentions(mentions, nextID)
      updateHashTag(hashtags, nextID)
      
      followers = 
      if List.first(:ets.lookup(:followersTable, username)) == nil do
          []
      else
          MapSet.to_list(elem(List.first(:ets.lookup(:followersTable, username)), 1))
      end

      result = %{tweeter: username, tweetText: content, isRetweet: true, org: user1}
     
      publishToSubscribers(followers, nextID, username, result)
      publishToSubscribers(mentions, nextID, username, result)
      {:noreply, socket}
  end

  def handle_in("queryTweets", payload, socket) do
    username = Map.get(payload, "username")
    
    mapSet = 
    if :ets.lookup(:followsTable,username) == [] do
      MapSet.new
    else
      [{_, set}] = :ets.lookup(:followsTable,username)
      set
    end 
   
    relevantTweets = fetchTweets(mapSet)

    push socket, "ReceiveQueryResults", %{tweets: relevantTweets}
    {:noreply, socket}  
end


    def handle_in("getMyMentions", payload, socket) do
      
      username = Map.get(payload, "username")
      mentions =
      if :ets.lookup(:mentionsMap, username) == [] do
        MapSet.new
      else
        [{_, set}] = :ets.lookup(:mentionsMap, username)
        set
      end
      mentionedTweets = getMentions(MapSet.to_list(mentions), [])
      push socket, "ReceiveMentions", %{tweets: mentionedTweets}
      {:noreply, socket}
  end

  def handle_in("tweetsWithHashtag", payload, socket) do
      hashtag = Map.get(payload, "hashtag")

      tweets = 
      if :ets.lookup(:hashtagMap, hashtag) == [] do
        MapSet.new
      else
        [{_, set}] = :ets.lookup(:hashtagMap, hashtag)
        set
      end

      hashtagTweets = getHashtags(MapSet.to_list(tweets), [])
      push socket, "ReceiveHashtags", %{tweets: hashtagTweets}
      {:noreply, socket}
  end

   
  def getHashtags([index | rest], hashtagTweets) do
      [{index, username, content, isRetweet, org_tweeter}] = :ets.lookup(:tweetsDB, index)
      hashtagTweets = List.insert_at(hashtagTweets, 0, %{tweetID: index, tweeter: username, tweet: content, isRetweet: isRetweet, org: org_tweeter})
      getHashtags(rest, hashtagTweets)
  end

  def getHashtags([], hashtagTweets) do
      hashtagTweets
  end

  def updateHashTag([hashtag | hashtags], index) do
     
    elems = 
    if :ets.lookup(:hashtagMap, hashtag) == [] do
        element = MapSet.new
        MapSet.put(element, index)
    else
        [{_,element}] = :ets.lookup(:hashtagMap, hashtag)
        MapSet.put(element, index)
    end

    :ets.insert(:hashtagMap, {hashtag, elems})
    updateHashTag(hashtags, index)
end

def updateHashTag([], _) do
end


  def getMentions([index | rest], mentionedTweets) do
      [{index, username, content, isRetweet, org_tweeter}] = :ets.lookup(:tweetsDB, index)
      mentionedTweets = List.insert_at(mentionedTweets, 0, %{tweetID: index, tweeter: username, tweet: content, isRetweet: isRetweet, org: org_tweeter})
      getMentions(rest, mentionedTweets)
  end

  def getMentions([], mentionedTweets) do
      mentionedTweets
  end

  def extractMentionsAndHashtags(content) do
      split_words=String.split(content," ")
      hashtags=findHashTags(split_words,[])
      mentions=findMentions(split_words,[])
      {hashtags, mentions}
  end

  def findHashTags([head|tail],hashList) do
      if(String.first(head)=="#") do
        [_, elem] = String.split(head, "#") 
        findHashTags(tail,List.insert_at(hashList, 0, head))
      else 
        findHashTags(tail,hashList)
      end
  
    end
  
    def findHashTags([],hashList) do
      hashList
    end
  
    def findMentions([head|tail],mentionList) do
      if(String.first(head)=="@") do
        [_, elem] = String.split(head, "@") 
        findMentions(tail,List.insert_at(mentionList, 0, elem))
        
      else 
        findMentions(tail,mentionList)
      end
  
    end

    def handle_in("tweet", payload, socket) do
      username = Map.get(payload, "username")
      content = Map.get(payload, "tweetText")
      :ets.insert(:map_of_sockets, {username, socket})
      {hashtags, mentions} = extractMentionsAndHashtags(content)
      nextID = :ets.info(:tweetsDB)[:size]

      :ets.insert(:tweetsDB, {nextID, username, content, false, nil})

      updateMentions(mentions, nextID)
      updateHashTag(hashtags, nextID)
     
      followers = 
      if List.first(:ets.lookup(:followersTable, username)) == nil do
          []
      else
          MapSet.to_list(elem(List.first(:ets.lookup(:followersTable, username)), 1))
      end
      result = %{tweeter: username, tweetText: content, isRetweet: false, org: nil}
      publishToSubscribers(followers, nextID, username, result)
      publishToSubscribers(mentions, nextID, username, result)

      {:noreply, socket}
  end

  
    def findMentions([],mentionList) do
      mentionList
    end

    def updateMentions([mention | mentions], index) do
      elems = 
      if :ets.lookup(:mentionsMap, mention) == [] do
          element = MapSet.new
          MapSet.put(element, index)
      else
          [{_,element}] = :ets.lookup(:mentionsMap, mention)
        MapSet.put(element, index)
      end

      :ets.insert(:mentionsMap, {mention, elems})
      updateMentions(mentions, index)
  end

  def updateMentions([], _) do
  end

  
  def publishToSubscribers([first | followers], index, username, payload) do
      push elem(List.first(:ets.lookup(:map_of_sockets, first)), 1),  "ReceiveTweet", payload
      publishToSubscribers(followers, index, username, payload)
  end
  
  def publishToSubscribers([], _, _, _) do
  end

  def fetchTweets(mapSet) do
      result = 
      for fUser <- MapSet.to_list(mapSet) do
        listTweets = List.flatten(:ets.match(:tweetsDB, {:_, fUser, :"$1", :_, :_}))
        Enum.map(listTweets, fn tweetContent -> %{tweeter: fUser, tweet: tweetContent} end)
    end
    List.flatten(result)
  end

end