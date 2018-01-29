
if Server then 
	
	function NS2Gamerules:GetFrontAutoBuild()
		return self.isAutoBuildUntilFront
	end 

	function NS2Gamerules:SetFrontAutoBuild(autobuild)
		self.isAutoBuildUntilFront = autobuild
	end
	
	local ns2_ResetGame = NS2Gamerules.ResetGame
	function NS2Gamerules:ResetGame()
		self:SetFrontAutoBuild(false)
		ns2_ResetGame(self)
	end 

end
