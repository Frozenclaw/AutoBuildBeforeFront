local kExecuteVoteDelay = 5

RegisterVoteType("VoteAutoBuild", { })

if Client then

    local function SetupAutoBuildVote(voteMenu)
    
        local function StartAutoBuildVote(data)
            AttemptToStartVote("VoteAutoBuild", { })
        end
        
        voteMenu:AddMainMenuOption(Locale.ResolveString("VOTE_AUTO_BUILD"), nil, StartAutoBuildVote)
        
        -- This function translates the networked data into a question to display to the player for voting.
        local function GetVoteAutoBuildQuery(data)
            return Locale.ResolveString("VOTE_AUTO_BUILD_QUERY")
        end
        AddVoteStartListener("VoteAutoBuild", GetVoteAutoBuildQuery)
        
    end
    AddVoteSetupCallback(SetupAutoBuildVote)
    
end

if Server then

    local function OnAutoBuildVoteSuccessful(data)
        Log("Vote Successful!")
    end
    SetVoteSuccessfulCallback("VoteAutoBuild", kExecuteVoteDelay, OnAutoBuildVoteSuccessful)
    
end