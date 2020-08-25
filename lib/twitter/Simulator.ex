defmodule Simulator do

    use Phoenix.ChannelTest
    @endpoint TwitterCloneWeb.Endpoint
    
    
    def start(total) do
            mapOfSockets = startClient(Enum.to_list(1..total), %{})
            addData(total, mapOfSockets)
            Process.sleep(5000)
            startProcess()
            Process.sleep(15000)
            spawn(fn-> getMentions() end)
            Process.sleep(5000)
            spawn(fn-> searchHashtag() end)
      end
    
    def addData(total, mapOfSockets) do
        :ets.new(:staticFields, [:named_table])
        :ets.insert(:staticFields, {"totalNodes", total})
        :ets.insert(:staticFields, {"sampleTweets", ["Please come to my party. ","Don't you dare come to my party. ","Why won't you invite me to your party? ","But I wanna come to your party. ","Okay I won't come to your party. "]})
        :ets.insert(:staticFields, {"hashTags", ["#adoptdontshop ","#UFisGreat ","#Fall2017 ","#DinnerParty ","#cutenesscatified "]})
        :ets.insert(:staticFields, {"mapOfSockets", mapOfSockets})
    end
    
    def startClient([client | numClients], mapOfSockets) do
            # Start the socket driver process
            {:ok, socket} = connect(TwitterCloneWeb.UserSocket, %{})    
            {:ok, _, socket} = subscribe_and_join(socket, "lobby", %{})
        
            payload = %{username: "user" <> Integer.to_string(client), password: "123"}
            # socket.connect()
        
            push socket, "registerAccount", payload
            push socket, "login", payload
            mapOfSockets = Map.put(mapOfSockets, "user" <> Integer.to_string(client), socket)
            startClient(numClients, mapOfSockets)
    end
    
    def startClient([], mapOfSockets) do
            mapOfSockets
    end


    def getMentions() do
        [{_, numClients}] = :ets.lookup(:staticFields, "totalNodes")
        [{_, mapOfSockets}] = :ets.lookup(:staticFields, "mapOfSockets")
        clientIds = for _<- 1..5 do
            client = Enum.random(1..numClients)
        end
    
        for j <- clientIds do
            payload = %{username: "user"<>Integer.to_string(j)}
            socket2 = Map.get(mapOfSockets, "user"<>Integer.to_string(j))
            push socket2, "getMyMentions", payload

        end
        Process.sleep(5000)
        getMentions()
    end

    def addSubscribers(numClients, mapOfSockets) do
        hList = for j <- 1..numClients do
                         round(1/j)
                       end
        c=(100/sum(hList,0))
    
        
        for tweeter <- 1..numClients, i <- 1..round(Float.floor(c/tweeter)) do
    
                follower = ("user" <> Integer.to_string(Enum.random(1..numClients)))
                mainUser = ("user" <> Integer.to_string(tweeter))
                push Map.get(mapOfSockets, follower), "subscribed", %{username2: mainUser, selfId: follower}
        end
    
        followersCount = 
        for tweeter <- 1..numClients do
        {"user" <> Integer.to_string(tweeter) , round(Float.floor(c/tweeter))}
        end
    end
    
    
    def searchHashtag() do
        [{_, hashTags}] = :ets.lookup(:staticFields, "hashTags")
        [{_, mapOfSockets}] = :ets.lookup(:staticFields, "mapOfSockets")
        
        for i<- 1..5 do
            hashTag = Enum.random(hashTags)
            payload = %{hashtag: String.trim(hashTag)}
            socket2 = Map.get(mapOfSockets, "user"<>Integer.to_string(i))
            push socket2, "tweetsWithHashtag", payload
        end

        Process.sleep(5000)
        searchHashtag()
    
    end
    
    def kill(ipAddr) do
        [{_, numClients}] = :ets.lookup(:staticFields, "totalNodes")

        clientIds = for i<- 1..5 do
            client = Enum.random(1..numClients)
        end
    
        for j <- clientIds do
            spawn(fn -> GenServer.cast(String.to_atom("user"<>Integer.to_string(j)),{:kill_self}) end)
        end
    
        Process.sleep(10000)
    
        for j <- clientIds do
            spawn(fn -> Client.start_link("user" <> Integer.to_string(j), ipAddr) end)
            spawn(fn -> Client.register_user("user" <> Integer.to_string(j), ipAddr) end)
        end
    
    end
    
    def startProcess() do 
            [{_, numClients}] = :ets.lookup(:staticFields, "totalNodes")
            [{_, mapOfSockets}] = :ets.lookup(:staticFields, "mapOfSockets")
            addSubscribers(numClients, mapOfSockets)
            Process.sleep(5000)
            delay = 3000
          for client <- 1..numClients do
            username = "user" <> Integer.to_string(client)
                spawn(fn -> generateTweets(username, Map.get(mapOfSockets,username), delay * client) end)
          end

    end
    
    def generateTweets(username, socket, delay) do
                content = Simulator.getTweets(username)
                payload = %{tweetText: content , username: username}
                push socket, "tweet", payload
                Process.sleep(delay)            
                generateTweets(username, socket, delay)
    end
    
    def sum([first|tail], sum) do
        sum = sum + first
        sum(tail,sum)
    end
    
    def sum([], sum) do
        sum
    end
    
    
    
        def reduce([first|tail], string) do
            string = string <> first
            reduce(tail, string)
        end
    
        def reduce([], string) do
            string
        end
    
      def findAddress(iter) do
        list = Enum.at(:inet.getif() |> Tuple.to_list, 1)
        if (elem(Enum.at(list, iter), 0) == {127, 0, 0, 1}) do
          findAddress(iter+1)
        else
          elem(Enum.at(list, iter), 0) |> Tuple.to_list |> Enum.join(".")
        end
      end

      
    def getTweets(username) do
        [{_, sampleTweets}] = :ets.lookup(:staticFields, "sampleTweets")
        rand_Index = Enum.random(1..Enum.count(sampleTweets))
        selectedTweet = Enum.at(sampleTweets, rand_Index - 1)
        
        [{_, hashTags}] = :ets.lookup(:staticFields, "hashTags")
        numTags = Enum.random(0..5)
    
        hashTagList = 
        if numTags > 0 do
            for i <- Enum.to_list(1..numTags) do
                 Enum.at(hashTags, i - 1)
            end
        else
            []
        end
        [{_, numClients}] = :ets.lookup(:staticFields, "totalNodes")
        numMentions = Enum.random(0..5)
    
        mentionsList = 
        if numMentions > 0 do
            for i <- Enum.to_list(1..numMentions) do
                 "@user" <> Integer.to_string(Enum.random(1..numClients)) <> " "
            end
        else
            []
        end
        selectedTweet <> reduce(hashTagList, "") <> reduce(mentionsList, "")
    
        end
    
      
    end