defmodule TapestryNodeServer do
  use GenServer

  @nodeIdLen 8
  @nodeHexVal 16
  @hashFunction :sha

  def start_link(node) do
    GenServer.start_link(__MODULE__, node)
  end

  def getNodeId(indexServer) do
    GenServer.call(indexServer, {:getNodeId})
  end

  def getNodeNeighbors(indexServer) do
    GenServer.call(indexServer, {:getNodeNeighbors})
  end

  def setNodeHashTable(indexServer, nodeIdList) do
    GenServer.cast(indexServer, {:setNodeHashTable, nodeIdList})
  end

  def setNewNodeHashTable(indexServer, nodeDetails) do
    GenServer.cast(indexServer, {:setNewNodeHashTable, nodeDetails})
  end

  def updateHashTable(indexServer, nodeDetails) do
    GenServer.cast(indexServer, {:updateHashTable, nodeDetails})
  end

  def init(node) do
    nodeId = :crypto.hash(@hashFunction, "#{node}") |> Base.encode16() |> String.slice(0..@nodeIdLen-1)
    {:ok, %{"nodeNum" => node, "nodeId" => nodeId, "nodeNeighbors" => %{}}}
  end

  def handle_call({:getNodeId}, _from, state) do
    {:ok, nodeId} = Map.fetch(state, "nodeId")
    {:reply, nodeId, state}
  end

  def handle_call({:getNodeNeighbors}, _from, state) do
    {:reply, Map.fetch(state, "nodeNeighbors"), state}
  end

  def handle_cast({:setNodeHashTable, nodeIdList}, state) do
    {:ok, currNodeId} = Map.fetch(state, "nodeId")
    currHashTable = Enum.reduce(1..@nodeIdLen, %{}, fn(j, acc) ->
      levelList = [] ++ Enum.map(0..@nodeHexVal-1, fn(k) ->
        l = Integer.to_string(k, 16)
        m = if(j == 1) do "" else currNodeId |> String.slice(0..j-2) end
        n = m<>l
        checkNodeList = Enum.filter(nodeIdList, fn x -> String.starts_with?(x,n) end)
        checkNodeList = checkNodeList -- [currNodeId]
        splitComp = currNodeId |> String.slice(0..String.length(n)-1)
        if (List.first(checkNodeList) == nil) or (splitComp == n) do
          ""
        else
          Enum.random(checkNodeList)
        end
      end)
      Map.put(acc, j, levelList)
    end)
    {:noreply, Map.put(state, "nodeNeighbors", currHashTable)}
  end

  def handle_cast({:setNewNodeHashTable, nodeDetails}, state) do
    {:ok, currNodeId} = Map.fetch(state, "nodeId")
    nodeIdList      = Map.get(nodeDetails, "nodeIdList")
    matchingMaxLen  = Map.get(nodeDetails, "matchingMaxLen")
    matchingNodeNeighbors = Map.get(nodeDetails, "matchingNodeNeighbors")
    currHashTable1 = Enum.reduce(1..matchingMaxLen+1, %{}, fn(j, acc) ->
      Map.put(acc, j, Map.get(matchingNodeNeighbors,j))
    end)
    currHashTable2 = Enum.reduce(matchingMaxLen+1..@nodeIdLen, %{}, fn(j, acc) ->
      levelList = [] ++ Enum.map(0..@nodeHexVal-1, fn(k) ->
        l = Integer.to_string(k, 16)
        m = if(j == 1) do "" else currNodeId |> String.slice(0..j-2) end
        n = m<>l
        checkNodeList = Enum.filter(nodeIdList, fn x -> String.starts_with?(x,n) end)
        checkNodeList = checkNodeList -- [currNodeId]
        splitComp = currNodeId |> String.slice(0..String.length(n)-1)
        if (List.first(checkNodeList) == nil) or (splitComp == n) do
          ""
        else
          Enum.random(checkNodeList)
        end
      end)
      Map.put(acc, j, levelList)
    end)
    currHashTable = Map.merge(currHashTable1, currHashTable2)
    {:noreply, Map.put(state, "nodeNeighbors", currHashTable)}
  end

  def handle_cast({:updateHashTable, nodeDetails}, state) do
    {:ok, nodeNeighbors} = Map.fetch(state, "nodeNeighbors")
    nodeId  = Map.get(nodeDetails, "nodeId")
    rowVal  = Map.get(nodeDetails, "rowVal")
    colVal  = Map.get(nodeDetails, "colVal")
    lvlNeighbors = Map.get(nodeNeighbors, rowVal)
    lvlNeighbors = List.replace_at(lvlNeighbors, colVal, nodeId)
    newNodeNeighbors = Map.replace!(nodeNeighbors, rowVal, lvlNeighbors)
    {:noreply, Map.put(state, "nodeNeighbors", newNodeNeighbors)}
  end
end
