local kExecuteVoteDelay = 5

RegisterVoteType("VoteAutoBuild", { })

if Client then

    local function SetupAutoBuildVote(voteMenu)
    
        local function StartAutoBuildVote(data)
            AttemptToStartVote("VoteAutoBuild", { })
        end
        
        voteMenu:AddMainMenuOption(Locale.ResolveString("AutoBuild Until Front"), nil, StartAutoBuildVote)
        
        -- This function translates the networked data into a question to display to the player for voting.
        local function GetVoteAutoBuildQuery(data)
            return Locale.ResolveString("Enable AutoBuild Until Front?")
        end
        AddVoteStartListener("VoteAutoBuild", GetVoteAutoBuildQuery)
        
    end
    AddVoteSetupCallback(SetupAutoBuildVote)
    
end

if Server then

    local function OnAutoBuildVoteSuccessful(data)
        GetGamerules():SetFrontAutoBuild(true) 
    end
    SetVoteSuccessfulCallback("VoteAutoBuild", kExecuteVoteDelay, OnAutoBuildVoteSuccessful)
    
end
