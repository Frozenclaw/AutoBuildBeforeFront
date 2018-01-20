
local kVoteExpireTime = 20
local kDefaultVoteExecuteTime = 30
local kNextVoteAllowedAfterTime = 50
-- How many seconds must pass before a client can start another vote of a certain type after a failed vote.
local kStartVoteAfterFailureLimit = 3 * 60

if Server then

    -- Allow reset between Countdown and kMaxTimeBeforeReset
    function VotingResetGameAllowed()
        local gameRules = GetGamerules()
        return gameRules:GetGameState() == kGameState.Countdown or (gameRules:GetGameStarted() and Shared.GetTime() - gameRules:GetGameStartTime() < kMaxTimeBeforeReset)
    end
    
	function VotingAutoBuildAllowed()
		local gameRules = GetGamerules()
		return gameRules:GetFrontDoorsOpen() == false and gameRules:GetGameStarted()
	end 
	
    local activeVoteName, activeVoteData, activeVoteResults, activeVoteStartedAtTime
    local activeVoteId = 0
    local lastVoteStartAtTime
    local lastTimeVoteResultsSent = 0
    local voteSuccessfulCallbacks = { }
    
    local startVoteHistory = { }
    
    function GetStartVoteAllowed(voteName, client)

        -- Check that there is no current vote.
        if activeVoteName then    
            return kVoteCannotStartReason.VoteInProgress
        end
        
        -- Check that enough time has passed since the last vote.
        if lastVoteStartAtTime and Shared.GetTime() - lastVoteStartAtTime < kNextVoteAllowedAfterTime then
            return kVoteCannotStartReason.Waiting
        end
        
        -- Check that this client hasn't started a failed vote of this type recently.
        if client then
            for v = #startVoteHistory, 1, -1 do

                local vote = startVoteHistory[v]
                if voteName == vote.type and client:GetUserId() == vote.client_id then

                    if not vote.succeeded and Shared.GetTime() - vote.start_time < kStartVoteAfterFailureLimit then
                        return kVoteCannotStartReason.Spam
                    end

                end

            end
        end
        
        local votingSettings = Server.GetConfigSetting("voting")
        if votingSettings and votingSettings[string.lower(voteName)] == false then
            return kVoteCannotStartReason.DisabledByAdmin
        end
        
        if voteName == "VoteResetGame" then
            if not VotingResetGameAllowed() then
                if GetGamerules():GetGameState() < kGameState.Countdown then
                    return kVoteCannotStartReason.TooEarly
                else
                    return kVoteCannotStartReason.TooLate
                end
            end
        end
		
		if voteName == "VoteAutoBuild" then
			if not VotingAutoBuildAllowed() then
				if GetGamerules():GetFrontDoorsOpen() == false and GetGamerules():GetGameStarted() == true then
					return kVoteCannotStartReason.TooLate 
				else
					return kVoteCannotStartReason.TooEarly
				end
			end
		end
		
        if voteName == "VoteAddCommanderBots" then
            if not VotingAddCommanderBotsAllowed() then
                return kVoteCannotStartReason.UnsupportedGamemode
            end
        end
        
        if voteName == "VotingForceEvenTeams" then
            if GetGamerules():GetGameStarted() then
                return kVoteCannotStartReason.GameInProgress
            end
        end
        
        return kVoteCannotStartReason.VoteAllowedToStart
        
    end
    
     function StartVote(voteName, client, data)
        
        local voteCanStart = GetStartVoteAllowed(voteName, client)
        if voteCanStart == kVoteCannotStartReason.VoteAllowedToStart then

            local clientId = client and client:GetId() or 0
        
            activeVoteId = activeVoteId + 1
            activeVoteName = voteName
            activeVoteResults = {
                voters = {},
                votes = {}
            }
            activeVoteStartedAtTime = Shared.GetTime()
            lastVoteStartAtTime = activeVoteStartedAtTime
            data.voteId = activeVoteId
            local now = Shared.GetTime()
            data.expireTime = now + kVoteExpireTime
            data.client_index = clientId
            Server.SendNetworkMessage(voteName, data)
            
            activeVoteData = data
            
            table.insert(startVoteHistory, { type = voteName, client_id = clientId, start_time = now, succeeded = false })
            
            Print("Started Vote: " .. voteName)
            
        elseif client then
            Server.SendNetworkMessage(client, "VoteCannotStart", { reason = voteCanStart }, true)
        end
        
    end
    
    function HookStartVote(voteName)
        
        local function OnStartVoteReceived(client, message)
            StartVote(voteName, client, message)
        end
        Server.HookNetworkMessage(voteName, OnStartVoteReceived)
        
    end
    
    function RegisterVoteType(voteName, voteData)
        
        assert(voteData.voteId == nil, "voteId field detected while registering a vote type")
        voteData.voteId = "integer"
        assert(voteData.expireTime == nil, "expireTime field detected while registering a vote type")
        voteData.expireTime = "time"
        assert(voteData.client_index == nil, "client_index field detected while registering a vote type")
        voteData.client_index = "integer"
        Shared.RegisterNetworkMessage(voteName, voteData)
        HookStartVote(voteName)
        
    end
    
    function SetVoteSuccessfulCallback(voteName, delayTime, callback)
    
        local voteSuccessfulCallback = { }
        voteSuccessfulCallback.delayTime = delayTime
        voteSuccessfulCallback.callback = callback
        voteSuccessfulCallbacks[voteName] = voteSuccessfulCallback
        
    end
    
    local function CountVotes(voteResults)
    
        local yes = 0
        local no = 0
        for i = 1, #voteResults.voters do

            local voter = voteResults.voters[i]
            local choice = voteResults.votes[voter]

            yes = (choice and yes + 1) or yes
            no = (not choice and no + 1) or no
            
        end
        
        return yes, no
        
    end
    
    local lastVoteSent = 0
    
    local function OnSendVote(client, message)
    
        if activeVoteName then
        
            local votingDone = Shared.GetTime() - activeVoteStartedAtTime >= kVoteExpireTime
            if not votingDone and message.voteId == activeVoteId then
                local clientId = client:GetUserId()
                if not activeVoteResults.votes[clientId] then
                    table.insert(activeVoteResults.voters, clientId)
                end

                activeVoteResults.votes[clientId] = message.choice
                lastVoteSent = Shared.GetTime()
            end
            
        end
        
    end
    Server.HookNetworkMessage("SendVote", OnSendVote)
    
    local function GetNumVotingPlayers()
        return Server.GetNumPlayers() - #gServerBots
    end
        
    local function GetVotePassed(yesVotes, noVotes)
        return yesVotes > (GetNumVotingPlayers() / 2)
    end
    
    local function OnUpdateVoting(dt)
    
        if activeVoteName then
        
            local yes, no = CountVotes(activeVoteResults)
            local required = math.floor(GetNumVotingPlayers() / 2) + 1
            local voteSuccessful = GetVotePassed(yes, no)
            local voteFailed = no >= math.floor(GetNumVotingPlayers() / 2) + 1
        
            if Shared.GetTime() - lastTimeVoteResultsSent > 1 then
            
                local voteState = kVoteState.InProgress
                
                local votingDone = Shared.GetTime() - activeVoteStartedAtTime >= kVoteExpireTime or voteSuccessful or voteFailed
                if votingDone then
                    voteState = voteSuccessful and kVoteState.Passed or kVoteState.Failed
                end
                
                Server.SendNetworkMessage("VoteResults", { voteId = activeVoteId, yesVotes = yes, noVotes = no, state = voteState, requiredVotes = required }, true)
                lastTimeVoteResultsSent = Shared.GetTime()
                
            end
            
            local voteSuccessfulCallback = voteSuccessfulCallbacks[activeVoteName]
            local delay = (voteSuccessfulCallback and (kVoteExpireTime + voteSuccessfulCallback.delayTime)) or kDefaultVoteExecuteTime
            
            if voteSuccessful then
                delay = lastVoteSent - activeVoteStartedAtTime + voteSuccessfulCallback.delayTime
            end
            if Shared.GetTime() - activeVoteStartedAtTime >= delay then
            
                Server.SendNetworkMessage("VoteComplete", { voteId = activeVoteId }, true)
                
                local yes, no = CountVotes(activeVoteResults)
                local voteSuccessful = GetVotePassed(yes, no)
                startVoteHistory[#startVoteHistory].succeeded = voteSuccessful
                Print("Vote Complete: " .. activeVoteName .. ". Successful? " .. (voteSuccessful and "Yes" or "No"))
                
                if voteSuccessfulCallback and voteSuccessful then
                    voteSuccessfulCallback.callback(activeVoteData)
                end
                
                activeVoteName = nil
                activeVoteData = nil
                activeVoteResults = nil
                activeVoteStartedAtTime = nil
                
            end
            
        end
        
    end
    Event.Hook("UpdateServer", OnUpdateVoting)
    
end

Script.Load("lua/autobuild/VotingAutoBuild.lua")
