-- Executes actual project methods with small stand-ins for native Entity/RPC boundaries.
local assertions = 0
local function check(ok, message)
    assertions = assertions + 1
    assert(ok, message)
end

local function approveAI(co,target)
    local generation=co._T.DisconnectGeneration[target]
    for seat=1,co.RequiredPlayerCount do
        local player=co.playerEntityBySeat[seat]
        if player~=nil and isvalid(player) and not co._T.AIBySeat[seat] then
            check(co:VoteDisconnectedSeat(co.userIdBySeat[seat],player,target,generation,true).ok,'AI continuation vote accepted')
            if co._T.AIBySeat[target] then break end
        end
    end
    check(co._T.AIBySeat[target] and not co._T.KickedBySeat[target],'approved AI preserves reconnect rights')
end

local function fixture(n)
    local session = LexioGameSession.new()
    local coordinator = LexioSessionCoordinator.new()
    local registry = LexioTableRegistry.new()
    local map = {Name='map01'}
    local host = {GetComponent=function(self,name) if name=='script.LexioTableRegistry' then return registry end end}
    map.GetChildByName=function(self,name) if name=='LexioManualSessionHost' then return host end end
    local entity = {CurrentMap=map, CurrentMapName='map01'}
    entity.GetComponent=function(self,name)
        if name=='script.LexioGameSession' then return session end
        if name=='script.LexioSessionCoordinator' then return coordinator end
    end
    coordinator.Entity=entity; coordinator.TableId='table01'; coordinator.RequiredPlayerCount=n
    coordinator:OnBeginPlay()
    registry.GetTableCoordinator=function() return coordinator end
    local users={}
    for seat=1,n do
        local id='player'..seat
        users[seat]=id
        local player={CurrentMap=map,PlayerComponent={UserId=id},Name='Player '..seat,NameTagComponent={Name='Nickname '..seat}}
        player.GetComponent=function() return nil end
        coordinator.userIdBySeat[seat]=id
        coordinator.seatByUserId[id]=seat
        coordinator.playerEntityBySeat[seat]=player
        coordinator.readyBySeat[seat]=true
        coordinator.explicitReadyBySeat[seat]=true
        coordinator.seatedBySeat[seat]=true
        coordinator.chairBySeat[seat]='chair'..seat
        local key=registry:MakeSeatKey('table01',seat)
        registry.seatOwnerByKey[key]=id
        registry.seatByUserId[id]={tableId='table01',seatIndex=seat,key=key}
        registry.playerByUserId[id]=player
    end
    check(session:StartGame(users,nil).ok,'start '..n..'p')
    coordinator.startRequested=true
    return session,coordinator,registry,map
end

for n=3,5 do
    local session,c,registry=fixture(n)
    for seat=1,n do check(#session.hands[seat]==12,'all modes deal twelve') end
    local v=session.stateVersion
    c:UpdateTurnClock(0)
    check(c._T.TurnSecondsRemaining==15,'turn starts at 15')
    c:UpdateTurnClock(14)
    check(c._T.TurnSecondsRemaining==1 and session.stateVersion==v,'no early timeout')
    c:UpdateTurnClock(1)
    check(session.stateVersion==v+1,'timeout commits one action')
    c:UpdateTurnClock(0)
    check(c._T.TurnSecondsRemaining==15,'next turn gets 15')
    local turns=0
    while session.phase~='Finished' and turns<1500 do
        c:UpdateTurnClock(0)
        c:UpdateTurnClock(15)
        turns=turns+1
    end
    check(session.phase=='Finished','all-timeout game completes '..n..'p')
    local total=0; local scores={}
    for seat=1,n do scores[seat]=session.scoreLedger[seat];total=total+scores[seat] end
    check(total==64*n,'settlement is zero sum '..n..'p')
    local vote=c:SubmitFinishDecision('player1',c.playerEntityBySeat[1],'Replay',c.finishGeneration)
    check(vote.ok,'replay vote accepted')
    local snap=c:BuildClientPublicSnapshot()
    check(snap.finishReplayBySeat[1] and snap.finishReplayCount==1,'per-seat replay flag')
    local duplicate=c:SubmitFinishDecision('player1',c.playerEntityBySeat[1],'Replay',c.finishGeneration)
    check(duplicate.ok and c:BuildClientPublicSnapshot().finishReplayCount==1,'duplicate vote does not double count')
    for seat=2,n do check(c:SubmitFinishDecision('player'..seat,c.playerEntityBySeat[seat],'Replay',c.finishGeneration).ok,'unanimous replay') end
    check(session.phase=='Playing','unanimous replay starts')
    for seat=1,n do check(session.scoreLedger[seat]==scores[seat],'carry score '..seat) end
    -- Complete a second full round using only the production timer path.
    turns=0
    while session.phase~='Finished' and turns<1500 do c:UpdateTurnClock(0);c:UpdateTurnClock(15);turns=turns+1 end
    check(session.phase=='Finished','second round completes '..n..'p')
    total=0
    for seat=1,n do check(session.scoreLedger[seat]==scores[seat]+session.scoreDeltas[seat],'second settlement adds delta');total=total+session.scoreLedger[seat] end
    check(total==64*n,'second round conserves total')
    -- Final result return must release a disconnected occupant, not leave a blocked table.
    for seat=1,n do c.playerEntityBySeat[seat].valid=false end
    c:ReturnAllFinishedPlayers('test_disconnected')
    check(next(c.seatByUserId)==nil and next(registry.seatByUserId)==nil,'disconnected result seats released')
    check(session.phase=='WaitingPlayers' and not c.startRequested,'finished table reusable')
end

do
    local session,c,registry=fixture(3)
    c.playerEntityBySeat[1].valid=false
    c:RecycleAbandonedGame()
    check(session.phase=='Playing','one disconnect does not abort remaining players')
    c.playerEntityBySeat[2].valid=false;c.playerEntityBySeat[3].valid=false
    c:RecycleAbandonedGame()
    check(session.phase=='WaitingPlayers' and next(registry.seatByUserId)==nil,'all players gone releases active table')
    check(next(session.scoreDeltas)==nil,'abandoned game awards no fabricated result')
end

do
    local session,c,registry,map=fixture(3)
    local room={code='L001',title='Test room',capacity=3,password='',tableId='table01',userIds={'player1'},seatByUserId={player1=1},readyByUserId={}}
    registry.privateRoomByCode.L001=room
    local visitor={CurrentMap=map,PlayerComponent={UserId='visitor'}}
    check(registry:ListPrivateRooms()[1].phase=='Playing' and not registry:ListPrivateRooms()[1].canJoin,'playing room stays visible, locked')
    check(registry:JoinPrivateRoom('visitor',visitor,'L001','').reason=='room_in_progress','server denies active room')
    session.phase='Finished'
    check(registry:ListPrivateRooms()[1].phase=='Finished','result room status')
    session:ResetSession();c.startRequested=false;c.startCountdownActive=true
    check(registry:ListPrivateRooms()[1].phase=='Countdown' and not registry:ListPrivateRooms()[1].canJoin,'countdown room locked')
    c.startCountdownActive=false
    check(registry:ListPrivateRooms()[1].canJoin,'waiting room available')
    room.userIds={'player1','player2','player3'}
    check(not registry:ListPrivateRooms()[1].canJoin,'full room locked')
end
do
    local registry=LexioTableRegistry.new()
    registry.queueUserIds={'waiting'}
    local attempts=0
    registry.TryMatchQueue=function() attempts=attempts+1 end
    registry:OnUpdate(0.9)
    check(attempts==0,'retry throttled')
    registry:OnUpdate(0.1)
    check(attempts==1,'waiting queue retries without a new join')
    registry.queueUserIds={}
    registry:OnUpdate(10)
    check(attempts==1,'empty queue performs no work')
end

do
    local controller=LexioPlayUIController.new()
    local nodes={}
    local function node(p)
        if nodes[p]==nil then
            nodes[p]={Enable=false,UITransformComponent={},TextGUIRendererComponent={},TextGUIRendererInputComponent={Text='',ActivateInputField=function(self) self.focused=true end}}
        end
        return nodes[p]
    end
    local base='/ui/LexioPrivateRoom/Browser/'
    controller.PrivateErrorText=node(base..'ErrorText')
    controller.PrivateTitleInput=node(base..'RoomTitleInput')
    controller.PrivatePasswordInput=node(base..'PasswordInput')
    _EntityService={GetEntityByPath=function(self,p) return node(p) end}
    _UILogic={SetSiblingIndex=function() end}
    _UserService={LocalPlayer=nil}
    controller:OpenJoinRoomPopup(' l001 ')
    check(controller._T.JoinPopupCode=='L001','invite code normalized')
    check(node(base..'PasswordInput').Enable and node(base..'PasswordInput').TextGUIRendererInputComponent.focused,'join password visible and focused')
    check(not node(base..'RoomTitleInput').Enable and not node(base..'Capacity3').Enable,'creation fields hidden for join')
    check(node(base..'CreateButton').TextGUIRendererComponent.Text=='입장','join button label')
    controller:SetCreatePopupVisible(false)
    check(controller._T.JoinPopupCode==nil and not node(base..'PasswordInput').Enable,'cancel clears join mode')
    controller:SetCreatePopupVisible(true)
    check(node(base..'RoomTitleInput').Enable and node(base..'Capacity3').Enable,'create form restored after joining')
    check(node(base..'CreatePopupTitle').TextGUIRendererComponent.Text=='방 만들기','create title restored')
    Environment={IsMakerPlay=function() return false end}
    controller:ToggleGamePreview()
    check(controller._T.PreviewActive~=true,'published game cannot open debug preview')
end
for n=3,5 do
    local session,c,registry,map=fixture(n)
    session.currentPlayerIndex=1
    local oldPlayer=c.playerEntityBySeat[1]
    oldPlayer.valid=false
    c:MarkDisconnected('player1')
    local generation=c._T.DisconnectGeneration[1]
    local version=session.stateVersion
    c:UpdateTurnClock(0)
    c:UpdateConnections(29)
    c:UpdateTurnClock(15)
    check(not c._T.AIBySeat[1] and session.stateVersion==version,'disconnect grace freezes the missing turn '..n)
    approveAI(c,1)
    check(c._T.AIBySeat[1] and not session.persistentRewardsEligible,'AI takeover at thirty seconds '..n)
    c:UpdateTurnClock(0)
    c:UpdateTurnClock(1.5)
    check(session.stateVersion==version+1 and #session.hands[1]==11,'AI commits legal action '..n)
    local handBefore=session:BuildPrivateHandSnapshot('player1')
    local replacement={CurrentMap=map,PlayerComponent={UserId='player1'},NameTagComponent={Name='returned'},GetComponent=function() return nil end}
    c.AttachBridge=function(self,player,id,seat,role)
        self.bridgeByUserId[id]={Entity=player,PushCurrentSnapshot=function() end}
        return self.bridgeByUserId[id]
    end
    check(not registry:ReconnectPlayer('player2',replacement),'reconnect identity verified')
    check(registry:ReconnectPlayer('player1',replacement),'same account restores seat '..n)
    check(c.playerEntityBySeat[1]==replacement and c._T.DisconnectedSeconds[1]==nil and not c._T.AIBySeat[1],'reconnect removes AI control')
    check(#session.hands[1]==#handBefore and session.hands[1][1].id==handBefore[1].id,'reconnect preserves owned hand')
    check(c._T.DisconnectGeneration[1]>generation,'reconnect invalidates old votes')
end

for n=3,5 do
    local session,c,registry,map=fixture(n)
    local target='player'..n
    local room={code='L001',title='Private',capacity=n,password='',tableId='table01',userIds={},seatByUserId={},readyByUserId={}}
    c.privateRoomCode='L001'
    registry.privateRoomByCode.L001=room
    registry.privateRoomCodeByTableId.table01='L001'
    for seat=1,n do local id='player'..seat;room.userIds[seat]=id;room.seatByUserId[id]=seat;registry.privateRoomCodeByUserId[id]='L001' end
    c.playerEntityBySeat[n].valid=false
    c:MarkDisconnected(target)
    local generation=c._T.DisconnectGeneration[n]
    check(not c:VoteDisconnectedSeat('player1',c.playerEntityBySeat[1],n,generation-1).ok,'reject stale disconnect vote')
    c:UpdateConnections(1)
    check(not c._T.AIBySeat[n] and not c._T.KickedBySeat[n],'private room awaits continuation vote')
    check(not c:VoteDisconnectedSeat('player1',c.playerEntityBySeat[1],n,generation-1).ok,'stale disconnect vote rejected')
    local required=math.floor((n-1)/2)+1
    check(c:GetDisconnectVoteThreshold(n)==required,'majority of other connected players')
    check(c:VoteDisconnectedSeat('player1',c.playerEntityBySeat[1],n,generation).ok,'first vote accepted')
    check(c:VoteDisconnectedSeat('player1',c.playerEntityBySeat[1],n,generation).ok and not c._T.KickedBySeat[n],'duplicate vote cannot pass threshold')
    for seat=2,required do check(c:VoteDisconnectedSeat('player'..seat,c.playerEntityBySeat[seat],n,generation).ok,'additional vote') end
    check(c._T.AIBySeat[n] and not c._T.KickedBySeat[n] and registry.seatByUserId[target]~=nil,'vote keeps disconnected player seat reserved')
    -- The following cleanup assertions cover a separate voluntary permanent departure.
    c._T.KickedBySeat[n]=true;registry:DetachReplacedPlayer(target,'table01',n)
    check(registry.seatByUserId[target]==nil and registry.privateRoomCodeByUserId[target]==nil,'kicked account released from room')
    local aiKey=registry:MakeSeatKey('table01',n)
    check(registry.seatOwnerByKey[aiKey]=='AI:'..target,'AI keeps seat reserved for current match')
    local returner={CurrentMap=map,PlayerComponent={UserId=target},GetComponent=function() return nil end}
    check(not registry:ReconnectPlayer(target,returner),'removed account cannot retake AI seat')
    -- This account can now enter another room; old-round cleanup must not remove that new seat.
    registry.seatByUserId[target]={tableId='table02',seatIndex=1,key='new-room-seat'}
    registry.seatOwnerByKey['new-room-seat']=target
    registry.playerByUserId[target]=returner
    session.phase='Finished'
    for seat=1,n-1 do c.playerEntityBySeat[seat].valid=false end
    c:ReturnAllFinishedPlayers('cleanup_test')
    check(registry.seatByUserId[target]~=nil and registry.seatByUserId[target].tableId=='table02','old cleanup preserves different room ownership')
    check(registry.seatOwnerByKey[aiKey]==nil,'retired AI reservation removed')
end
do
    local session,c,registry=fixture(3)
    c.playerEntityBySeat[1].valid=false
    c:MarkDisconnected('player1');approveAI(c,1)
    local turns=0
    while session.phase~='Finished' and turns<1500 do c:UpdateTurnClock(0);c:UpdateTurnClock(15);turns=turns+1 end
    check(session.phase=='Finished','game with AI can finish')
    local balance=session.scoreLedger[1]
    check(not c:SubmitFinishDecision('player2',c.playerEntityBySeat[2],'Replay',c.finishGeneration).ok,'replay rejected when AI remains at finish')
    check(session.phase=='Finished','one human vote is insufficient')
    check(not c:SubmitFinishDecision('player3',c.playerEntityBySeat[3],'Replay',c.finishGeneration).ok,'all human votes cannot override AI-at-finish policy')
    c:StartReplayRound()
    check(session.phase=='Finished' and session.scoreLedger[1]==balance,'AI round cannot restart or alter final score')
end

do
    Vector2=function(x,y) return {x=x,y=y} end
    Color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end
    local ui=LexioPlayUIController.new()
    ui._T.AvatarUserBySeat={}
    ui.GetLocalBridge=function() return {_T={Seat=1}} end
    ui.RenderScoreWallet=function() end
    ui.SortPanel={UITransformComponent={}}
    ui.ActionPanel={UITransformComponent={}}
    local panels={};local badges={}
    for seat=1,5 do
        local badge={UITransformComponent={},TextGUIRendererComponent={},SpriteGUIRendererComponent={},ButtonComponent={}}
        badges[seat]=badge
        local panel={UITransformComponent={anchoredPosition={x=0,y=0},RectSize={x=100,y=100}},SpriteGUIRendererComponent={}}
        panel.GetChildByName=function(self,name) if name=='StatusBadge' then return badge end end
        panels[seat]=panel
        ui['Seat'..seat..'Panel']=panel
        ui['Seat'..seat..'Text']={UITransformComponent={},TextGUIRendererComponent={}}
    end
    for n=3,5 do
        local snapshot={playerCount=n,phase='Playing',currentPlayerIndex=1,privateRoomCode='L001',disconnectedSeconds={-1,29,30},disconnectVoteCounts={0,0,1},disconnectVoteThresholds={2,2,2},aiBySeat={},passed={}}
        ui:RenderSeats(snapshot)
        check(badges[1].TextGUIRendererComponent.Text=='MY TURN!','normal turn badge retained '..n)
        check(badges[2].TextGUIRendererComponent.Text=='대행 투표 0/2' and badges[2].ButtonComponent.Enable,'immediate vote label '..n)
        check(badges[3].TextGUIRendererComponent.Text=='대행 투표 1/2' and badges[3].ButtonComponent.Enable,'private vote badge clickable '..n)
        snapshot.aiBySeat[3]=true
        snapshot.kickedBySeat={false,false,true}
        ui:RenderSeats(snapshot)
        check(badges[3].TextGUIRendererComponent.Text=='AI 진행 중' and not badges[3].ButtonComponent.Enable,'AI badge disables voting '..n)
    end
end
log('[OFFLINE] Beta scenarios passed assertions='..assertions)

-- Logical leave keeps the live client available for reconnect or a targeted kick notification.
for n=3,5 do
    local session,c,registry,map=fixture(n)
    session.currentPlayerIndex=1
    c:UpdateTurnClock(0); c:UpdateTurnClock(4)
    local remaining=c._T.TurnCountdown
    local version=session.stateVersion
    local target=n
    local player=c.playerEntityBySeat[target]
    local controls=LexioManualTestControls.new(); controls.Entity=player
    player.GetComponent=function(self,name) if name=='script.LexioManualTestControls' then return controls end end
    senderUserId='player'..target
    controls:RequestSuspendGame()
    check(controls._T.ReconnectOnly==true and not controls:IsSeated(),'leave opens reconnect-only screen '..n)
    check(c.playerEntityBySeat[target]==nil and registry.seatByUserId[senderUserId]~=nil,'leave reserves owned seat '..n)
    c:UpdateTurnClock(15)
    check(session.stateVersion==version and c._T.TurnCountdown==remaining,'other player turn pauses without losing seconds '..n)
    check(c:BuildClientPublicSnapshot().connectionPaused,'snapshot publishes pause '..n)
    local resumeCalls=0
    controls.RequestResumeGame=function() resumeCalls=resumeCalls+1 end
    _UserService={LocalPlayer=player}
    controls:OnUpdate(5)
    check(resumeCalls==0,'suspended client never auto-resumes '..n)
    c.AttachBridge=function(self,p,id,seat,role) self.bridgeByUserId[id]={Entity=p,PushCurrentSnapshot=function() end} end
    _LexioPlayUIController={SetStaticLobbyOpen=function() end}
    local hand=session.hands[target]
    check(registry:ReconnectPlayer(senderUserId,player),'manual reconnect accepted '..n)
    check(not controls._T.ReconnectOnly and controls:IsSeated() and session.hands[target]==hand,'reconnect restores same hand and screen '..n)
    check(c._T.TurnCountdown==remaining and not c:HasPendingDisconnect(),'reconnect preserves paused time '..n)
    c:UpdateTurnClock(1)
    check(c._T.TurnCountdown==remaining-1,'resumed clock continues '..n)
    -- A successful vote notifies the still-connected suspended client and revokes its seat.
    c.privateRoomCode='L002'
    controls:RequestSuspendGame()
    c:UpdateConnections(1)
    local routed=false
    controls.ShowFinishedLobby=function(self,recipient) routed=recipient==senderUserId; self._T.ReconnectOnly=false end
    local generation=c._T.DisconnectGeneration[target]
    for seat=1,math.floor((n-1)/2)+1 do
        check(c:VoteDisconnectedSeat('player'..seat,c.playerEntityBySeat[seat],target,generation).ok,'vote accepted '..n)
    end
    check(not routed and controls._T.ReconnectOnly,'approval does not close reconnect screen '..n)
    controls:RequestAbandonGame()
    check(routed and not controls._T.ReconnectOnly,'voluntary departure routes target to public lobby '..n)
    check(registry.seatByUserId[senderUserId]==nil and not registry:ReconnectPlayer(senderUserId,player),'kick rejects later reconnect '..n)
end
for n=3,5 do
    local session,c,registry,map=fixture(n)
    local controls=LexioManualTestControls.new();controls.Entity=c.playerEntityBySeat[1]
    local returned=0;controls.ShowFinishedLobby=function() returned=returned+1 end
    registry.ReconnectPlayer=function() return false end
    senderUserId='player1'
    controls:RequestResumeGame(false)
    check(returned==0,'background reconnect failure does not force lobby')
    controls:RequestResumeGame(true)
    check(returned==1,'unavailable explicit reconnect returns to lobby')
end
log('[OFFLINE] Connection flow scenarios passed total assertions='..assertions)

for n=3,5 do
    local session,c,registry,map=fixture(n)
    check(registry:ReconnectPlayer('player1',c.playerEntityBySeat[1]),'duplicate reconnect remains accepted '..n)
end
for n=3,5 do
    local controller=LexioPlayUIController.new()
    local controls=LexioManualTestControls.new(); controls._T.IsSeated=true
    local snapshot={phase='Playing',playerCount=n,privateRoomCode='L001',seatNames={},disconnectedSeconds={},aiBySeat={},disconnectGenerations={},disconnectVoteCounts={},disconnectVoteThresholds={}}
    for seat=1,n do snapshot.seatNames[seat]='Player '..seat;snapshot.disconnectedSeconds[seat]=-1;snapshot.disconnectGenerations[seat]=1;snapshot.disconnectVoteCounts[seat]=0;snapshot.disconnectVoteThresholds[seat]=1 end
    snapshot.disconnectedSeconds[n]=30
    local bridge={_T={Seat=1},GetMatchedPublicSnapshot=function() return snapshot end}
    controller.GetLocalBridge=function() return bridge end
    local nodes={}
    local function node(p)
        nodes[p]=nodes[p] or {Enable=false,TextGUIRendererComponent={}}
        nodes[p].GetChildByName=function(self,name) return node(p..'/'..name) end
        return nodes[p]
    end
    _EntityService={GetEntityByPath=function(self,p) return node(p) end}
    _UserService={LocalPlayer={GetComponent=function() return controls end}}
    controller.ContentRoot={Enable=true}
    check(not controller:UpdateConnectionScreens(),'normal game stays active '..n)
    check(node('/ui/LexioPlayHUD/VotePopup').Enable,'vote popup automatically visible '..n)
    controller._T.DisconnectVoteOpen=false
    controller:UpdateConnectionScreens()
    check(not node('/ui/LexioPlayHUD/VotePopup').Enable,'dismissed vote stays dismissed '..n)
    snapshot.disconnectedSeconds[n]=-1
    controller._T.DisconnectVoteOpen=true
    controller:UpdateConnectionScreens()
    check(not node('/ui/LexioPlayHUD/VotePopup').Enable,'reconnect closes vote popup '..n)
    controls._T.ReconnectOnly=true
    check(controller:UpdateConnectionScreens(),'suspended UI exits normal rendering '..n)
    check(node('/ui/LexioPlayHUD/ReconnectScreen').Enable and not controller.ContentRoot.Enable,'reconnect screen hides cards '..n)
end
log('[OFFLINE] Connection UI assertions passed total='..assertions)

do
    local controller=LexioPlayUIController.new()
    controller._T.PrivateEventConnections={}
    controller._T.EventConnections={}
    local nodes={}
    local function node(p)
        if not nodes[p] then
            nodes[p]={Enable=true,TextGUIRendererComponent={},TextGUIRendererInputComponent={Text='선택 테스트'}}
            nodes[p].ConnectEvent=function(self,event,callback) self.click=callback;return callback end
        end
        return nodes[p]
    end
    local chosen=nil
    local controls={RefreshPrivateRooms=function() end,CreatePrivateRoom=function(self,title,capacity,password) chosen=capacity end}
    _UserService={LocalPlayer={GetComponent=function() return controls end}}
    local base='/ui/LexioPrivateRoom/Browser/'
    _EntityService={GetEntityByPath=function(self,p) if p:find('/ReconnectScreen/') or p:find('/VotePopup/') then return nil end return node(p) end}
    controller.PrivateReadyButton=node('/ready');controller.PrivateLeaveButton=node('/leave')
    controller.PrivateTitleInput=node(base..'RoomTitleInput');controller.PrivatePasswordInput=node(base..'PasswordInput');controller.PrivateCodeInput=node(base..'InviteCodeInput');controller.PrivateErrorText=node(base..'ErrorText')
    controller:ConnectPrivateRoomButtons()
    for capacity=3,5 do
        node(base..'Capacity'..capacity).click({})
        node(base..'CreateButton').click({})
        check(chosen==capacity,'capacity selection reaches create request '..capacity)
    end
    controller:ConnectConnectionButtons()
    check(#controller._T.EventConnections==4,'missing overlay does not block existing leave binding')
    controller:ConnectConnectionButtons()
    check(#controller._T.EventConnections==4,'optional binding retry has no duplicate handlers')
    _EntityService.GetEntityByPath=function(self,p) return node(p) end
    controller:ConnectConnectionButtons()
    check(#controller._T.EventConnections==8,'late overlay buttons bind when available')
end
log('[OFFLINE] Room capacity regression passed total='..assertions)

for n=3,5 do
    for _,private in ipairs({false,true}) do
        local session,c,registry,map=fixture(n)
        c.privateRoomCode=private and 'L009' or ''
        local player=c.playerEntityBySeat[n]
        local controls=LexioManualTestControls.new(); controls.Entity=player
        player.GetComponent=function(self,name) if name=='script.LexioManualTestControls' then return controls end end
        senderUserId='player'..n
        controls:RequestSuspendGame()
        local generation=c._T.DisconnectGeneration[n]
        check(c:VoteDisconnectedSeat('player1',c.playerEntityBySeat[1],n,generation).ok,'vote accepted immediately in both room types '..n)
        local routed=false;controls.ShowFinishedLobby=function(self,id) routed=id==senderUserId end
        controls:RequestAbandonGame()
        check(routed and c._T.KickedBySeat[n] and c._T.AIBySeat[n],'voluntary lobby leave replaces seat '..n)
        check(registry.seatByUserId[senderUserId]==nil and not registry:ReconnectPlayer(senderUserId,player),'voluntary leave revokes reconnect '..n)
    end
end
do
    local ui=LexioPlayUIController.new()
    ui._T.UIReady=true
    local checks=0
    ui.ConnectConnectionButtons=function() end
    ui.UpdateConnectionScreens=function() checks=checks+1; return true end
    ui.UpdateMapActivation=function() error('suspended client entered game render') end
    ui.UpdatePrivateRoomUI=function() error('suspended client entered lobby render') end
    for frame=1,120 do ui:OnUpdate(1/60) end
    check(checks==120,'suspended frames stop before game/lobby activation')
end
log('[OFFLINE] Immediate vote and voluntary exit passed total='..assertions)

for n=3,5 do
    local controls=LexioManualTestControls.new()
    local bridge={_T={MatchedPublicSnapshot={phase='WaitingPlayers'},MatchedPrivateHand={}}}
    controls.Entity={GetComponent=function(self,name) if name=='script.LexioPlayerBridge' then return bridge end end}
    controls.IsInLexioGameRoom=function() return true end
    controls._T.IsSeated=true;controls._T.SeatChairName='old';controls._T.PrivateRoomSnapshot={code='old'}
    local created=0
    controls.RequestCreatePrivateRoom=function(self,title,capacity,password) check(capacity==n,'new room capacity preserved');created=created+1 end
    controls:ApplyPrivateRoomResult(false,'leave_rejected',nil)
    check(controls:IsSeated(),'rejected leave preserves room membership')
    controls:ApplyPrivateRoomResult(true,'',nil)
    check(not controls:IsSeated() and controls._T.SeatChairName=='' and controls._T.PrivateRoomSnapshot==nil,'waiting-room leave clears client membership '..n)
    check(bridge._T.MatchedPublicSnapshot==nil and bridge._T.MatchedPrivateHand==nil,'waiting-room leave drops old game snapshots '..n)
    controls:CreatePrivateRoom('새 방',n,'')
    check(created==1 and controls._T.PrivateRoomError=='creating','create after leave reaches server '..n)
end
log('[OFFLINE] Leave/recreate regression passed total='..assertions)

local function tileList(spec,prefix)
    local result={}
    for i,pair in ipairs(spec) do result[i]={id=prefix..i,rank=pair[1],suit=pair[2]} end
    return result
end
local aiCases={
    {previous={{5,1}},hand={{3,1},{5,2},{6,1}},count=1,rank=5},
    {previous={{4,1},{4,2}},hand={{5,1},{5,2},{6,1},{6,2}},count=2,rank=5},
    {previous={{4,1},{4,2},{4,3}},hand={{5,1},{5,2},{5,3},{6,1},{6,2},{6,3}},count=3,rank=5},
    {previous={{3,1},{3,2},{3,3},{4,1},{4,2}},hand={{5,1},{5,2},{5,3},{6,1},{6,2},{8,4}},count=5},
    {previous={{4,1},{4,2},{4,3},{4,4},{3,1}},hand={{5,1},{5,2},{5,3},{5,4},{3,1},{7,2}},count=5},
    {previous={{3,1},{4,2},{5,3},{6,4},{7,1}},hand={{4,1},{5,2},{6,3},{7,4},{8,1},{9,2}},count=5}
}
for n=3,5 do
    for index,case in ipairs(aiCases) do
        local session,c=fixture(n)
        local hand=tileList(case.hand,'ai')
        session.hands[1]=hand;session.currentPlayerIndex=1;session.winningPlayerIndex=2;session.phase='Playing';session.passed={}
        session.currentPlay=_LexioRules:ClassifyPlay(tileList(case.previous,'prev'),n)
        c._T.AIBySeat[1]=true
        local ids=c:FindAIPlay(1)
        check(ids~=nil and #ids==case.count,'AI finds legal response '..n..'/'..index)
        local selected=session:ResolveOwnedTiles(1,ids)
        check(_LexioRules:CanSubmit(selected,n,session.currentPlay,false),'AI response beats prior play '..n..'/'..index)
        if case.rank then check(selected[1].rank==case.rank,'AI saves stronger cards '..index) end
        local version=session.stateVersion;local before=#hand
        c:UpdateTurnClock(0);c:UpdateTurnClock(1.5)
        check(session.stateVersion==version+1 and #session.hands[1]==before-case.count,'AI timer commits submission '..n..'/'..index)
    end
    local session,c=fixture(n)
    session.hands[1]=tileList({{3,1},{4,1}},'low');session.currentPlayerIndex=1;session.winningPlayerIndex=2;session.phase='Playing';session.passed={}
    session.currentPlay=_LexioRules:ClassifyPlay(tileList({{2,4}},'max'),n);c._T.AIBySeat[1]=true
    check(c:FindAIPlay(1)==nil,'AI has no stronger card '..n)
    c:UpdateTurnClock(0);c:UpdateTurnClock(1.5)
    check(session.passed[1] and #session.hands[1]==2,'AI passes only when unable to respond '..n)
end
for n=3,5 do
    local session,c,registry,map=fixture(n)
    c.privateRoomCode='L000'
    local room={code='L000',tableId='table01',capacity=n,title='old',password='',ownerUserId='player1',userIds={},seatByUserId={},readyByUserId={}}
    registry.privateRoomByCode.L000=room;registry.privateRoomCodeByTableId.table01='L000'
    local oldPlayers={}
    for seat=1,n do
        local id='player'..seat
        oldPlayers[seat]=c.playerEntityBySeat[seat]
        room.userIds[seat]=id;room.seatByUserId[id]=seat;registry.privateRoomCodeByUserId[id]='L000'
    end
    for seat=1,n do
        local id='player'..seat
        c:MarkDisconnected(id);c._T.KickedBySeat[seat]=true;c:EnableSeatAI(seat,'test_leave')
        registry:DetachReplacedPlayer(id,'table01',seat)
        if seat<n then check(registry.privateRoomByCode.L000~=nil,'room stays while people remain '..n) end
    end
    check(registry.privateRoomByCode.L000==nil and #registry:ListPrivateRooms()==0,'zero-person room disappears '..n)
    check(registry:IsTableEmpty('table01') and session.phase=='WaitingPlayers' and not c.startRequested,'empty table reusable '..n)
    check(next(c._T.AIBySeat)==nil and next(c.seatByUserId)==nil,'AI and old seat ownership cleared '..n)
    registry.GetTableIdForCapacity=function() return 'table01' end
    c.AttachBridge=function() end
    check(registry:CreatePrivateRoom('player1',oldPlayers[1],'new',n,'').ok,'same capacity room can be created again '..n)
end
log('[OFFLINE] AI responses and empty-room cleanup passed total='..assertions)

local function roomSettingsFixture(n)
    local session,source,registry,map=fixture(n)
    registry.GetTableIdForCapacity=function(self,size) return size==3 and "table01" or (size==4 and "table02" or (size==5 and "table03" or "")) end
    session:ResetSession();source.startRequested=false
    for seat=3,n do registry:ReleasePlayer('player'..seat,'fixture') end
    local initialId=registry:GetTableIdForCapacity(n)
    source.TableId=initialId
    for seat=1,2 do
        local id='player'..seat;local old=registry.seatByUserId[id]
        registry.seatOwnerByKey[old.key]=nil
        old.tableId=initialId;old.key=registry:MakeSeatKey(initialId,seat)
        registry.seatOwnerByKey[old.key]=id
    end
    local coordinators={[initialId]=source}
    for capacity=3,5 do
        local id=registry:GetTableIdForCapacity(capacity)
        if not coordinators[id] then
            local game=LexioGameSession.new();local co=LexioSessionCoordinator.new()
            co.TableId=id;co.RequiredPlayerCount=capacity
            local entity={CurrentMap=map,CurrentMapName='map01'}
            entity.GetComponent=function(self,name) if name=='script.LexioGameSession' then return game end end
            co.Entity=entity;co:OnBeginPlay();coordinators[id]=co
        end
        coordinators[id].AttachBridge=function() end
    end
    registry.GetTableCoordinator=function(self,id) return coordinators[id] end
    local room={code='L777',tableId=initialId,capacity=n,title='same room',password='',ownerUserId='player1',userIds={'player1','player2'},seatByUserId={player1=1,player2=2},readyByUserId={player1=true,player2=true}}
    registry.privateRoomByCode.L777=room;registry.privateRoomCodeByTableId[initialId]='L777'
    registry.privateRoomCodeByUserId.player1='L777';registry.privateRoomCodeByUserId.player2='L777'
    source.privateRoomCode='L777';source.explicitReadyRequired=true
    return registry,room,coordinators,map
end
for n=3,5 do
    local registry,room,coordinators=roomSettingsFixture(n)
    local owner=registry.playerByUserId.player1
    local guest=registry.playerByUserId.player2
    check(not registry:UpdatePrivateRoomSettings('player2',guest,n,true,'secret').ok,'guest cannot edit room '..n)
    check(not registry:UpdatePrivateRoomSettings('player1',guest,n,true,'secret').ok,'forged owner entity rejected '..n)
    check(not registry:UpdatePrivateRoomSettings('player1',owner,n,true,'').ok,'new locked room requires password '..n)
    check(registry:UpdatePrivateRoomSettings('player1',owner,n,true,'secret').ok and room.password=='secret','owner enables password '..n)
    check(not room.readyByUserId.player1 and not room.readyByUserId.player2,'settings clear readiness '..n)
    check(registry:UpdatePrivateRoomSettings('player1',owner,n,true,'').ok and room.password=='secret','blank keeps existing password '..n)
    check(registry:UpdatePrivateRoomSettings('player1',owner,n,true,'newkey').ok and room.password=='newkey','owner changes password '..n)
    check(registry:UpdatePrivateRoomSettings('player1',owner,n,false,'').ok and room.password=='','owner removes password '..n)
    for _,capacity in ipairs({5,4,3}) do
        local oldTable=room.tableId
        check(registry:UpdatePrivateRoomSettings('player1',owner,capacity,false,'').ok,'capacity migration accepted '..n..' to '..capacity)
        check(room.code=='L777' and room.capacity==capacity and #room.userIds==2,'migration keeps room and participants')
        for seat=1,2 do
            local id='player'..seat;local assignment=registry.seatByUserId[id]
            check(assignment.tableId==room.tableId and room.seatByUserId[id]==assignment.seatIndex,'registry and room seat synchronized')
            check(coordinators[room.tableId].playerEntityBySeat[assignment.seatIndex]==registry.playerByUserId[id],'destination owns same player')
        end
        if oldTable~=room.tableId then check(registry:IsTableEmpty(oldTable),'previous capacity table released') end
    end
    local targetId=registry:GetTableIdForCapacity(4)
    local key=registry:MakeSeatKey(targetId,1);registry.seatOwnerByKey[key]='busy'
    check(not registry:UpdatePrivateRoomSettings('player1',owner,4,false,'').ok and room.capacity==3,'busy capacity preserves original room')
    registry.seatOwnerByKey[key]=nil
    local current=coordinators[room.tableId];local original=current.SessionEntity:GetComponent('script.LexioGameSession')
    original.phase='Playing';current.startRequested=true
    check(not registry:UpdatePrivateRoomSettings('player1',owner,3,true,'blocked').ok,'settings blocked after game starts')
end
log('[OFFLINE] Host room settings passed total='..assertions)

do
    local registry,room,coordinators,map=roomSettingsFixture(4)
    local owner=registry.playerByUserId.player1
    for seat=3,4 do
        local id='player'..seat
        local player={CurrentMap=map,PlayerComponent={UserId=id},NameTagComponent={Name=id},GetComponent=function() end}
        check(registry:ReserveQueuedSeat(id,player,room.tableId,seat),'additional participant reserved')
        table.insert(room.userIds,id);room.seatByUserId[id]=seat;registry.privateRoomCodeByUserId[id]=room.code
    end
    local result=registry:UpdatePrivateRoomSettings('player1',owner,3,false,'')
    check(not result.ok and result.reason=='capacity_too_small' and room.capacity==4,'cannot shrink below current participant count')
end
do
    local registry,room,coordinators=roomSettingsFixture(3)
    local owner=registry.playerByUserId.player1
    local reserve=registry.ReserveQueuedSeat
    registry.ReserveQueuedSeat=function(self,id,player,tableId,seat)
        if tableId=='table03' and id=='player2' then return false end
        return reserve(self,id,player,tableId,seat)
    end
    local result=registry:UpdatePrivateRoomSettings('player1',owner,5,true,'secret')
    check(not result.ok and room.capacity==3 and room.tableId=='table01' and room.password=='','failed migration preserves room settings')
    check(registry.seatByUserId.player1.tableId=='table01' and registry.seatByUserId.player2.tableId=='table01','failed migration restores all participants')
    check(registry:IsTableEmpty('table03'),'failed migration releases target table')
    check(registry:LeavePrivateRoom('player1','test_owner_leave'),'owner leaves waiting room')
    local snapshot=registry:BuildPrivateRoomSnapshot(room,'player2')
    check(snapshot.ownerUserId=='player2' and snapshot.members[1].owner,'ownership transfers to remaining participant')
    check(registry:UpdatePrivateRoomSettings('player2',registry.playerByUserId.player2,3,true,'next').ok,'new owner can change settings')
end
log('[OFFLINE] Settings rollback and host transfer passed total='..assertions)

do
    Color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end
    local ui=LexioPlayUIController.new()
    for capacity=3,5 do
        for seat=1,capacity do
            local avatar={Enable=false};local owner={Enable=true};local bubble={Enable=true}
            local slot={SpriteGUIRendererComponent={},GetChildByName=function(self,name)
                if name=='Avatar' then return avatar elseif name=='OwnerBadge' then return owner elseif name=='ChatBubble' then return bubble end
            end}
            ui:SetWaitingSeatState(slot,true,true)
            check(avatar.Enable and slot.SpriteGUIRendererComponent.Color.g==0.92,'ready occupied seat is green')
            ui:SetWaitingSeatState(slot,false,true)
            check(not avatar.Enable and slot.SpriteGUIRendererComponent.Color.g==0.79,'empty seat resets color even with stale readiness')
            check(not owner.Enable and not bubble.Enable,'empty seat hides owner badge and bubble')
            ui:SetWaitingSeatState(slot,true,false)
            check(avatar.Enable and slot.SpriteGUIRendererComponent.Color.g==0.79,'new unready occupant starts pink')
        end
    end
end
log('[OFFLINE] Waiting-seat transition regression passed total='..assertions)

local function dynamicRoomFixture()
    Vector3=function(x,y,z) return {x=x,y=y,z=z} end
    local registry=LexioTableRegistry.new()
    local map={Name='map01'}
    local entities={}
    local controlsById={}
    local registryHost={CurrentMap=map,CurrentMapName='map01'}
    registryHost.GetComponent=function(self,name) if name=='script.LexioTableRegistry' then return registry end end
    registry.Entity=registryHost;registry:OnBeginPlay()
    map.GetChildByName=function(self,name) if name=='LexioManualSessionHost' then return registryHost end return entities['/maps/map01/'..name] end
    local function makeHost(name,tableId,capacity,boot)
        local session=LexioGameSession.new();local co=LexioSessionCoordinator.new()
        local host={Name=name,CurrentMap=map,CurrentMapName='map01'}
        host.GetComponent=function(self,typeName) if typeName=='script.LexioGameSession' then return session elseif typeName=='script.LexioSessionCoordinator' then return co end end
        co.Entity=host;co.TableId=tableId;co.RequiredPlayerCount=capacity
        co.AttachBridge=function(self,player,id,seat,role)
            local bridge=LexioPlayerBridge.new();bridge.Entity=player
            bridge.RequestClientReady=function() end
            bridge.ReceiveSnapshot=function(self,role,seat,hand,public,recipient)
                check(recipient==id,'private snapshot targets bound owner only')
                self.capturedHand=hand;self.capturedPublic=public
            end
            bridge:BindServer(host,host,player,id,seat,role)
            self.bridgeByUserId[id]=bridge;player.bridge=bridge
            return bridge
        end
        entities['/maps/map01/'..name]=host
        if boot then co:OnBeginPlay() end
        return host
    end
    for capacity=3,5 do
        local number='0'..(capacity-2)
        makeHost('LexioTable'..number..'SessionHost','table'..number,capacity,true)
    end
    _SpawnService={SpawnByModelId=function(self,modelId,name,pos,parent)
        check(parent==map,'dynamic host has real map parent')
        return makeHost(name,'unassigned',3,false)
    end}
    _EntityService={GetEntityByPath=function(self,path) return entities[path] end,Destroy=function(self,entity) entity.valid=false end}
    _UtilLogic.ElapsedSeconds=100
    local function player(id)
        local controls=LexioManualTestControls.new()
        local entity={Name=id,CurrentMap=map,CurrentMapName='map01',PlayerComponent={UserId=id},NameTagComponent={Name=id}}
        controls.Entity=entity;controlsById[id]=controls
        entity.GetComponent=function(self,name) if name=='script.LexioManualTestControls' then return controls elseif name=='script.LexioPlayerBridge' then return entity.bridge end end
        return entity
    end
    return registry,player,controlsById
end
do
    local registry,player,controls=dynamicRoomFixture()
    local rooms={}
    local seen={}
    for capacity=3,5 do
        for group=1,3 do
            local prefix='n'..capacity..'g'..group..'p'
            local owner=player(prefix..1)
            local created=registry:CreatePrivateRoom(prefix..1,owner,'room'..capacity..group,capacity,'')
            check(created.ok,'multiple same-capacity room creation '..capacity..'/'..group)
            local room=registry.privateRoomByCode[created.room.code]
            check(not seen[room.tableId],'every concurrent room owns a unique session')
            seen[room.tableId]=true
            for seat=2,capacity do check(registry:JoinPrivateRoom(prefix..seat,player(prefix..seat),room.code,'').ok,'join independently allocated room') end
            local co=registry:GetTableCoordinator(room.tableId)
            for seat=1,capacity do check(registry:SetPrivateRoomReady(prefix..seat,registry.playerByUserId[prefix..seat],true),'ready in own room') end
            co:CompleteStartCountdown()
            local game=co.SessionEntity:GetComponent('script.LexioGameSession')
            check(game.phase=='Playing' and game.playerCount==capacity,'each independent match starts')
            for seat=1,capacity do check(#game.hands[seat]==12,'independent match deals twelve per player') end
            table.insert(rooms,{room=room,co=co,game=game,prefix=prefix})
        end
    end
    check(#registry:ListPrivateRooms()==9,'nine concurrent rooms visible')
    local first=rooms[1];local other=rooms[2]
    local beforeVersion=other.game.stateVersion
    local beforeTurn=other.game.currentPlayerIndex
    local otherScore=other.game.scoreLedger[1]
    local firstTurn=first.game.currentPlayerIndex
    local firstUser=first.game.userIds[firstTurn]
    check(first.game:SubmitForUser(firstUser,{first.game.hands[firstTurn][1].id},first.game.stateVersion).ok,'first room submits normally')
    check(other.game.stateVersion==beforeVersion and other.game.currentPlayerIndex==beforeTurn and #other.game.hands[1]==12 and other.game.scoreLedger[1]==otherScore,'submission cannot change other room turn, hand, or score')
    senderUserId=first.prefix..1
    controls[first.prefix..1]:RequestRoomChat('first room only')
    for seat=1,3 do check(#controls[first.prefix..seat]._T.RoomChatLines==1,'room chat reaches own participants') end
    for seat=1,3 do check(controls[other.prefix..seat]._T.RoomChatLines==nil,'room chat never reaches neighboring room') end
    _UtilLogic.ElapsedSeconds=_UtilLogic.ElapsedSeconds+1
    controls[first.prefix..1]:RequestRoomChat('씨 . 발')
    for seat=1,3 do
        check(controls[first.prefix..seat]._T.RoomChatLines[2]==first.prefix .. '1: ***','server broadcasts only masked profanity')
        check(controls[first.prefix..seat]._T.RoomChatBubbles[first.prefix..1].text=='***','bubble receives same masked payload')
        check(controls[other.prefix..seat]._T.RoomChatLines==nil,'filtered chat remains room-isolated')
    end
    first.co:UpdateTurnClock(0);other.co:UpdateTurnClock(0)
    local otherTime=other.co._T.TurnCountdown
    first.co:MarkDisconnected(first.prefix..3)
    local generation=first.co._T.DisconnectGeneration[3]
    local firstTime=first.co._T.TurnCountdown
    first.co:UpdateTurnClock(1);other.co:UpdateTurnClock(1)
    check(first.co._T.TurnCountdown==firstTime and other.co._T.TurnCountdown==otherTime-1,'disconnect pauses only its own room clock')
    check(not other.co:VoteDisconnectedSeat(other.prefix..1,registry.playerByUserId[other.prefix..1],3,generation).ok,'vote in other room cannot replace first room seat')
    for seat=1,2 do check(first.co:VoteDisconnectedSeat(first.prefix..seat,registry.playerByUserId[first.prefix..seat],3,generation).ok,'own-room kick vote accepted') end
    check(first.co._T.AIBySeat[3] and not other.co._T.AIBySeat[3],'AI replacement isolated by room')
    local returningId=other.prefix..3
    local returningPlayer=registry.playerByUserId[returningId]
    local returningHand=other.game.hands[3]
    other.co:MarkDisconnected(returningId)
    check(not registry:ReconnectPlayer(returningId,registry.playerByUserId[first.prefix..1]),'reconnect cannot borrow another room participant identity')
    check(registry:ReconnectPlayer(returningId,returningPlayer),'reconnect restores own dynamic room')
    check(other.game.hands[3]==returningHand and other.co.playerEntityBySeat[3]==returningPlayer,'dynamic reconnect keeps original private hand')
    check(controls[returningId]._T.PrivateRoomSnapshot.code==other.room.code,'reconnect UI receives own room only')

    local host=registry._T.DynamicHosts[other.room.tableId]
    if host then
        local count=#other.game.hands[1]
        other.co:OnBeginPlay()
        check(#other.game.hands[1]==count and other.co.startRequested,'late engine lifecycle cannot reset an allocated game')
    end

    local peerLedger={}
    for seat=1,3 do peerLedger[seat]=other.game.scoreLedger[seat] end
    local finishing=first.game.currentPlayerIndex
    first.game.hands[finishing]={first.game.hands[finishing][1]}
    first.game.phase='LeadPending';first.game.winningPlayerIndex=finishing;first.game.currentPlay=nil
    check(first.game:SubmitForUser(first.game.userIds[finishing],{first.game.hands[finishing][1].id},first.game.stateVersion).ok and first.game.phase=='Finished','one room reaches real score settlement')
    for seat=1,3 do check(other.game.scoreLedger[seat]==peerLedger[seat],'other room score unaffected by settlement') end
    first.co:BroadcastSnapshots()
    first.co.finishDecisionByUserId[first.prefix..1]='Replay';first.co.finishDecisionByUserId[first.prefix..2]='Replay'
    local score=first.game.scoreLedger[1]
    first.co:StartReplayRound()
    check(first.game.phase=='Finished' and first.game.scoreLedger[1]==score,'AI room cannot restart after settlement')
    for seat=1,3 do check(other.game.scoreLedger[seat]==peerLedger[seat],'other room score unaffected by rejected replay') end
    local peer=rooms[3];local peerScore=peer.game.scoreLedger[1]
    local closing=other.game.currentPlayerIndex
    other.game.hands[closing]={other.game.hands[closing][1]};other.game.phase='LeadPending';other.game.winningPlayerIndex=closing;other.game.currentPlay=nil
    check(other.game:SubmitForUser(other.game.userIds[closing],{other.game.hands[closing][1].id},other.game.stateVersion).ok,'all-human room finishes')
    other.co:BroadcastSnapshots()
    for seat=1,3 do other.co.finishDecisionByUserId[other.prefix..seat]='Replay' end
    local carry=other.game.scoreLedger[1];other.co:StartReplayRound()
    check(other.game.phase=='Playing' and other.game.scoreLedger[1]==carry,'all-human replay carries own score')
    check(peer.game.scoreLedger[1]==peerScore,'all-human replay preserves another room score')
    for seat=1,2 do
        local id=first.prefix..seat
        first.co:MarkDisconnected(id);first.co._T.KickedBySeat[seat]=true;first.co:EnableSeatAI(seat,'test_leave');registry:DetachReplacedPlayer(id,first.room.tableId,seat)
    end
    first.co._T.KickedBySeat[3]=true;registry:DetachReplacedPlayer(first.prefix..3,first.room.tableId,3)
    check(registry.privateRoomByCode[first.room.code]==nil and other.game.phase=='Playing','closing one room preserves adjacent game')
    check(#registry:ListPrivateRooms()==8,'only empty room disappears')
end
log('[OFFLINE] Dynamic multi-room isolation passed total='..assertions)

do
    local registry,player=dynamicRoomFixture()
    local sessions={}
    for index=1,12 do
        local id='queued'..index
        check(registry:JoinQueue(id,player(id),3),'join repeated three-player matchmaking')
    end
    for index=1,12 do
        local assignment=registry.seatByUserId['queued'..index]
        check(assignment~=nil,'all queued players assigned')
        sessions[assignment.tableId]=(sessions[assignment.tableId] or 0)+1
    end
    local count=0
    for id,size in pairs(sessions) do count=count+1;check(size==3,'each auto-match owns three seats') end
    check(count==4 and #registry.queueUserIds==0,'four simultaneous three-player automatic matches')
end
do
    local registry,player=dynamicRoomFixture()
    local a=player('ownerA');local b=player('ownerB')
    local one=registry:CreatePrivateRoom('ownerA',a,'first',3,'')
    local two=registry:CreatePrivateRoom('ownerB',b,'second',3,'')
    check(one.ok and two.ok,'two waiting rooms with same size created')
    local roomA=registry.privateRoomByCode[one.room.code]
    local roomB=registry.privateRoomByCode[two.room.code]
    local tableB=roomB.tableId
    check(registry:UpdatePrivateRoomSettings('ownerA',a,5,true,'secret').ok,'one room changes size independently')
    check(roomB.capacity==3 and roomB.password=='' and roomB.tableId==tableB and registry.seatByUserId.ownerB.tableId==tableB,'neighbor settings and assignment preserved')
    local host=registry._T.DynamicHosts[tableB]
    check(registry:LeavePrivateRoom('ownerB','close'),'last user leaves dynamic room')
    registry:OnUpdate(1)
    check(not isvalid(host) and registry:GetTableCoordinator(tableB)==nil,'empty dynamic host destroyed without waiting queue')
    check(registry.privateRoomByCode[roomA.code]~=nil and registry.seatByUserId.ownerA.tableId==roomA.tableId,'dynamic cleanup preserves other room')
end
log('[OFFLINE] Matchmaking, score, replay and cleanup isolation passed total='..assertions)

do
    local oldGrant=_LexioRewardService.GrantMatchRewards
    _LexioRewardService.GrantMatchRewards=function() error('retired reward payout invoked') end
    for capacity=3,5 do
        for _,mode in ipairs({'ai_finish','returned_before','returned_after'}) do
            local registry,makePlayer,controls=dynamicRoomFixture()
            local players={};local ids={}
            for seat=1,capacity do ids[seat]=mode..seat;players[seat]=makePlayer(ids[seat]);controls[ids[seat]]._T.IsSeated=true end
            local result=registry:CreatePrivateRoom(ids[1],players[1],'finish policy',capacity,'')
            check(result.ok,'finish policy room created')
            local room=registry.privateRoomByCode[result.room.code]
            for seat=2,capacity do check(registry:JoinPrivateRoom(ids[seat],players[seat],room.code,'').ok,'finish policy room joined') end
            for seat=1,capacity do registry:SetPrivateRoomReady(ids[seat],players[seat],true) end
            local co=registry:GetTableCoordinator(room.tableId);co:CompleteStartCountdown()
            local game=co.SessionEntity:GetComponent('script.LexioGameSession')
            co:MarkDisconnected(ids[capacity]);co:EnableSeatAI(capacity,'test_disconnect')
            controls[ids[capacity]]._T.ReconnectOnly=true
            if mode=='returned_before' then check(registry:ReconnectPlayer(ids[capacity],players[capacity]),'before-finish reconnect succeeds') end
            game:SetPersistentRewardsEligible(true,'retired_payout_probe')
            game.currentPlayerIndex=1;game.winningPlayerIndex=1;game.phase='LeadPending';game.currentPlay=nil;game.passed={}
            game.hands[1]={game.hands[1][1]}
            check(game:SubmitForUser(ids[1],{game.hands[1][1].id},game.stateVersion).ok,'round finishes with final chip settlement')
            co:BroadcastSnapshots()
            local score=game.scoreLedger[1]
            if mode=='returned_before' then
                check(not co:BuildClientPublicSnapshot().finishedWithAI,'AI history does not block human-finished round')
                for seat=1,capacity do check(co:SubmitFinishDecision(ids[seat],players[seat],'Replay',co.finishGeneration).ok,'all humans can replay after timely return') end
                check(game.phase=='Playing' and game.scoreLedger[1]==score,'timely return preserves chips through replay')
                check(registry.privateRoomByCode[room.code]~=nil,'human-finished room stays open')
            else
                check(co:BuildClientPublicSnapshot().finishedWithAI,'AI present at finish is latched')
                if mode=='returned_after' then
                    check(registry:ReconnectPlayer(ids[capacity],players[capacity]),'late return can receive final results')
                    check(not co:HasAISeat() and co:BuildClientPublicSnapshot().finishedWithAI,'late return cannot rewrite finish-time decision')
                end
                check(not co:SubmitFinishDecision(ids[1],players[1],'Replay',co.finishGeneration).ok,'AI-finished round rejects replay on server')
                co:OnUpdate(31)
                check(registry.privateRoomByCode[room.code]==nil,'AI-finished room is deleted')
                for seat=1,capacity do
                    check(registry.seatByUserId[ids[seat]]==nil,'AI-finished round releases every registry seat')
                    check(not controls[ids[seat]]._T.ReconnectOnly and not controls[ids[seat]]:IsSeated(),'AI-finished round returns every live client to lobby')
                end
                local fresh=registry:CreatePrivateRoom(ids[1],players[1],'fresh game',capacity,'')
                check(fresh.ok,'new room can be created after AI round closes')
                local freshRoom=registry.privateRoomByCode[fresh.room.code]
                for seat=2,capacity do check(registry:JoinPrivateRoom(ids[seat],players[seat],freshRoom.code,'').ok,'fresh participants join new room') end
                for seat=1,capacity do registry:SetPrivateRoomReady(ids[seat],players[seat],true) end
                local newCo=registry:GetTableCoordinator(freshRoom.tableId);newCo:CompleteStartCountdown()
                local newGame=newCo.SessionEntity:GetComponent('script.LexioGameSession')
                for seat=1,capacity do check(newGame.scoreLedger[seat]==64,'new room always starts from sixty-four chips') end
            end
        end
    end
    _LexioRewardService.GrantMatchRewards=oldGrant
end
do
    local ui=LexioPlayUIController.new();ui._T.PendingFinishId=''
    ui.FinishPanel={UITransformComponent={}};ui.ErrorText={TextGUIRendererComponent={}}
    ui.FinishCountdownText={TextGUIRendererComponent={}};ui.FinishScoreText={TextGUIRendererComponent={}}
    ui.ReplayButton={Enable=true,ButtonComponent={}};ui.ExitButton={UITransformComponent={},ButtonComponent={}}
    local snapshot={phase='Finished',stateVersion=1,playerCount=3,finishedWithAI=true,finishCountdown=30,seatNames={'a','b','c'},scoreLedger={70,60,62},scoreDeltas={6,-4,-2}}
    local bridge={_T={Seat=1,Role='Player'},GetMatchedPublicSnapshot=function() return snapshot end}
    ui.GetLocalBridge=function() return bridge end
    _UILogic={SetSiblingIndex=function() end}
    ui:RenderFinish(snapshot)
    check(not ui.ReplayButton.Enable and not ui.ReplayButton.ButtonComponent.Enable and ui.ExitButton.ButtonComponent.Enable,'AI results only offer lobby return')
    check(ui.ExitButton.UITransformComponent.anchoredPosition.x==0,'AI result lobby button centered')
    snapshot.finishedWithAI=false;ui:RenderFinish(snapshot)
    check(ui.ReplayButton.Enable and ui.ReplayButton.ButtonComponent.Enable and ui.ExitButton.UITransformComponent.anchoredPosition.x==160,'all-human results restore normal replay layout')
end
log('[OFFLINE] Finish-time AI policy, lobby return and fresh chips passed total='..assertions)

do
    local registry,makePlayer,controls=dynamicRoomFixture()
    local first=makePlayer('quick1')
    _UserService={LocalPlayer=first}
    local menu=LexioMainMenuController.new()
    local ui=LexioPlayUIController.new()
    ui.IsLexioGameRoom=function() return true end
    for _,key in ipairs({'MatchPanel','Watch1Button','Watch2Button','Watch3Button','StopWatchButton','MatchBackButton','QueueButton','QueueStatusText'}) do
        ui[key]={Enable=false,TextGUIRendererComponent={},ButtonComponent={}}
    end
    menu:OpenAutoMatch()
    for frame=1,10 do ui:UpdateMatchPanel() end
    check(controls.quick1._T.MatchMenuOpen and ui.MatchPanel.Enable,'quick button opens persistent size selection')
    check(ui.Watch1Button.Enable and ui.Watch2Button.Enable and ui.Watch3Button.Enable,'quick match exposes all player counts')
    senderUserId='quick1';controls.quick1:ChooseAutoQueueSize(3)
    ui:UpdateMatchPanel()
    check(controls.quick1._T.IsQueued and registry.queuedByUserId.quick1 and ui.MatchPanel.Enable,'size choice reaches server queue and remains visible')
    controls.quick1:ToggleAutoQueue()
    ui:UpdateMatchPanel()
    check(not controls.quick1._T.IsQueued and not registry.queuedByUserId.quick1 and not ui.MatchPanel.Enable,'quick match cancellation clears server and UI')
    menu:OpenAutoMatch();controls.quick1:ChooseAutoQueueSize(3)
    for index=2,3 do
        local player=makePlayer('quick'..index);_UserService.LocalPlayer=player;senderUserId='quick'..index
        menu:OpenAutoMatch();controls['quick'..index]:ChooseAutoQueueSize(3)
    end
    local assignment=registry.seatByUserId.quick1
    check(assignment~=nil and registry.seatByUserId.quick2.tableId==assignment.tableId and registry.seatByUserId.quick3.tableId==assignment.tableId,'quick matching assigns all three to same game')
    local co=registry:GetTableCoordinator(assignment.tableId)
    for index=1,3 do
        local id='quick'..index;senderUserId=id
        check(controls[id]:IsSeated() and not controls[id]._T.IsQueued,'match result clears queue and seats each client')
        registry.playerByUserId[id].bridge:NotifyClientReady()
    end
    check(co.startCountdownActive,'real ready RPC starts automatic match countdown')
    co:CompleteStartCountdown()
    check(co.SessionEntity:GetComponent('script.LexioGameSession').phase=='Playing','quick button through ready RPC reaches active game')
end
do
    local registry,makePlayer,controls=dynamicRoomFixture()
    local player=makePlayer('rejectedQuick')
    local cancels=0
    registry.JoinQueue=function() return false end
    registry.CancelQueue=function() cancels=cancels+1;return true end
    senderUserId='rejectedQuick'
    controls.rejectedQuick:RequestAutoQueue(true,3)
    check(cancels==0,'rejected join never falls through into queue cancellation')
    check(controls.rejectedQuick._T.QueueError=='queue_rejected' and controls.rejectedQuick._T.MatchMenuOpen,'rejected queue request opens actionable feedback')
end
log('[OFFLINE] Quick match button-to-game regression passed total='..assertions)

do
    local registry,makePlayer,controls=dynamicRoomFixture()
    local owner=makePlayer('existingOwner')
    local created=registry:CreatePrivateRoom('existingOwner',owner,'existing',3,'')
    local room=registry.privateRoomByCode[created.room.code]
    for index=1,5 do local id='waiting'..index;check(registry:JoinQueue(id,makePlayer(id),3),'five users join quick matching') end
    check(#room.userIds==3 and registry.seatByUserId.waiting1.tableId==room.tableId and registry.seatByUserId.waiting2.tableId==room.tableId,'first two queue users fill existing room')
    local newTable=registry.seatByUserId.waiting3.tableId
    check(newTable~=room.tableId and registry.seatByUserId.waiting4.tableId==newTable and registry.seatByUserId.waiting5.tableId==newTable,'remaining three form independent new match')
    check(#registry.queueUserIds==0,'all five queue users assigned exactly once')
    check(controls.waiting1._T.PrivateRoomSnapshot.code==room.code and not controls.waiting1._T.IsQueued and controls.waiting1:IsSeated(),'existing-room quick entry opens waiting room and clears queue')
    local existingCo=registry:GetTableCoordinator(room.tableId)
    check(not existingCo.startCountdownActive and not room.readyByUserId.waiting1,'existing-room join still requires explicit ready')
end
do
    local registry,makePlayer=dynamicRoomFixture()
    local locked=registry:CreatePrivateRoom('lockedOwner',makePlayer('lockedOwner'),'locked',3,'secret')
    local public4=registry:CreatePrivateRoom('fourOwner',makePlayer('fourOwner'),'four',4,'')
    local running=registry:CreatePrivateRoom('runningOwner',makePlayer('runningOwner'),'running',3,'')
    local runningRoom=registry.privateRoomByCode[running.room.code]
    registry:GetTableCoordinator(runningRoom.tableId).SessionEntity:GetComponent('script.LexioGameSession').phase='Playing'
    check(registry:JoinQueue('exactThree',makePlayer('exactThree'),3),'exact-size user queues')
    check(registry.queuedByUserId.exactThree and registry.seatByUserId.exactThree==nil,'password, running and wrong-size rooms excluded')
    check(registry:JoinQueue('anySize',makePlayer('anySize'),0),'any-size user queues')
    check(registry.privateRoomCodeByUserId.anySize==public4.room.code and registry.queuedByUserId.exactThree,'any-size user joins eligible existing room')
    local added=registry:CreatePrivateRoom('newOwner',makePlayer('newOwner'),'newly created',3,'')
    registry:OnUpdate(1)
    check(registry.privateRoomCodeByUserId.exactThree==added.room.code,'queued user finds room created after joining queue')
end
do
    local registry,makePlayer=dynamicRoomFixture()
    registry:CreatePrivateRoom('owner',makePlayer('owner'),'retry',3,'')
    local reserve=registry.ReserveQueuedSeat
    registry.ReserveQueuedSeat=function(self,id,player,tableId,seat) if id=='retryUser' then return false end return reserve(self,id,player,tableId,seat) end
    registry:JoinQueue('retryUser',makePlayer('retryUser'),3)
    check(registry.queuedByUserId.retryUser and registry.playerByUserId.retryUser~=nil,'failed existing-room reservation preserves queue ticket')
    registry.ReserveQueuedSeat=reserve;registry:OnUpdate(1)
    check(registry.seatByUserId.retryUser~=nil and not registry.queuedByUserId.retryUser,'existing-room reservation retries successfully')
end
do
    local ui=LexioPlayUIController.new()
    local controls=LexioManualTestControls.new();controls._T.IsSeated=true
    local snapshot={phase='WaitingPlayers',playerCount=3,privateRoomCode='',startCountdown=0,seatUserIds={'a','b','c'}}
    local bridge={GetMatchedPublicSnapshot=function() return snapshot end}
    local nodes={}
    local function node(path)
        if not nodes[path] then
            nodes[path]={Enable=false,UITransformComponent={},TextGUIRendererComponent={}}
            nodes[path].GetChildByName=function(self,name) return node(path..'/'..name) end
        end
        return nodes[path]
    end
    _EntityService={GetEntityByPath=function(self,path) return node(path) end}
    _UserService={LocalPlayer={GetComponent=function() return controls end}}
    _UILogic={SetSiblingIndex=function() end}
    ui.GetLocalBridge=function() return bridge end
    ui:UpdateMatchFoundScreen()
    check(node('/ui/LexioPlayHUD/MatchFound').Enable and node('/ui/LexioPlayHUD/MatchFound/Window/Countdown').TextGUIRendererComponent.Text=='준비 중','match confirmation shown while clients connect')
    for seconds=3,1,-1 do snapshot.startCountdown=seconds;ui:UpdateMatchFoundScreen();check(node('/ui/LexioPlayHUD/MatchFound/Window/Countdown').TextGUIRendererComponent.Text==tostring(seconds),'real countdown number displayed '..seconds) end
    snapshot.phase='Playing';ui:UpdateMatchFoundScreen()
    check(not node('/ui/LexioPlayHUD/MatchFound').Enable,'countdown closes when game actually starts')
    snapshot.phase='WaitingPlayers';snapshot.privateRoomCode='L001';snapshot.startCountdown=0;ui:UpdateMatchFoundScreen()
    check(not node('/ui/LexioPlayHUD/MatchFound').Enable,'existing room keeps normal ready screen before everyone readies')
    snapshot.startCountdown=3;ui:UpdateMatchFoundScreen()
    check(node('/ui/LexioPlayHUD/MatchFound').Enable and node('/ui/LexioPlayHUD/MatchFound/Window/Title').TextGUIRendererComponent.Text=='모두 준비 완료!','existing room countdown shown after explicit readiness')
end
log('[OFFLINE] Existing-room priority and match countdown passed total='..assertions)

for capacity=3,5 do
    local registry,makePlayer,controls=dynamicRoomFixture()
    local ids={};local players={}
    for seat=1,capacity do ids[seat]='resume'..capacity..'p'..seat;players[seat]=makePlayer(ids[seat]) end
    local created=registry:CreatePrivateRoom(ids[1],players[1],'temporary AI',capacity,'')
    local room=registry.privateRoomByCode[created.room.code]
    for seat=2,capacity do registry:JoinPrivateRoom(ids[seat],players[seat],room.code,'') end
    for seat=1,capacity do registry:SetPrivateRoomReady(ids[seat],players[seat],true) end
    local co=registry:GetTableCoordinator(room.tableId);co:CompleteStartCountdown()
    local game=co.SessionEntity:GetComponent('script.LexioGameSession')
    local target=capacity;senderUserId=ids[target]
    controls[ids[target]]:RequestSuspendGame()
    co:UpdateConnections(29)
    check(not co._T.AIBySeat[target] and co:HasPendingDisconnect(),'generated room gives thirty-second reconnect grace '..capacity)
    approveAI(co,target)
    check(co._T.AIBySeat[target] and not co._T.KickedBySeat[target] and not co:HasPendingDisconnect(),'generated room begins temporary AI without expulsion '..capacity)
    check(registry.seatByUserId[ids[target]]~=nil and controls[ids[target]]._T.ReconnectOnly,'temporary AI preserves reconnect screen and seat ownership '..capacity)
    game.currentPlayerIndex=target;game.winningPlayerIndex=target;game.currentPlay=nil;game.phase='LeadPending';game.passed={}
    local before=#game.hands[target]
    co._T.ClockVersion=nil;co:UpdateTurnClock(0);co:UpdateTurnClock(1.5)
    check(#game.hands[target]==before-1,'temporary AI actually plays before return '..capacity)
    local hand=game.hands[target]
    controls[ids[target]]:RequestResumeGame(true)
    check(not co._T.AIBySeat[target] and co.playerEntityBySeat[target]==players[target],'reconnect button takes control back from AI '..capacity)
    check(game.hands[target]==hand and #hand==before-1,'returning human inherits hand after AI actions '..capacity)
    check(controls[ids[target]]:IsSeated() and not controls[ids[target]]._T.ReconnectOnly,'reconnect screen returns to same game '..capacity)
    game.currentPlayerIndex=target;game.winningPlayerIndex=target;game.phase='LeadPending';game.currentPlay=nil;game.hands[target]={hand[1]}
    check(game:SubmitForUser(ids[target],{hand[1].id},game.stateVersion).ok,'returned human finishes the round '..capacity)
    co:BroadcastSnapshots()
    check(not co:BuildClientPublicSnapshot().finishedWithAI,'timely AI-to-human return keeps replay available '..capacity)
end
log('[OFFLINE] Generated-room temporary AI return passed total='..assertions)

local function continuationFixture(capacity,remaining)
    local registry,makePlayer,controls=dynamicRoomFixture()
    local ids={};local players={}
    for seat=1,capacity do ids[seat]='ballot'..capacity..'p'..seat;players[seat]=makePlayer(ids[seat]);controls[ids[seat]]._T.IsSeated=true end
    local created=registry:CreatePrivateRoom(ids[1],players[1],'vote policy',capacity,'')
    local room=registry.privateRoomByCode[created.room.code]
    for seat=2,capacity do registry:JoinPrivateRoom(ids[seat],players[seat],room.code,'') end
    for seat=1,capacity do registry:SetPrivateRoomReady(ids[seat],players[seat],true) end
    local co=registry:GetTableCoordinator(room.tableId);co:CompleteStartCountdown()
    for seat=remaining+1,capacity do senderUserId=ids[seat];controls[ids[seat]]:RequestSuspendGame() end
    return registry,co,room,ids,players,controls
end
for capacity=3,5 do
    for remaining=1,capacity-1 do
        local registry,co,room,ids,players,controls=continuationFixture(capacity,remaining)
        local target=remaining+1;local generation=co._T.DisconnectGeneration[target]
        local required=math.floor(remaining/2)+1
        check(co:GetDisconnectVoteThreshold(target)==required,'strict-majority threshold for '..remaining..' human(s)')
        for seat=1,required-1 do
            check(co:VoteDisconnectedSeat(ids[seat],players[seat],target,generation,true).ok,'initial approval accepted')
            check(co:HasPendingDisconnect(),'half or fewer approvals never starts AI')
        end
        check(co:VoteDisconnectedSeat(ids[required],players[required],target,generation,true).ok,'threshold approval accepted')
        check(not co:HasPendingDisconnect(),'one shared approval resolves every pending AI seat')
        for seat=remaining+1,capacity do
            check(co._T.AIBySeat[seat] and not co._T.KickedBySeat[seat],'all missing seats temporarily AI controlled')
            check(registry.seatByUserId[ids[seat]]~=nil and controls[ids[seat]]._T.ReconnectOnly,'AI ballot preserves every missing player ownership and reconnect screen')
        end
        senderUserId=ids[target];controls[ids[target]]:RequestResumeGame(true)
        check(co.playerEntityBySeat[target]==players[target] and not co._T.AIBySeat[target] and not controls[ids[target]]._T.ReconnectOnly,'voted AI returns to original human')
        check(registry.privateRoomByCode[room.code]~=nil,'approved continuation keeps room alive')
    end
end
for remaining=1,4 do
    local capacity=math.max(3,remaining+1)
    local registry,co,room,ids,players,controls=continuationFixture(capacity,remaining)
    local target=remaining+1;local generation=co._T.DisconnectGeneration[target]
    local maximumNo=remaining-(math.floor(remaining/2)+1)+1
    for seat=1,maximumNo do
        check(co:VoteDisconnectedSeat(ids[seat],players[seat],target,generation,false).ok,'opposition vote accepted')
        if seat<maximumNo then check(registry.privateRoomByCode[room.code]~=nil,'minority opposition does not close potentially passing ballot') end
    end
    check(registry.privateRoomByCode[room.code]==nil,'impossible strict majority closes room')
    for seat=1,capacity do
        check(registry.seatByUserId[ids[seat]]==nil,'rejected continuation releases every seat')
        check(not controls[ids[seat]]._T.ReconnectOnly and not controls[ids[seat]]:IsSeated(),'rejected continuation returns live and suspended humans to lobby')
    end
end
for remaining=1,4 do
    local capacity=math.max(3,remaining+1)
    local registry,co,room,ids,players=continuationFixture(capacity,remaining)
    local target=remaining+1;local generation=co._T.DisconnectGeneration[target]
    local yes=math.floor(remaining/2)
    for seat=1,yes do co:VoteDisconnectedSeat(ids[seat],players[seat],target,generation,true) end
    co:UpdateConnections(29)
    check(registry.privateRoomByCode[room.code]~=nil and co:HasPendingDisconnect(),'ballot remains open before thirty-second deadline')
    check(co:BuildClientPublicSnapshot().disconnectVoteSecondsRemaining==1,'ballot remaining second published')
    co:UpdateConnections(1)
    check(registry.privateRoomByCode[room.code]==nil,'no response cannot hold room beyond deadline')
    local result=co._T.LastDisconnectBallotResult
    check(result.total==remaining and result.yes==yes and result.no==remaining-yes,'all non-votes explicitly counted as opposition')
end
do
    local registry,co,room,ids,players=continuationFixture(5,3)
    local target=4;local oldGeneration=co._T.DisconnectGeneration[target]
    co:VoteDisconnectedSeat(ids[1],players[1],target,oldGeneration,true)
    co:MarkDisconnected(ids[3])
    check(co:GetDisconnectBallotCounts().yes==0,'roster change resets votes')
    check(not co:VoteDisconnectedSeat(ids[2],players[2],target,oldGeneration,true).ok,'old ballot generation rejected after roster change')
    local current=co._T.DisconnectGeneration[target]
    co:VoteDisconnectedSeat(ids[1],players[1],target,current,true)
    co:VoteDisconnectedSeat(ids[1],players[1],target,current,true)
    check(co:HasPendingDisconnect(),'duplicate approval cannot satisfy two-person unanimity')
    co:VoteDisconnectedSeat(ids[2],players[2],target,current,true)
    check(co._T.AIBySeat[3] and co._T.AIBySeat[4] and co._T.AIBySeat[5],'one ballot starts all three AI substitutes')
end
log('[OFFLINE] Strict-majority AI continuation and no-vote timeout passed total='..assertions)

-- Presentation: sound deduplication, mute, scale restoration and snapshot idempotence.
do
    local audio={bgm=0,sfx=0,stopped=0}
    _SoundService={PlayBGM=function() audio.bgm=audio.bgm+1 end, PlaySound=function() audio.sfx=audio.sfx+1 end, StopBGM=function() audio.stopped=audio.stopped+1 end, StopSound=function() end}
    local ui=LexioPlayUIController.new()
    ui._T.PresentationEnabled=true; ui._T.SoundEnabled=true
    ui.HandPanelPC=nil;ui.FinishPanel=nil
    ui.GetLocalBridge=function() return {_T={Seat=1}} end
    ui:UpdatePresentation(0.1); ui:UpdatePresentation(0.1)
    check(audio.bgm==1,'BGM starts once')
    ui:PlayFeedback('Select'); ui:PlayFeedback('Select')
    check(audio.sfx==1,'same-frame sound is deduplicated')
    ui:ToggleAudio(); ui:PlayFeedback('Submit')
    check(audio.stopped==1 and audio.sfx==1,'mute stops BGM and suppresses effects')
    ui:UpdatePresentation(0.1); ui:ToggleAudio()
    check(audio.bgm==2 and ui._T.SoundEnabled,'unmute resumes BGM')
    local node={Name='Test',UITransformComponent={UIScale=Vector3(2,3,1)}}
    ui:PulseUI(node,0.1,0.2); ui:PulseUI(node,0.1,0.2)
    check(#ui._T.UiAnimations==1,'overlapping pulses replace rather than accumulate')
    check(math.abs(node.UITransformComponent.UIScale.x-2.2)<0.0001,'pulse preserves original scale')
    ui:UpdatePresentation(0.3)
    check(node.UITransformComponent.UIScale.x==2 and node.UITransformComponent.UIScale.y==3,'animation restores exact base scale')
    check(#ui._T.UiAnimations==0,'completed animations are removed')
    local snap={tableId='sound-test',stateVersion=1,phase='Playing',currentPlayerIndex=1,turnNumber=1,trickNumber=1,passed={},lastPlay={}}
    ui:PresentSnapshot(snap); local count=audio.sfx
    ui:UpdatePresentation(0.1); ui:PresentSnapshot(snap)
    check(audio.sfx==count,'repeated snapshots do not replay start or turn cues')
    snap.turnNumber=2; snap.stateVersion=2; ui:PresentSnapshot(snap)
    check(audio.sfx==count+1,'new local turn produces one cue')
    ui:UpdatePresentation(0.1); snap.phase='Finished';snap.winnerIndex=1;ui:PresentSnapshot(snap);count=audio.sfx
    ui:UpdatePresentation(0.1);ui:PresentSnapshot(snap)
    check(audio.sfx==count,'result cue plays once')
    snap.stateVersion=0;snap.phase='LeadPending';snap.turnNumber=1;ui:PresentSnapshot(snap)
    check(not ui._T.PresentationResult,'replay resets result presentation')
end
log('[OFFLINE] Presentation regression passed total='..assertions)

do
    local ui=LexioPlayUIController.new();ui._T.PresentationEnabled=true;ui._T.SoundEnabled=true
    local sounds=0;_SoundService={PlaySound=function() sounds=sounds+1 end}
    local function button(name)
        return {Name=name,ButtonComponent={},Children={},ConnectEvent=function(self,event,fn) self.calls=(self.calls or 0)+1;self.click=fn;return self.calls end}
    end
    local a=button('StartButton');local b=button('RankSortButton');local c=button('CreateConfirmButton');local mute=button('SoundButton')
    local tree={Name='Root',Children={a,{Name='Nested',Children={b,c,mute}}}}
    ui:BindButtonSounds(tree);ui:BindButtonSounds(tree)
    check(a.calls==1 and b.calls==1 and c.calls==1,'all nested UI buttons bind exactly once')
    check(mute.calls==nil,'mute button retains its dedicated audio behavior')
    for _,node in ipairs({a,b,c}) do ui._T.FeedbackClock=(ui._T.FeedbackClock or 0)+0.1;node.click() end
    check(sounds==3,'menu sort and confirmation share one click cue each')
    ui._T.SoundEnabled=false;ui._T.FeedbackClock=1;a.click()
    check(sounds==3,'common click respects mute')
end
log('[OFFLINE] Common button audio passed total='..assertions)

do
 local ui=LexioPlayUIController.new();ui._T.PresentationEnabled=true;ui._T.AudioStarted=true;ui.HandPanelPC=nil;ui.FinishPanel=nil
 ui.GetLocalBridge=function() return {_T={Seat=1}} end
 local played={};ui.PlayFeedback=function(self,kind) played[#played+1]=kind end
 local snap={tableId='voice-delay',stateVersion=1,phase='LeadPending',currentPlayerIndex=1,turnNumber=1,trickNumber=1,passed={},lastPlay={}}
 ui:PresentSnapshot(snap)
 check(played[1]=='Start' and #played==1,'first turn waits for start voice')
 ui:UpdatePresentation(0.5);check(#played==1,'first turn voice does not overlap start')
 ui:UpdatePresentation(0.6);check(played[2]=='Turn','first player receives delayed my-turn')
 ui:UpdatePresentation(1);check(#played==2,'delayed my-turn plays only once')
 snap.stateVersion=0;ui:PresentSnapshot(snap)
 snap.currentPlayerIndex=2;ui:PresentSnapshot(snap);local n=#played
 ui:UpdatePresentation(2);check(#played==n,'turn lost before delay cancels voice')
end
log('[OFFLINE] First-turn voice regression passed total='..assertions)

do
 local ui=LexioPlayUIController.new();ui._T.PresentationEnabled=true;ui._T.SoundEnabled=true
 local bgm=nil;local sounds={}
 _SoundService={SetBGMVolume=function(self,v) bgm=v end,PlaySound=function(self,id,v) sounds[#sounds+1]=v end}
 ui:SetSoundLevel('Bgm',42);check(bgm==0.42,'BGM slider changes live volume')
 ui:SetSoundLevel('Effects',50);ui:PlayFeedback('Turn')
 check(math.abs(sounds[1]-0.5)<0.00001,'effect slider scales voice volume')
 check(ui._T.BgmVolume==0.42,'effect slider preserves BGM level')
 ui:SetSoundLevel('Effects',0);ui._T.FeedbackClock=1;ui:PlayFeedback('Click')
 check(#sounds==1,'zero effects volume suppresses sound')
 ui:SetSoundLevel('Bgm',-20);check(bgm==0,'BGM volume clamps at zero')
 ui:SetSoundLevel('Effects',130);check(ui._T.EffectsVolume==1,'effects volume clamps at maximum')
end
log('[OFFLINE] Independent audio levels passed total='..assertions)

do
 local controls=LexioManualTestControls.new()
 for _,text in ipairs({'씨발','씨 . 발','ㅅ ㅂ','개새끼','병신','지랄','FUCK','f.u.c.k','you are a bitch','씨​발'}) do check(controls:FilterRoomChat(text)=='***','explicit and obfuscated profanity masked') end
 for _,text in ipairs({'안녕하세요','준비됐어요 ㅋㅋ','시발점부터 설명해줘','열차 시발역','class','shitake','좋은 게임이었어요'}) do check(controls:FilterRoomChat(text)==text,'ordinary conversation preserved') end
end
log('[OFFLINE] Room profanity filtering passed total='..assertions)

-- Turn feedback lifetime and one authoritative pass sound.
do
 local ui=LexioPlayUIController.new()
 ui.ErrorText={TextGUIRendererComponent={Text='제출 완료'}}
 ui.GetLocalBridge=function() return {_T={Seat=1}} end
 local snap={tableId='feedback',phase='Playing',currentPlayerIndex=1,turnNumber=1,trickNumber=1}
 ui:ClearPreviousTurnMessage(snap)
 check(ui.ErrorText.TextGUIRendererComponent.Text=='','first local turn drops previous feedback')
 ui.ErrorText.TextGUIRendererComponent.Text='낼 수 없는 타일 조합입니다.'
 ui:ClearPreviousTurnMessage(snap)
 check(ui.ErrorText.TextGUIRendererComponent.Text~='','current-turn error remains readable')
 snap.currentPlayerIndex=2;snap.turnNumber=2;ui:ClearPreviousTurnMessage(snap)
 check(ui.ErrorText.TextGUIRendererComponent.Text~='','other turn does not repeatedly clear feedback')
 snap.currentPlayerIndex=1;snap.turnNumber=4;ui:ClearPreviousTurnMessage(snap)
 check(ui.ErrorText.TextGUIRendererComponent.Text=='','returning local turn clears old error')
 ui.ErrorText.TextGUIRendererComponent.Text='제출 완료';snap.tableId='new-room';ui:ClearPreviousTurnMessage(snap)
 check(ui.ErrorText.TextGUIRendererComponent.Text=='','new room does not inherit action feedback')
 local pass={Name='PassButton',ButtonComponent={},Children={},ConnectEvent=function() error('generic sound must not bind pass') end}
 ui:BindButtonSounds(pass)
 check(ui._T.ButtonSoundConnections[pass]==nil,'pass has no generic click sound')
 ui._T.PresentationEnabled=true;ui._T.PresentationRoom='pass-audio';ui._T.PresentationPhase='Playing';ui._T.PresentationVersion=1
 local sounds={};ui.PlayFeedback=function(self,kind) sounds[#sounds+1]=kind end
 local state={tableId='pass-audio',stateVersion=2,phase='Playing',currentPlayerIndex=2,turnNumber=2,trickNumber=1,lastPlay={},passed={[2]=true,[3]=true}}
 ui:PresentSnapshot(state)
 check(#sounds==1 and sounds[1]=='Pass','one sound for pass state update')
 state.stateVersion=3;ui:PresentSnapshot(state)
 check(#sounds==1,'repeated snapshot does not replay pass')
 state.passed[4]=true;state.stateVersion=4;ui:PresentSnapshot(state)
 check(#sounds==2,'later distinct pass plays once')
end
log('[OFFLINE] Turn-message and pass-audio regression passed total='..assertions)
