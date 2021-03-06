'handles network events

'first 100 ids reserved for base network events
'Const NET_SETSLOT:Int					= 101	' SERVER: command from server to set to a given playerslot
'Const NET_SLOTSET:Int					= 102	' ALL: 	  response to all, that IP uses slot X now

Const NET_SENDGAMESTATE:Int				= 102	' ALL:    sends a ReadyFlag
Const NET_GAMEREADY:Int					= 103	' ALL:    sends a ReadyFlag
Const NET_PREPAREGAME:Int				= 104	' SERVER: sends a request to change gamestate
Const NET_STARTGAME:Int					= 105	' SERVER: sends a StartFlag
Const NET_CHATMESSAGE:Int				= 106	' ALL:    a sent chatmessage ;D
Const NET_PLAYERDETAILS:Int				= 107	' ALL:    name, channelname...
Const NET_FIGUREPOSITION:Int			= 108	' ALL:    x,y,room,target...
Const NET_FIGURECHANGETARGET:Int		= 109	' ALL:    coordinates of the new target...
Const NET_ELEVATORSYNCHRONIZE:Int		= 111	' SERVER: synchronizing the elevator
Const NET_ELEVATORROUTECHANGE:Int		= 112	' ALL:    elevator routes have changed
Const NET_NEWSSUBSCRIPTIONCHANGE:Int	= 113	' ALL:	  sends Changes in subscription levels of news-agencies
Const NET_STATIONMAPCHANGE:Int			= 114	' ALL:    stations have changes (added ...)
Const NET_MOVIEAGENCYCHANGE:Int			= 115	' ALL:    sends changes of programme in movieshop
Const NET_ROOMAGENCYCHANGE:Int			= 116	' ALL:    sends changes to room details (owner changes etc.)
Const NET_PROGRAMMECOLLECTIONCHANGE:Int = 117	' ALL:    programmecollection was changed (removed, sold...)
Const NET_PROGRAMMEPLAN_CHANGE:Int		= 118	' ALL:    playerprogramme has changed (added, removed, ...movies,ads ...)
Const NET_PLAN_SETNEWS:Int				= 119
Const NET_GAMESETTINGS:Int				= 121	' SERVER: send extra settings (random seed value etc.)

Const NET_DELETE:Int					= 0
Const NET_ADD:Int						= 1000

Const NET_CHANGE:Int					= 3000
Const NET_BUY:Int						= 4000
Const NET_SELL:Int						= 5000
Const NET_BID:Int						= 6000
Const NET_SWITCH:Int					= 7000
Const NET_TOSUITCASE:Int				= 8000
Const NET_FROMSUITCASE:Int				= 9000

Network.callbackServer = ServerEventHandler
Network.callbackClient = ClientEventHandler


'=== EVENTS FOR SERVER ===
Function ServerEventHandler(server:TNetworkServer,client:TNetworkclient,id:Int, networkObject:TNetworkObject)
	Select networkObject.evType
		'player joined, send player data to all
		case NET_PLAYERJOINED
			NetworkHelper.SendPlayerDetails()
'		default
'			print "server got unused event:" + networkObject.evType
	EndSelect
End Function


'=== EVENTS FOR CLIENT ===
Function ClientEventHandler(client:TNetworkclient,id:Int, networkObject:TNetworkObject)
	local inGame:int = (Game.gamestate = TGame.STATE_RUNNING)

	Select networkObject.evType
		case NET_PLAYERJOINED
			local playerID:int = NetworkObject.getInt(1)
			local playerName:string	= NetworkObject.getString(2)
			'skip invalid players
			if not GetPlayer(playerID) then return

			'a package from a REMOTE player, not me
			if GetPlayerCollection().playerID <> playerID
				GetPlayer(playerID).SetRemoteHumanControlled(playerID)
				print "set playerID " + playerID +" as remote human"
			endif

			'send others all important extra game data
			local gameData:TNetworkObject = TNetworkObject.Create( NET_GAMESETTINGS )
			gameData.setInt(1, GetPlayerCollection().playerID)
			gameData.setInt(2, Game.GetRandomizerBase() )
			'TODO: add game settings/rules
			Network.BroadcastNetworkObject( gameData, NET_PACKET_RELIABLE )


		case NET_JOINRESPONSE
			'=== ONLY CLIENTS ===
			if Network.isServer then return
			if not Network.client.joined then return

			'we are not the gamemaster and got a playerID
			local joined:int = NetworkObject.getInt(1)
			local playerID:int = NetworkObject.getInt(2)
			if GetPlayer(playerID)
				GetPlayerCollection().playerID = playerID
				Network.client.playerID = playerID
				GetPlayerCollection().Get(playerID).SetLocalHumanControlled()

				TLogger.Log("Network.ClientEventHandler", "got join response. Server requested to to set playerID to "+playerID, LOG_DEBUG | LOG_NETWORK)
			else
				TLogger.Log("Network.ClientEventHandler", "got join response. Server request contained invalid playerID ~q"+playerID+"~q", LOG_DEBUG | LOG_NETWORK)
			endif


		case NET_GAMESETTINGS
			'=== ONLY CLIENTS ===
			if Network.isServer then return
			if not Network.client.joined then return
			
			local hostPlayerID:int = NetworkObject.getInt(1)
			local randomSeedValue:int = NetworkObject.getInt(2)
			Game.SetRandomizerBase( randomSeedValue )


		case NET_PREPAREGAME
				print "NET: received preparegame"
				Game.SetGameState(TGame.STATE_PREPAREGAMESTART)

		case NET_STARTGAME
				print "NET: received startgame"
				Game.startNetworkGame = True

		case NET_GAMEREADY
				NetworkHelper.ReceiveGameReady( networkObject )

		case NET_SENDGAMESTATE
				NetworkHelper.ReceiveGameState( networkObject )

		case NET_PLAYERDETAILS
				NetworkHelper.ReceivePlayerDetails( networkObject )

		case NET_FIGUREPOSITION
				if inGame then NetworkHelper.ReceiveFigurePosition( networkObject )

		case NET_FIGURECHANGETARGET
				if inGame then NetworkHelper.ReceiveFigureChangeTarget( networkObject )

		case NET_CHATMESSAGE
			NetworkHelper.ReceiveChatMessage( networkObject )

		'not working yet
		case NET_ELEVATORROUTECHANGE
				if inGame then NetworkHelper.ReceiveElevatorRouteChange( networkObject )
		case NET_ELEVATORSYNCHRONIZE
				if inGame then NetworkHelper.ReceiveElevatorSynchronize( networkObject )

		case NET_NEWSSUBSCRIPTIONCHANGE
				if inGame then NetworkHelper.ReceiveNewsSubscriptionChange( networkObject )
		case NET_MOVIEAGENCYCHANGE
				if inGame then NetworkHelper.ReceiveMovieAgencyChange( networkObject )
		case NET_ROOMAGENCYCHANGE
				if inGame then NetworkHelper.ReceiveRoomAgencyChange( networkObject )
		case NET_PROGRAMMECOLLECTIONCHANGE
				if inGame then NetworkHelper.ReceiveProgrammeCollectionChange( networkObject )
		case NET_STATIONMAPCHANGE
				if inGame then NetworkHelper.ReceiveStationmapChange( networkObject )

		case NET_PROGRAMMEPLAN_CHANGE
				if inGame then NetworkHelper.ReceiveProgrammePlanChange(networkObject)
		case NET_PLAN_SETNEWS
				if inGame then NetworkHelper.ReceivePlanSetNews( networkObject )

		default
				if networkObject.evType>=100
					TLogger.Log("Network.ClientEventHandler", "got unused event: "+networkObject.evType+".", LOG_DEBUG | LOG_NETWORK)
				endif
	EndSelect

End Function




'=== EVENTS FROM INFO CHANNEL ===
'redirect a networkobject as event so others may connect easily
Function InfoChannelEventHandler(networkObject:TNetworkObject)
'	print "infochannel: got event: "+networkObject.evType
	if networkObject.evType = NET_ANNOUNCEGAME
		local evData:TData = new TData
		evData.AddNumber("slotsUsed", networkObject.getInt(1))
		evData.AddNumber("slotsMax", networkObject.getInt(2))
		evData.AddNumber("hostIP", networkObject.getInt(3)) 		'could differ from senderIP
		evData.AddNumber("hostPort", networkObject.getInt(4)) 		'differs from senderPort (info channel)
		evData.AddString("hostName", networkObject.getString(5))
		evData.AddString("gameTitle", networkObject.getString(6))

		EventManager.triggerEvent(TEventSimple.Create( "network.infoChannel.onReceiveAnnounceGame", evData, null))
	endif
End Function




Type TNetworkHelper
	field registeredEvents:int = FALSE
	'disable if functions get called which emit events 
	Global listenToEvents:int = FALSE


	Method Create:TNetworkHelper()
		'self.RegisterEventListeners()
		return self
	End Method


	Method RegisterEventListeners:int()
		if registeredEvents then return FALSE

		EventManager.registerListenerFunction("programmeplan.SetNews", TNetworkHelper.onPlanSetNews)
		'someone adds a chatline
		EventManager.registerListenerFunction("chat.onAddEntry", TNetworkHelper.OnChatAddEntry)
		'changes to the player's stationmap
		EventManager.registerListenerFunction("stationmap.removeStation", TNetworkHelper.onChangeStationmap)
		EventManager.registerListenerFunction("stationmap.addStation", TNetworkHelper.onChangeStationmap)

		'changes to rooms (eg. owner changes)
		EventManager.registerListenerFunction("RoomAgency.rentRoom", TNetworkHelper.onChangeRoomAgency)

		'changes to the player's programmecollection
		EventManager.registerListenerFunction("programmecollection.removeProgrammeLicence", TNetworkHelper.onChangeProgrammeCollection)
		EventManager.registerListenerFunction("programmecollection.addProgrammeLicence", TNetworkHelper.onChangeProgrammeCollection)
		EventManager.registerListenerFunction("programmecollection.removeAdContract", TNetworkHelper.onChangeProgrammeCollection)
		EventManager.registerListenerFunction("programmecollection.addAdContract",	TNetworkHelper.onChangeProgrammeCollection)
		EventManager.registerListenerFunction("programmecollection.removeProgrammeLicenceFromSuitcase", TNetworkHelper.onChangeProgrammeCollection)
		EventManager.registerListenerFunction("programmecollection.addProgrammeLicenceToSuitcase", TNetworkHelper.onChangeProgrammeCollection)

		'listen to events to refresh figure position 
		EventManager.registerListenerFunction("figure.onSyncTimer", TNetworkHelper.onFigurePositionChanged)
		EventManager.registerListenerFunction("figure.onReachTarget", TNetworkHelper.onFigurePositionChanged)
		EventManager.registerListenerFunction("figure.onSetInRoom", TNetworkHelper.onFigurePositionChanged)
		'as soon as a figure changes its target (add it to the "route")
		EventManager.registerListenerFunction("figure.onChangeTarget", TNetworkHelper.onFigureChangeTarget)

		'changes in movieagency
		EventManager.registerListenerFunction("ProgrammeLicenceAuction.setBid", TNetworkHelper.onChangeMovieAgency)

		registeredEvents = true
	End Method


	Function onChangeRoomAgency:int( triggerEvent:TEventBase )
		if not listenToEvents then return False

		'only react if game leader / server
		'if not Game.isGameLeader() then return False
		if not Network.isServer then return False

		local room:TRoom = TRoom(triggerEvent.GetSender())
		if not room then return False

		local action:int = -1
		if triggerEvent.isTrigger("RoomAgency.rentRoom") then action = NET_BUY
		if triggerEvent.isTrigger("RoomAgency.cancelRoom") then action = NET_SELL
		if action = -1 then return FALSE

		local owner:int = triggerEvent.GetData().GetInt("newOwner", 0)
		NetworkHelper.SendRoomAgencyChange(room, action, owner)
	End Function
	

	'connect GUI with normal handling
	Function onPlanSetNews:int( triggerEvent:TEventBase )
		local news:TNews = TNews(triggerEvent._sender)
		if not news then return 0

		local slot:int = triggerEvent.getData().getInt("slot",-1)
		if slot < 0 then return 0

		'ignore ai player's events if no gameleader
		if not Game.isGameLeader() and GetPlayer(news.owner).isLocalAi() then return false
		'do not allow events from players for other players objects
		if news.owner <> GetPlayerCollection().playerID and not Game.isGameLeader() then return FALSE

		NetworkHelper.SendPlanSetNews(GetPlayerCollection().playerID, news, slot)
	End Function


	'connect GUI with normal handling
	Function onChangeStationmap:int( triggerEvent:TEventBase )
		local stationmap:TStationMap = TStationMap(triggerEvent._sender)
		if not stationmap then return FALSE

		local station:TStation = TStation( triggerEvent.getData().get("station") )
		if not station then return FALSE

		'ignore ai player's events if no gameleader
		if not Game.isGameLeader() and GetPlayer(station.owner).isLocalAi() then return false
		'do not allow events from players for other players objects
		if station.owner <> GetPlayerCollection().playerID and not Game.isGameLeader() then return FALSE

		local action:int = -1
		if triggerEvent.isTrigger("stationmap.addStation") then action = NET_ADD
		if triggerEvent.isTrigger("stationmap.removeStation") then action = NET_DELETE
		if action = -1 then return FALSE

		NetworkHelper.SendStationmapChange(station, action)
	End Function


	Function onFigurePositionChanged:int( triggerEvent:TEventBase )
		local figure:TFigure = TFigure(triggerEvent.GetSender())
		if not figure then return FALSE

		NetworkHelper.SendFigurePosition(figure)
	End Function


	Function onFigureChangeTarget:int( triggerEvent:TEventBase )
		local figure:TFigure = TFigure(triggerEvent.GetSender())
		if not figure then return FALSE

		'only send changes for figures WE control
		local playerID:int = GetPlayerBaseCollection().playerID
		'other player ?
		if figure.playerID > 0 and figure.playerID <> playerID then return False
		'other figures are controlled by GameLeader
		if figure.playerID = 0 and not Game.IsGameLeader() then return False
	

		local x:int = triggerEvent.GetData().GetInt("x", 0)
		local y:int = triggerEvent.GetData().GetInt("y", 0)
		local forceChange:int = triggerEvent.GetData().GetInt("forceChange", 0)
		NetworkHelper.SendFigureChangeTarget(figure, x, y, forceChange)
	End Function


	Function onChangeProgrammeCollection:int( triggerEvent:TEventBase )
		local programmeCollection:TPlayerProgrammeCollection = TPlayerProgrammeCollection(triggerEvent._sender)
		if not programmeCollection then return 0

		local owner:int = programmeCollection.owner
		'ignore ai player's events if no gameleader
		if GetPlayer(owner).isLocalAi() and not Game.isGameLeader() then return false
		'do not allow events from players for other players objects
		if owner <> GetPlayerCollection().playerID and not Game.isGameLeader() then return FALSE

		select triggerEvent.getTrigger()
			case "programmecollection.removeprogrammelicence"
					local Licence:TProgrammeLicence = TProgrammeLicence(triggerEvent.GetData().get("programmeLicence"))
					local sell:int = triggerEvent.GetData().getInt("sell",FALSE)
					if sell
						NetworkHelper.SendProgrammeCollectionProgrammeLicenceChange(owner, Licence, NET_SELL)
					else
						NetworkHelper.SendProgrammeCollectionProgrammeLicenceChange(owner, Licence, NET_DELETE)
					endif
			case "programmecollection.addprogrammelicence"
					local Licence:TProgrammeLicence = TProgrammeLicence(triggerEvent.GetData().get("programmeLicence"))
					local buy:int = triggerEvent.GetData().getInt("buy",FALSE)
					if buy
						NetworkHelper.SendProgrammeCollectionProgrammeLicenceChange(owner, Licence, NET_BUY)
					else
						NetworkHelper.SendProgrammeCollectionProgrammeLicenceChange(owner, Licence, NET_ADD)
					endif

			case "programmecollection.addprogrammelicencetosuitcase"
					local licence:TProgrammeLicence = TProgrammeLicence(triggerEvent.GetData().get("programmeLicence"))
					NetworkHelper.SendProgrammeCollectionProgrammeLicenceChange(owner, licence, NET_TOSUITCASE)
			case "programmecollection.removeprogrammelicencefromsuitcase"
					local licence:TProgrammeLicence = TProgrammeLicence(triggerEvent.GetData().get("programmeLicence"))
					NetworkHelper.SendProgrammeCollectionProgrammeLicenceChange(owner, licence, NET_FROMSUITCASE)

			case "programmecollection.removeadcontract"
					local contract:TAdContract = TAdContract(triggerEvent.GetData().get("adcontract"))
					NetworkHelper.SendProgrammeCollectionContractChange(owner, contract, NET_DELETE)
			case "programmecollection.addadcontract"
					local contract:TAdContract = TAdContract(triggerEvent.GetData().get("adcontract"))
					NetworkHelper.SendProgrammeCollectionContractChange(owner, contract, NET_ADD)
		end select

		return FALSE
	End Function


	Function onChangeMovieAgency:int( triggerEvent:TEventBase )
		Select triggerEvent.getTrigger()
			case "programmelicenceauction.setbid"
				local licence:TProgrammeLicence = TProgrammeLicence(triggerEvent.GetData().get("licence"))
				local playerID:int = triggerEvent.GetData().getInt("bestBidder", -1)
				NetworkHelper.SendMovieAgencyChange(NET_BID, playerID, -1, -1, licence)
		End Select
	End Function



	Method SendGameState()
		local obj:TNetworkObject = TNetworkObject.Create( NET_SENDGAMESTATE )
		obj.setInt(1, GetPlayerCollection().playerID)
		obj.setDouble(2, GetWorldTime()._timeFactor)
		obj.setInt(3, GetWorldTime()._paused)
		obj.setDouble(4, GetWorldTime()._timeGoneLastUpdate) '- so clients can catch up
		obj.setDouble(5, GetWorldTime()._timeGone)
		Network.BroadcastNetworkObject( obj, not NET_PACKET_RELIABLE )
	End Method


	Method ReceiveGameState( obj:TNetworkObject )
		Local playerID:Int		= obj.getInt(1)
		'must be a player DIFFERENT to me
		if not GetPlayerCollection().IsPlayer(playerID) or playerID = GetPlayerCollection().playerID then return

		'60 upd per second = -> GetDeltaTimer().GetDeltaTime() => 16ms
		'ping in ms -> latency/2 -> 0.5*latency/16ms = "1,3 updates bis ping ankommt"
		'pro Update: zeiterhoehung von "game.speed/10.0"
		'-> bereinigung: "0.5*latency/16" * "game.speed/10.0"
		local correction:Double = 0.5 * Network.client.latency / GetDeltaTimer().GetDelta() * GetWorldTime()._timeFactor/10.0
		'we want it in s not in ms
		correction :/ 1000.0
'		print obj.getFloat(3) + "  + "+correction

		GetWorldTime()._timeFactor = obj.getDouble(2)
		GetWorldTime()._paused = obj.getInt(3)
		GetWorldTime().SetTimeGone(obj.getDouble(5) + correction)
		'done in SetTimeGone()
		'GetWorldTime()._timeGoneLastUpdate = obj.getDouble(4) + correction
	End Method

'checked
	Method SendPlayerDetails()
		'print "Send Player Details to all but me ("+TNetwork.dottedIP(host.ip)+")"
		'send packets indivual - no need to have multiple entities in one packet

		for local player:TPlayer = EachIn GetPlayerCollection().players
			'it's me or i'm hosting and its an AI player
			if player.playerID = Network.client.playerID OR (Network.isServer and Player.isLocalAI())
				'Print "[NET] send playerdetails of ME and IF I'm the host also from AI players"

				local obj:TNetworkObject = TNetworkObject.Create( NET_PLAYERDETAILS )
				obj.SetInt(	1, player.playerID )
				obj.SetString( 2, Player.name )
				obj.SetString( 3, Player.channelname )
				obj.SetInt(	4, Player.color.toInt() )
				obj.SetInt(	5, Player.figurebase )
				obj.SetInt(	6, Player.playerType )
				obj.SetInt(	7, Player.playerControlledByID )
				
				Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )
			EndIf
		Next
	End Method

	Method ReceivePlayerDetails( obj:TNetworkObject )
		Local playerID:Int = obj.getInt(1)
		local player:TPlayer = GetPlayer(playerID)
		if not player then return

		Local name:string = obj.getString(2)
		Local channelName:string = obj.getString(3)
		Local color:int	= obj.getInt(4)
		Local figureBase:int = obj.getInt(5)
		Local playerType:int = obj.getInt(6)
		Local playerControlledByID:int = obj.getInt(7)

		'=== ADJUST PLAYER TYPE ===
		'do not adjust data for our very own player
		if playerID <> GetPlayerCollection().playerID
			Select playerType
				case TPlayer.PLAYERTYPE_REMOTE_AI
					'if the player is AI, check if we control it
					if playerControlledByID = GetPlayerCollection().playerID
						player.SetLocalAIControlled()
					endif
				case TPlayer.PLAYERTYPE_LOCAL_AI
					'this means, it is local to the game leader
					player.SetRemoteAIControlled(playerControlledByID)
				case TPlayer.PLAYERTYPE_LOCAL_HUMAN
					'this means, it is local to the game leader
					player.SetRemoteHumanControlled(playerControlledByID)
				case TPlayer.PLAYERTYPE_REMOTE_HUMAN
					'if the player is AI, check if we control it
					if playerControlledByID = GetPlayerCollection().playerID
						player.SetLocalHumanControlled()
					endif
			End Select
		endif
		
		'=== REFRESH PLAYER DATA ===
		'only refresh for players we do not control
		If playerControlledByID <> GetPlayerCollection().playerID 
			If figureBase <> player.figurebase
				player.UpdateFigureBase(figureBase)
			endif
			
			If player.color.toInt() <> color
				player.color.fromInt(color)
				player.RecolorFigure()
			EndIf

			player.name = name
			player.channelname = channelName
			local screen:TScreen_GameSettings = TScreen_GameSettings(ScreenCollection.GetScreen("GameSettings"))
			screen.guiPlayerNames[ playerID-1 ].value = name
			screen.guiChannelNames[ playerID-1 ].value = channelName
			player.figure.playerID = playerID
		EndIf
	End Method



'checked
	Method SendFigurePosition:int(figure:TFigure)
		'"not-player" figures can only be send from Master
		if figure.playerID and not Network.isServer then return Null

		local obj:TNetworkObject = TNetworkObject.Create( NET_FIGUREPOSITION )
		obj.SetInt( 1, figure.id )		'playerID
		obj.SetFloat( 2, figure.area.GetX() )	'position.x
		obj.SetFloat( 3, figure.area.GetY() )	'...
		if figure.inRoom then obj.setInt( 4, figure.inRoom.id)
		if figure.fromRoom then obj.setInt( 5, figure.fromRoom.id)
		if figure.fromDoor then obj.setInt( 6, figure.fromDoor.id)
		Network.BroadcastNetworkObject( obj )
	End Method
	

	Method ReceiveFigurePosition( obj:TNetworkObject )
		Local figureID:Int = obj.getInt(1)
		local figure:TFigure = GetFigureCollection().Get( figureID )
		if figure = null then return

		local posX:Float = obj.getFloat(2)
		local posY:Float = obj.getFloat(3)
		local inRoomID:int = obj.getInt( 4, -1, TRUE )
		local fromRoomID:int = obj.getInt( 5, -1, TRUE )
		local fromDoorID:int = obj.getInt( 6, -1, TRUE )

		If inRoomID <= 0 Then figure.inRoom = Null
		If figure.inRoom
			If inRoomID > 0 and figure.inRoom.id <> inRoomID
				figure.inRoom = GetRoomCollection().Get(inRoomID)
			EndIf
		EndIf


		if figure.GetTarget()
			If not figure.IsInElevator()
				local targetPos:TVec2D = figure.GetTargetMoveToPosition()
				'only set X if wrong floor or x differs > 10 pixels
				if posY = targetPos.x
					if Abs(posX - targetPos.x) > 10 then figure.area.position.setXY(posX, posY)
				else
					figure.area.position.setXY(posX, posY)
				endif
			endif
		endif
		
		
		If fromRoomID <= 0 Then figure.fromRoom = Null
		If fromRoomID > 0 And figure.fromroom
			If figure.fromRoom.id <> fromRoomID
				figure.fromRoom = GetRoomCollection().Get( fromRoomID )
				figure.fromDoor = GetRoomDoorBaseCollection().Get( fromDoorID )
			endif
		EndIf
	End Method


	Method SendFigureChangeTarget:int(figure:TFigure, x:int, y:int, forceChange:int)
		local obj:TNetworkObject = TNetworkObject.Create( NET_FIGURECHANGETARGET )
		obj.SetInt( 1, figure.id )

		'no target? send something so remote deletes potential targets too
		if not figure.GetTarget()
			obj.SetInt( 2,  0 )
			obj.SetInt( 3, -1 )
			obj.SetInt( 4, -1 )
			obj.SetInt( 5,  0 )
		else
			obj.SetInt( 2, 1 )
			obj.SetInt( 3, x )
			obj.SetInt( 4, y )
			obj.SetInt( 5, forceChange )
		endif
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )
	End Method

	Method ReceiveFigureChangeTarget( obj:TNetworkObject )
		Local figureID:Int = obj.getInt(1)
		local figure:TFigure = GetFigureCollection().Get( figureID )
		if figure = null then return

		local add:Int = obj.getInt( 2, 0 )
		local posX:Int = obj.getInt( 3, -1 )
		local posY:Int = obj.getInt( 4, -1 )
		local forceChange:Int = obj.getInt( 5,  0 )
		if add
			figure._changeTarget(posX, posY, forceChange)
		else
			figure.ClearTargets()
		endif
	End Method
	

	Method SendPrepareGame()
		print "[NET] inform all to switch gamestate"
		Network.BroadcastNetworkObject( TNetworkObject.Create( NET_PREPAREGAME ), NET_PACKET_RELIABLE )
	End Method
	

	Method SendStartGame()
		local allReady:int = 1
		for local otherclient:TNetworkclient = eachin Network.server.clients
			if not GetPlayerCollection().Get(otherclient.playerID).networkstate then allReady = false
		Next
		if allReady
			'send game start - maybe wait for "receive" too
			Game.startNetworkGame = 1
			print "[NET] allReady so send game start to all others"
			Network.BroadcastNetworkObject( TNetworkObject.Create( NET_STARTGAME ), NET_PACKET_RELIABLE )
			return
		endif
	End Method

'checked
	'ask players if they are ready to start a game
	Method SendGameReady(playerID:Int, onlyTo:Int=-1)
		local obj:TNetworkObject = TNetworkObject.Create( NET_GAMEREADY )
		obj.setInt(1, playerID)
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )

		'self ready
		GetPlayerCollection().Get(playerID).networkstate = 1

		for local i:int = 1 to 4
			'set AI players ready
			if GetPlayerCollection().IsLocalAi(i) then GetPlayerCollection().Get(i).networkstate = 1
		Next

		if Network.isServer then SendStartGame()
	End Method

	'server asks me if i am ready to start the game
	Method ReceiveGameReady( obj:TNetworkObject )
		print "[NET] ReceiveGameReady"

		'set remote player as ready
		local remotePlayerID:int = obj.getInt(1)
		GetPlayerCollection().Get(remotePlayerID).networkstate = 1

		if Game.GAMESTATE <> TGame.STATE_RUNNING
			SendGameReady( GetPlayerCollection().playerID, 0 )
		endif
	End Method


	Method ReceiveElevatorRouteChange( obj:TNetworkObject )
		print "IMPLEMENT ReceiveElevatorRouteChange()"
	End Method


	Method ReceiveElevatorSynchronize( obj:TNetworkObject )
		print "IMPLEMENT ReceiveElevatorSynchronize()"
	End Method

'checked
	Method SendNewsSubscriptionChange(playerID:Int, genre:int, level:int)
		local obj:TNetworkObject = TNetworkObject.Create( NET_NEWSSUBSCRIPTIONCHANGE )
		obj.setInt(1, playerID)
		obj.setInt(2, genre)
		obj.setInt(3, level)
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )
	End Method

	Method ReceiveNewsSubscriptionChange( obj:TNetworkObject )
		Local playerID:Int = obj.getInt(1)
		local player:TPlayer = GetPlayerCollection().Get( playerID )
		if player = null then return

		Local genre:Int	= obj.getInt(2)
		Local level:Int	= obj.getInt(3)
		'print "[NET] ReceiveNewsSubscriptionChange: player="+playerID+", genre="+genre+", level="+level
		player.setNewsAbonnement(genre, level, false)
	End Method




	Method SendMovieAgencyChange(methodtype:int, playerID:Int, newID:Int=-1, slot:Int=-1, licence:TProgrammeLicence)
		local obj:TNetworkObject = TNetworkObject.Create( NET_MOVIEAGENCYCHANGE )
		obj.setInt(1, playerID)
		obj.setInt(2, methodtype)
		obj.setInt(3, newid)
		obj.setInt(4, slot)
		obj.setInt(5, licence.id)
		Network.BroadcastNetworkObject( obj,  NET_PACKET_RELIABLE )
	End Method

	Method ReceiveMovieAgencyChange( obj:TNetworkObject )
		Local playerID:Int = obj.getInt(1)
		Local methodtype:Int = obj.getInt(2)
		Local newid:Int = obj.getInt(3)
		Local slot:Int = obj.getInt(4)
		Local licenceID:Int = obj.getInt(5)

		Local tmpID:Int = -1
		Local oldX:Int, oldY:Int
		Select methodtype
			Case NET_BID
					local obj:TAuctionProgrammeBlocks = TAuctionProgrammeBlocks.GetByLicence(null, licenceID)
					if obj
						obj.SetBid(playerID)
						print "[NET] MovieAgency auction bid "+methodtype+" obj:"+obj.licence.GetTitle()
					else
						print "[NET] ERROR: ReceiveMovieAgencyChange - licence not found."
					endif
			Default
					Print "SendMovieAgencyChange: no method mentioned"
		End Select
	End Method



	Method SendRoomAgencyChange(room:TRoom, action:int=0, owner:int=0)
		local obj:TNetworkObject = TNetworkObject.Create( NET_ROOMAGENCYCHANGE )
		obj.SetInt(1, room.owner)
		obj.SetInt(2, action)
		obj.SetInt(3, owner)
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )
	End Method

	Method ReceiveRoomAgencyChange:int(obj:TNetworkObject)
		local roomID:int = obj.getInt(1)
		local action:int = obj.getInt(2)
		local newOwner:int = obj.getInt(3)

		local room:TRoom = GetRoomCollection().Get(roomID)
		if not room then return False

		'disable events - ignore it to avoid recursion
		listenToEvents = False

		select action
			case NET_BUY
					RoomHandler_RoomAgency.rentRoom(room, newOwner)
					print "[NET] RoomAgency: player "+newOwner+" rents room "+ room.GetName()

					return TRUE
			case NET_SELL
					local oldOwner:int = room.owner
					RoomHandler_RoomAgency.cancelRoom(room)
					print "[NET] RoomAgencY: player "+oldOwner+" stopped renting room "+room.GetName()
					return TRUE
		EndSelect

		listenToEvents = TRUE
	End Method


	Method SendStationmapChange(station:TStation, action:int=0)
		local obj:TNetworkObject = TNetworkObject.Create( NET_STATIONMAPCHANGE )
		obj.SetInt(1, station.owner)
		obj.SetInt(2, action)
		obj.SetFloat(3, station.pos.x)
		obj.SetFloat(4, station.pos.y)
		obj.SetInt(5, station.radius)
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )
	End Method

	Method ReceiveStationmapChange:int( obj:TNetworkObject)
		local playerID:int		= obj.getInt(1)
		local action:int		= obj.getInt(2)
		local pos:TVec2D		= new TVec2D.Init( obj.getFloat(3), obj.getFloat(4) )
		local radius:int		= obj.getInt(5)
		if not GetPlayerCollection().IsPlayer(playerID) then return FALSE

rem
		local station:TStation
		if GetStationMapCollection()
			print "mapcoll ok"
			if GetStationMapCollection().GetMap(playerID)
				print "map ok"
				if GetStationMapCollection().GetMap(playerID).getStation(pos.x, pos.y)
					station = GetStationMapCollection().GetMap(playerID).getStation(pos.x, pos.y)
					print "station ok"
				endif
			endif
		endif
		if not station then return False
endrem
		local station:TStation	= GetStationMapCollection().GetMap(playerID, True).getStation(pos.x, pos.y)

		'disable events - ignore it to avoid recursion
		TStationMap.fireEvents = FALSE

		select action
			case NET_ADD
					'create the station if not existing
					if not station then station = TStation.Create(pos,-1, radius, playerID)

					GetStationMapCollection().GetMap(playerID).AddStation( station, FALSE )
					print "[NET] StationMap player "+playerID+" - add station "+station.pos.GetIntX()+","+station.pos.GetIntY()

					return TRUE
			case NET_DELETE
					if not station then return FALSE

					GetStationMapCollection().GetMap(playerID).RemoveStation( station, FALSE )
					print "[NET] StationMap player "+playerID+" - removed station "+station.pos.GetIntX()+","+station.pos.GetIntY()
					return TRUE
		EndSelect
		TStationMap.fireEvents = TRUE
	End Method


	Method SendProgrammeCollectionProgrammeLicenceChange(playerID:int= -1, licence:TProgrammeLicence, action:int=0)
		self.SendProgrammeCollectionChange(playerID, 1, licence.id, action)
	End Method
	
	Method SendProgrammeCollectionContractChange(playerID:int= -1, contract:TAdContract, action:int=0)
		local id:int = contract.id
		'when adding a new contract, we do not send the contract id
		'itself (it is useless for others)
		'but the contractbase.id so the remote client can reconstruct
		if action = NET_ADD then id = contract.base.id

		self.SendProgrammeCollectionChange(playerID, 2, id, action)
	End Method

	Method SendProgrammeCollectionChange(playerID:int= -1, objectType:int=0, objectID:int=0, action:int=0)
		local obj:TNetworkObject = TNetworkObject.Create( NET_PROGRAMMECOLLECTIONCHANGE )
		obj.SetInt(1, playerID)
		obj.SetInt(2, objectType)
		obj.SetInt(3, objectID)
		obj.SetInt(4, action)
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )
	End Method

	Method ReceiveProgrammeCollectionChange:int( obj:TNetworkObject)
		local playerID:int		= obj.getInt(1)
		local objectType:int	= obj.getInt(2)
		local objectID:int		= obj.getInt(3)
		local action:int		= obj.getInt(4)
		local player:TPlayer = GetPlayerCollection().Get(playerID)
		if not player then return FALSE

		select objectType
			'ProgrammeLicence
			case 1
					Local licence:TProgrammeLicence = GetProgrammeLicenceCollection().Get(objectID)
					if not licence then return FALSE

					'disable events - ignore it to avoid recursion
					TPlayerProgrammeCollection.fireEvents = FALSE

					select action
						case NET_ADD
								player.GetProgrammeCollection().AddProgrammeLicence(licence, FALSE)
								print "[NET] PCollection"+playerID+" - add programme licence " + licence.GetTitle()
						'remove from Collection (Archive - RemoveProgrammeLicence)
						case NET_DELETE
								player.GetProgrammeCollection().RemoveProgrammeLicence(licence, FALSE)
								print "[NET] PCollection"+playerID+" - remove programme licence " + licence.GetTitle()
						case NET_BUY
								player.GetProgrammeCollection().AddProgrammeLicence(licence, TRUE)
								print "[NET] PCollection"+playerID+" - buy programme licence " + licence.GetTitle()
						case NET_SELL
								player.GetProgrammeCollection().RemoveProgrammeLicence(licence, TRUE)
								print "[NET] PCollection"+playerID+" - sell programme licence " + licence.GetTitle()
						case NET_TOSUITCASE
								player.GetProgrammeCollection().AddProgrammeLicenceToSuitcase(licence)
								print "[NET] PCollection"+playerID+" - to suitcase - programme " + licence.GetTitle()
						case NET_FROMSUITCASE
								player.GetProgrammeCollection().RemoveProgrammeLicenceFromSuitcase(licence)
								print "[NET] PCollection"+playerID+" - from suitcase - programme licence " + licence.GetTitle()
					EndSelect

					TPlayerProgrammeCollection.fireEvents = TRUE
			'Contract
			case 2
					Local contractbase:TAdContractBase = GetAdContractBaseCollection().Get( objectID )
					if not contractbase then return FALSE

					'disable events - ignore it to avoid recursion
					TPlayerProgrammeCollection.fireEvents = FALSE

					select action
						case NET_ADD
								player.GetProgrammeCollection().AddAdContract( new TAdContract.Create(contractBase) )
								print "[NET] PCollection"+playerID+" - add contract "+contractbase.GetTitle()
						case NET_DELETE
								local contract:TAdContract = player.GetProgrammeCollection().GetAdContractByBase( contractBase.id )
								if contract
									player.GetProgrammeCollection().RemoveAdContract( contract )
									print "[NET] PCollection"+playerID+" - remove contract "+contract.GetTitle()
								endif
					EndSelect

					TPlayerProgrammeCollection.fireEvents = TRUE
		EndSelect
	End Method




	'****************************
	' send/receive chat messages
	'****************************

	'the event to fetch new messages to send
	Function onChatAddEntry:int( triggerEvent:TEventBase )
		local senderID:int 		= triggerEvent.GetData().getInt("senderID",-1)
		local sendToChannels:int= triggerEvent.GetData().getInt("channels", 0)
		local chatMessage:string= triggerEvent.GetData().getString("text", "")
		local fromRemote:string	= triggerEvent.GetData().getInt("remoteSource",0)

		'only send if not already coming from the network
		if fromRemote = 0
			NetworkHelper.SendChatMessage(chatMessage, senderID, sendToChannels)
		else
			print "received chat event FROM NETWORK -> ignoring"
		endif
	End Function

	'send new messages
	Method SendChatMessage:int(ChatMessage:String = "", senderID:int=-1, sendToChannels:int=0)
		if senderID < 0 then return FALSE
		if sendToChannels = CHAT_CHANNEL_NONE then return FALSE
		'limit to game host sending for others (AI)
		if senderID <> GetPlayerCollection().playerID and not Game.IsGameLeader() then return FALSE

		local obj:TNetworkObject = TNetworkObject.Create( NET_CHATMESSAGE)
		obj.setInt(1, GetPlayerCollection().playerID)	'so we know the origin of the packet
		obj.setInt(2, senderID)			'author of the message
		obj.setString(3, ChatMessage)
		obj.setInt(4, sendToChannels)
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE  )
	End Method

	'receive new messages
	Method ReceiveChatMessage:int( obj:TNetworkObject )
		Local originID:Int			= obj.getInt(1)
		Local senderID:Int			= obj.getInt(2)
		Local chatMessage:String	= obj.getString(3)
		Local sendToChannels:Int	= obj.getInt(4)

		'if we got back our own message, we do not want to emit
		'a new event - as we would then also will send/receive
		'it again and again and... This should not happen (but broadcasts...)
		if originID = GetPlayerCollection().playerID
			print "ERROR: ReceiveChatMessage - got back my own message!!"
			return FALSE
		endif

		'emit an event, we received a chat message
		'- add a "remoteSource=1" so others may recognize it
		EventManager.triggerEvent( TEventSimple.Create( "chat.onAddEntry", new TData.AddNumber("senderID", senderID).AddNumber("channels", sendToChannels).AddString("text",chatMessage).AddNumber("remoteSource",1) , null ) )
	End Method





	Method SendStationChange(playerID:Int, station:TStation, newaudience:Int, add:int=1)
		local obj:TNetworkObject = TNetworkObject.Create( NET_STATIONMAPCHANGE )
		obj.setInt(1, playerID)
		obj.setInt(2, add)
		obj.setFloat(3, station.Pos.x)
		obj.setFloat(4, station.Pos.y)
		obj.setInt(5, station.reach)
		obj.setInt(6, station.price)
		obj.setInt(7, newaudience)
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )
	End Method


	Method SendPlanSetNews(senderPlayerID:Int, block:TNews, slot:int=0)
		local obj:TNetworkObject = TNetworkObject.Create( NET_PLAN_SETNEWS )

		obj.setInt(1, senderPlayerID)
		obj.setInt(2, block.id)
		obj.setInt(3, block.owner)
		obj.setInt(4, slot)
		Network.BroadcastNetworkObject( obj, NET_PACKET_RELIABLE )

		print "[NET] SendPlanSetNews: senderPlayer="+senderPlayerID+", blockowner="+block.owner+", block="+block.id+" slot="+slot
	End Method

	Method ReceivePlanSetNews:int( obj:TNetworkObject )
		local sendingPlayerID:int = obj.getInt(1)

		if not GetPlayerCollection().IsPlayer(sendingPlayerID) then return NULL

		local blockID:int = obj.getInt(2)
		local blockOwnerID:int = obj.getInt(3)
		local slot:int = obj.getInt(4)
		local owningPlayer:TPlayer = GetPlayerCollection().Get(blockOwnerID)
		if not owningPlayer then return Null

		Local news:TNews = owningPlayer.GetProgrammeCollection().getNews(blockID)
		'do not automagically create new blocks for others...
		'all do it independently from each other (for intact randomizer base )
		if not news then return TRUE

		'deactivate events for that moment - avoid recursion
		TPlayerProgrammePlan.fireEvents = FALSE

		owningPlayer.GetProgrammePlan().SetNews(news, slot)

		TPlayerProgrammePlan.fireEvents = TRUE

		print "[NET] ReceivePlanSetNewsSlot: sendingPlayer="+sendingPlayerID+", blockowner="+blockOwnerID+", block="+news.id+" slot="+slot
	End Method



'checked
	Method SendProgrammePlanChange(playerID:Int, broadcastObject:TBroadcastMaterial, slotType:int=0, day:int, hour:int)
		local obj:TNetworkObject = TNetworkObject.Create(NET_PROGRAMMEPLAN_CHANGE)
		obj.setInt(1, playerID)
		if obj
			obj.setInt(2, broadcastObject.materialType)
			obj.setInt(3, broadcastObject.id) 'not really used atm
			obj.setInt(4, broadcastObject.GetReferenceID())
		else
			obj.setInt(2, 0)
			obj.setInt(3, 0)
			obj.setInt(4, 0)
		endif
		obj.setInt(5, slotType)
		obj.setInt(6, day)
		obj.setInt(7, hour)
		Network.BroadcastNetworkObject(obj, NET_PACKET_RELIABLE)
	End Method

	Method ReceiveProgrammePlanChange:int( obj:TNetworkObject )
		if not GetPlayerCollection().IsPlayer(obj.getInt(1)) then return FALSE

		local playerID:int		= obj.getInt(1)
		local objectType:int	= obj.getInt(2)
		local objectID:int		= obj.getInt(3)
		local referenceID:int	= obj.getInt(4)
		local slotType:int		= obj.getInt(5)
		local day:int			= obj.getInt(6)
		local hour:int			= obj.getInt(7)

		'delete at given spot
		if objectID = 0 then return (null<> GetPlayerProgrammePlanCollection().Get(playerID).RemoveObject(null, slotType, day, hour))

		'add to given datetime
		local broadcastMaterial:TBroadcastMaterial
		Select objectType
			case TBroadcastmaterial.TYPE_PROGRAMME
				broadcastMaterial = TProgramme.Create(GetPlayerProgrammeCollectionCollection().Get(playerID).GetProgrammeLicence(referenceID))
			case TBroadcastmaterial.TYPE_ADVERTISEMENT
				broadcastMaterial = new TAdvertisement.Create(GetPlayerProgrammeCollectionCollection().Get(playerID).GetAdContract(referenceID))
		End Select
		If not broadcastMaterial
			print "[NET] ReceiveProgrammePlanChange: object "+objectID+" with reference "+referenceID+" not found."
			return FALSE
		endif

		GetPlayerProgrammePlanCollection().Get(playerID).AddObject(broadcastMaterial, slotType, day, hour)
	End Method
End Type
Global NetworkHelper:TNetworkHelper = new TNetworkHelper.Create()