defmodule TapestryAlgorithm do

  @nodeIdLen 8
  @nodeHexVal 16

  #############################################################
  #Main module to get input arguments,start server processes for
  #each node,set hash table,route requests,dynamic node join and
  #print max no.of hops
  #############################################################

  def main() do
    input       = System.argv()
    numNodes    = Enum.at(input, 0) |> String.to_integer()
    numRequests = Enum.at(input, 1) |> String.to_integer()
    nodeMap     = Enum.map(1..numNodes, fn z -> {:ok, node} = TapestryNodeServer.start_link(z)
      node
    end)
    nodeIdList  = Enum.map(nodeMap, fn z ->
      nodeId = TapestryNodeServer.getNodeId(z)
      nodeId
    end)

    setNodeHashTable(nodeMap, numNodes, nodeIdList)

    :ets.new(:noOfHops, [:set, :public, :named_table])
    :ets.insert(:noOfHops, {"totalHops", 0})
    :ets.insert(:noOfHops, {"maxHops", 0})

    IO.puts("Starting Tapestry Algorithm...")

    newNodeDetails  = insertNewNode(nodeMap, numNodes, nodeIdList)
    newNodeMap      = Map.get(newNodeDetails,"nodeMap")
    newNodeIdList   = Map.get(newNodeDetails,"nodeIdList")
    getNodeRequests(newNodeMap, numNodes+1, newNodeIdList, numRequests)

    [{_, maxHops}] = :ets.lookup(:noOfHops, "maxHops")
    IO.puts("Max Hops taken in the network is: #{maxHops}")
  end

 #Creates the neighbor hash table for each node
  def setNodeHashTable(nodeMap, numNodes, nodeIdList) do
    for i <- 0..numNodes-1 do
      TapestryNodeServer.setNodeHashTable(Enum.at(nodeMap, i), nodeIdList)
    end
  end

  #Gets the number of node requests for routing. We choose the request nodes in a random manner
  def getNodeRequests(nodeMap, numNodes, nodeIdList, numRequests) do
    for i <- 0..numNodes-1 do
      currNodeId      = Enum.at(nodeIdList, i)
      currNodePid     = Enum.at(nodeMap, i)
      currNodeIdList  = nodeIdList -- [currNodeId]
      for _j <- 0..numRequests-1 do
        requestNodeId   = getRandomNode(currNodeIdList)
        :ets.insert(:noOfHops, {"totalHops", 0})
        startNodeRequest(currNodePid, currNodeId, requestNodeId, nodeIdList, nodeMap)
      end
    end
  end

  #Starts routing for each of the requested nodes based on the routing table and returns max hops
  def startNodeRequest(currNodePid, currNodeId, requestNodeId, nodeIdList, nodeMap) do
    {:ok, currNodeNeighbors} = TapestryNodeServer.getNodeNeighbors(currNodePid)
    l1 = String.myers_difference(requestNodeId,currNodeId)
    l2 = Tuple.to_list(Enum.at(l1,0))
    l3 = if Enum.member?(l2,:eq) do Enum.at(l2,1) else "" end
    rowVal = String.length(l3)
    {colVal, ""} = if rowVal == 0 do Integer.parse(String.first(requestNodeId), 16) else Integer.parse(String.at(requestNodeId,rowVal), 16) end
    nextHopNode = Enum.at(Map.get(currNodeNeighbors, rowVal+1),colVal)
    if(nextHopNode == requestNodeId) do
      [{_, totalHops}]  = :ets.lookup(:noOfHops, "totalHops")
      [{_, maxHops}]    = :ets.lookup(:noOfHops, "maxHops")
      if(totalHops+1 > maxHops) do
        :ets.insert(:noOfHops, {"maxHops", totalHops + 1})
      end
    else
      nextHopNodeIndex  = Enum.find_index(nodeIdList, fn x -> x == nextHopNode end)
      nextHopNodePid    = Enum.at(nodeMap, nextHopNodeIndex)
      [{_, totalHops}]  = :ets.lookup(:noOfHops, "totalHops")
      :ets.insert(:noOfHops, {"totalHops", totalHops + 1})
      startNodeRequest(nextHopNodePid, nextHopNode, requestNodeId, nodeIdList, nodeMap)
    end
  end

  #function for dynamic node join, this function adds one extra node
  def insertNewNode(nodeMap, numNodes, nodeIdList) do
    nodeNum = numNodes+1
    {:ok, nodePid} = TapestryNodeServer.start_link(nodeNum)
    nodeId      = TapestryNodeServer.getNodeId(nodePid)
    nodeMap     = nodeMap ++ [nodePid]
    nodeIdList  = nodeIdList ++ [nodeId]
    matchingNodeDetails = getClosestMatchingNodeNeighbors(nodeNum, numNodes, nodeMap, nodeIdList)
    nodeDetails = %{}
    nodeDetails = Map.put(nodeDetails, "nodeIdList", nodeIdList)
    nodeDetails = Map.merge(nodeDetails,matchingNodeDetails)
    TapestryNodeServer.setNewNodeHashTable(nodePid, nodeDetails)
    multicastNewNodeNeighbors(nodePid, nodeId, nodeMap, nodeIdList)
    otherMatchingNodes = Map.get(nodeDetails,"otherMatchingNodes")
    for k <- 0..length(otherMatchingNodes)-1 do
      otherNodeIndex  = Enum.find_index(nodeIdList, fn x -> x == Enum.at(otherMatchingNodes,k) end)
      otherNodePid    = Enum.at(nodeMap, otherNodeIndex)
      additionalMulticast(otherNodePid, Enum.at(otherMatchingNodes,k), nodeId)
    end
    newNodeDetails = %{}
    newNodeDetails = Map.put(newNodeDetails,"nodeMap",nodeMap)
    newNodeDetails = Map.put(newNodeDetails,"nodeIdList",nodeIdList)
    newNodeDetails
  end

  #Utility function for dynamic node join to find the closest matching neighbors
  #based on maximum prefix match
  def getClosestMatchingNodeNeighbors(nodeNum, numNodes, nodeMap, nodeIdList) do
    nodeId  = Enum.at(nodeIdList, nodeNum-1)
    currNodeIdList = nodeIdList -- [nodeId]

    matchingNodesList = Enum.reduce(0..numNodes-1, %{}, fn(i, acc) ->
      l1 = String.myers_difference(Enum.at(currNodeIdList,i),nodeId)
      l2 = Tuple.to_list(Enum.at(l1,0))
      l3 = if Enum.member?(l2,:eq) do Enum.at(l2,1) else "" end
      strLen = String.length(l3)
      matchNodeId = Enum.at(nodeIdList,i)
      Map.put(acc, matchNodeId, strLen)
    end)
    matchingNodesKeys     = Map.keys(matchingNodesList)
    matchingNodesValues   = Map.values(matchingNodesList)
    matchingMaxLen        = Enum.max(matchingNodesValues)
    matchingNodeIndex     = Enum.find_index(matchingNodesValues, fn x -> x == matchingMaxLen end)
    matchingNodeId        = Enum.at(matchingNodesKeys,matchingNodeIndex)
    matchingNodeIndexPid  = Enum.find_index(nodeIdList, fn x -> x == matchingNodeId end)
    matchingNodePid       = Enum.at(nodeMap, matchingNodeIndexPid)

    otherMatchingNodes = Enum.map(matchingNodesList, fn {key, val} ->
      if val == matchingMaxLen do
        key
      end end)
    otherMatchingNodes = Enum.uniq(otherMatchingNodes) -- [nil]


    {:ok, matchingNodeNeighbors} = TapestryNodeServer.getNodeNeighbors(matchingNodePid)
    matchingNodeDetails = %{}
    matchingNodeDetails = Map.put(matchingNodeDetails, "matchingNodeNeighbors", matchingNodeNeighbors)
    matchingNodeDetails = Map.put(matchingNodeDetails, "matchingNodeId", matchingNodeId)
    matchingNodeDetails = Map.put(matchingNodeDetails, "matchingMaxLen", matchingMaxLen)
    matchingNodeDetails = Map.put(matchingNodeDetails, "otherMatchingNodes", otherMatchingNodes)
    matchingNodeDetails
  end

  #function to publish casting message to neighbors of the new node to tell that a new node
  #has joined the network
  def multicastNewNodeNeighbors(nodePid, nodeId, nodeMap, nodeIdList) do
    {:ok, nodeNeighbors} = TapestryNodeServer.getNodeNeighbors(nodePid)
    for i <- 1..@nodeIdLen do
      for j <- 0..@nodeHexVal-1 do
        checkNodeId = Enum.at(Map.get(nodeNeighbors, i),j)
        if checkNodeId != "" do
          checkNodeIndex  = Enum.find_index(nodeIdList, fn x -> x == checkNodeId end)
          checkNodePid    = Enum.at(nodeMap, checkNodeIndex)
          {:ok, checkNodeNeighbors} = TapestryNodeServer.getNodeNeighbors(checkNodePid)
          {colVal, ""} = Integer.parse(String.at(nodeId,i-1), 16)
          toUpdateNodeId = Enum.at(Map.get(checkNodeNeighbors,i),colVal)
          if toUpdateNodeId == "" do
            updateNodeDetails = %{}
            updateNodeDetails = Map.put(updateNodeDetails, "nodeId", nodeId)
            updateNodeDetails = Map.put(updateNodeDetails, "rowVal", i)
            updateNodeDetails = Map.put(updateNodeDetails, "colVal", colVal)
            TapestryNodeServer.updateHashTable(checkNodePid,updateNodeDetails)
          end
        end
      end
    end
  end

#There maybe more than 1 maximum prefix matches for the newly joined node
#so we additionally cast the information to every other match
  def additionalMulticast(nodePid, nodeId, rootNodeId) do
    {:ok, nodeNeighbors} = TapestryNodeServer.getNodeNeighbors(nodePid)
    l1 = String.myers_difference(rootNodeId,nodeId)
    l2 = Tuple.to_list(Enum.at(l1,0))
    l3 = if Enum.member?(l2,:eq) do Enum.at(l2,1) else "" end
    rowVal = String.length(l3)
    {colVal, ""} = if rowVal == 0 do Integer.parse(String.first(rootNodeId), 16) else Integer.parse(String.at(rootNodeId,rowVal), 16) end
    checkNodeId = Enum.at(Map.get(nodeNeighbors, rowVal+1),colVal)
    if checkNodeId == "" do
      updateNodeDetails = %{}
      updateNodeDetails = Map.put(updateNodeDetails, "nodeId", rootNodeId)
      updateNodeDetails = Map.put(updateNodeDetails, "rowVal", rowVal+1)
      updateNodeDetails = Map.put(updateNodeDetails, "colVal", colVal)
      TapestryNodeServer.updateHashTable(nodePid,updateNodeDetails)
    end
  end

  def getRandomNode(nodeIdList) do
    Enum.random(nodeIdList)
  end
end
