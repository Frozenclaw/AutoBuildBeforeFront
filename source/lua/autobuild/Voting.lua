if Server then
  -- Define your vote allowed function
  function VotingAutoBuildAllowed()
    local gameRules = GetGamerules()
    return gameRules:GetFrontDoorsOpen() == false and gameRules:GetGameStarted()
  end

  -- Save old GetStartVoteAllowed because of overuse of local variables
  -- and no hook for modders
  local ns2_GetStartVoteAllowed = GetStartVoteAllowed
  function GetStartVoteAllowed(voteName, client)
    -- Call the original code and grab the reason
    local originalReason = ns2_GetStartVoteAllowed(voteName, client)
    -- If no other error has returned (ie.kVoteCannotStartReason.Spam)
    if originalReason == kVoteCannotStartReason.VoteAllowedToStart then
      -- Check for your custom vote and perform the required logic
      if voteName == "VoteAutoBuild" then
  			if not VotingAutoBuildAllowed() then
  				if GetGamerules():GetFrontDoorsOpen() == true and GetGamerules():GetGameStarted() == true then
  					return kVoteCannotStartReason.TooLate
  				else
  					return kVoteCannotStartReason.TooEarly
  				end
  			end
      end
		end
    -- Return the original reason code if the custom logic isn't run
    return originalReason
  end
end

Script.Load("lua/autobuild/VotingAutoBuild.lua")
