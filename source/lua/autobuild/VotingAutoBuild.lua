local kExecuteVoteDelay = 5

RegisterVoteType("VoteResetGame", { })

if Client then

    local function SetupResetGameVote(voteMenu)
    
        local function StartResetGameVote(data)
            AttemptToStartVote("VoteResetGame", { })
        end
        
        voteMenu:AddMainMenuOption(Locale.ResolveString("VOTE_RESET_GAME"), nil, StartResetGameVote)
        
        -- This function translates the networked data into a question to display to the player for voting.
        local function GetVoteResetGameQuery(data)
            return Locale.ResolveString("VOTE_RESET_GAME_QUERY")
        end
        AddVoteStartListener("VoteResetGame", GetVoteResetGameQuery)
        
    end
    AddVoteSetupCallback(SetupResetGameVote)
    
end

if Server then

    local function OnResetGameVoteSuccessful(data)
        GetGamerules():ResetGame()
    end
    SetVoteSuccessfulCallback("VoteResetGame", kExecuteVoteDelay, OnResetGameVoteSuccessful)
    
end