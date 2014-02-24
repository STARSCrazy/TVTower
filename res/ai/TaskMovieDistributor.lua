-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
TaskMovieDistributor = AITask:new{
	MoviesAtDistributor = nil;
	NiveauChecked = false;
	MovieCount = 0;
	CheckMode = 0;
	BudgetWeigth = 7;
	BasePriority = 8;
	MovieList = nil;
	TargetRoom = TVT.ROOM_MOVIEAGENCY;
	CheckMoviesJob = nil;
	AppraiseMovies = nil;
	CurrentBargainBudget = 0
}

function TaskMovieDistributor:typename()
	return "TaskMovieDistributor"
end

function TaskMovieDistributor:Activate()
	debugMsg(">>> Starte Task 'TaskMovieDistributor'")

	-- Was getan werden soll:
	self.CheckMoviesJob = JobCheckMovies:new()
	self.CheckMoviesJob.MovieDistributorTask = self

	self.AppraiseMovies = JobAppraiseMovies:new()
	self.AppraiseMovies.MovieDistributorTask = self

	self.BuyMovies = JobBuyMovies:new()
	self.BuyMovies.MovieDistributorTask = self

	self.MoviesAtDistributor = {}
end

function TaskMovieDistributor:GetNextJobInTargetRoom()
	if (self.CheckMoviesJob.Status ~= JOB_STATUS_DONE) then
		return self.CheckMoviesJob
	elseif (self.AppraiseMovies.Status ~= JOB_STATUS_DONE) then
		return self.AppraiseMovies
	elseif (self.BuyMovies.Status ~= JOB_STATUS_DONE) then
		return self.BuyMovies
	end

	self:SetWait()
end

function AITask:OnDayBegins()
	self.CurrentBargainBudget = self.BudgetWholeDay / 2 -- Tagesbudget f�r gute Angebote ohne konkreten Bedarf
end
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
JobCheckMovies = AIJob:new{
	CurrentMovieIndex = 0;
	MovieDistributorTask = nil
}

function JobCheckMovies:typename()
	return "JobCheckMovies"
end

function JobCheckMovies:Prepare(pParams)
	debugMsg("Schaue Filmangebot an")
	self.CurrentMovieIndex = 0
end

function JobCheckMovies:Tick()
	while self.Status ~= JOB_STATUS_DONE do
		self:CheckMovie()
	end
end

function JobCheckMovies:CheckMovie()
	local response = TVT.md_getProgrammeLicence(self.CurrentMovieIndex)
	if ((response.result == TVT.RESULT_WRONGROOM) or (response.result == TVT.RESULT_NOTFOUND)) then
		self.Status = JOB_STATUS_DONE
		return
	end

	local licence = TVT.convertToProgrammeLicence(response.data)
	local player = _G["globalPlayer"]
	self.MovieDistributorTask.MoviesAtDistributor[self.CurrentMovieIndex] = licence

	player.Stats:AddMovie(licence)

	self.CurrentMovieIndex = self.CurrentMovieIndex + 1
end
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
JobAppraiseMovies = AIJob:new{
	CurrentMovieIndex = 0;
	MovieDistributorTask = nil;

	MovieMaxPrice = -1;
	PrimetimeMovieMinQuality = -1;
	DayMovieMinQuality = -1;

	SeriesMaxPrice = -1;
	PrimetimeSeriesMinQuality = -1;
	DaySeriesMinQuality = -1
}

function JobAppraiseMovies:typename()
	return "JobAppraiseMovies"
end

function JobAppraiseMovies:Prepare(pParams)
	debugMsg("Bewerte/Vergleiche Filme")
	self.CurrentMovieIndex = 0
	self:AdjustMovieNiveau()
end

function JobAppraiseMovies:Tick()
	while self.Status ~= JOB_STATUS_DONE do
		self:AppraiseCurrentMovie()
	end
end

function JobAppraiseMovies:AdjustMovieNiveau()
	local player = _G["globalPlayer"]
	local stats = player.Stats
	local movieBudget = self.MovieDistributorTask.BudgetWholeDay
	local maxPrice = movieBudget / 2;

	local maxQualityMovies = stats.MovieQualityAcceptable.MaxValue;
	local minQualityMovies = stats.MovieQualityAcceptable.MinValue;
	local maxQualitySeries = stats.SeriesQualityAcceptable.MaxValue;
	local minQualitySeries = stats.SeriesQualityAcceptable.MinValue;

	self.MovieMaxPrice = maxPrice
	self.SeriesMaxPrice = maxPrice

	local ScopeMovies = maxQualityMovies - minQualityMovies
	self.PrimetimeMovieMinQuality = math.round(minQualityMovies + (ScopeMovies * 0.75))
	self.DayMovieMinQuality = math.round(minQualityMovies + (ScopeMovies * 0.4))

	local ScopeSeries = maxQualitySeries - minQualitySeries
	self.PrimetimeSeriesMinQuality = math.round(minQualitySeries + (ScopeSeries * 0.75))
	self.DaySeriesMinQuality = math.round(minQualitySeries + (ScopeSeries * 0.4))
end

function JobAppraiseMovies:AppraiseCurrentMovie()
	local movie = self.MovieDistributorTask.MoviesAtDistributor[self.CurrentMovieIndex]
	if (movie ~= nil) then
		self:AppraiseMovie(movie)
		self.CurrentMovieIndex = self.CurrentMovieIndex + 1
	else
		self.Status = JOB_STATUS_DONE
	end
end

function JobAppraiseMovies:AppraiseMovie(licence)
	local player = _G["globalPlayer"]
	local stats = player.Stats
	local pricePerBlockStats = nil
	local qualityStats = nil
--RON
--TVT.PrintOut("RON: AppraiseMovie")
	--Allgemeine Minimalvorraussetzungen erf�llt?
	if (licence.IsMovie()) then
		if (CheckMovieBuyConditions(licence, self.MovieMaxPrice, self.DayMovieMinQuality)) then
			pricePerBlockStats = stats.MoviePricePerBlockAcceptable
			qualityStats = stats.MovieQualityAcceptable
		else
			return
		end
	else
		if (CheckMovieBuyConditions(licence, self.SeriesMaxPrice, self.DaySeriesMinQuality)) then
			pricePerBlockStats = stats.SeriesPricePerBlockAcceptable
			qualityStats = stats.SeriesQualityAcceptable
		else
			return
		end
	end

	-- Je g�nstiger desto besser
	local financeFactor = licence:GetPricePerBlock() / pricePerBlockStats.AverageValue
	financeFactor = CutFactor(financeFactor, 0.2, 2)
	--debugMsg("licence.GetPricePerBlock: " .. licence.GetPricePerBlock() .. " ; pricePerBlockStats.AverageValue: " .. pricePerBlockStats.AverageValue)

	-- Je qualitativ hochwertiger desto besser	
	local qualityFactor = licence.GetQuality(0) / qualityStats.AverageValue
	qualityFactor = CutFactor(qualityFactor, 0.2, 2)
	--debugMsg("licence.Quality: " .. licence.Quality .. " ; qualityStats.AverageValue: " .. qualityStats.AverageValue)
	licence.SetAttractiveness(financeFactor * qualityFactor)
	--debugMsg("MovieLicence-Attractiveness: ===== " .. licence.GetAttractiveness() .. " ===== ; financeFactor: " .. financeFactor .. " ; qualityFactor: " .. qualityFactor)
end
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
JobBuyMovies = AIJob:new{
	MovieDistributorTask = nil;
}

function JobBuyMovies:typename()
	return "JobBuyMovies"
end

function JobBuyMovies:Prepare(pParams)
	debugMsg("Kaufe Filme")
	--debugMsg("CurrentBudget: " .. self.MovieDistributorTask.CurrentBudget .. " - CurrentBargainBudget: " .. self.MovieDistributorTask.CurrentBargainBudget)

	local sortMethod = function(a, b)
		return a.GetAttractiveness() > b.GetAttractiveness()
	end
	table.sort(self.MovieDistributorTask.MoviesAtDistributor, sortMethod)
end

function JobBuyMovies:Tick()
	local movies = self.MovieDistributorTask.MoviesAtDistributor

	--TODO: Pr�fen wie viele Filme �berhaupt gebraucht werden

	for k,v in pairs(movies) do
		if (v:GetPrice() <= self.MovieDistributorTask.CurrentBudget) then
			if (v:GetPrice() <= self.MovieDistributorTask.CurrentBargainBudget) then -- Tagesbudget f�r gute Angebote ohne konkreten Bedarf
				if (v.GetAttractiveness() > 1) then
					--debugMsg("Kaufe Film: " .. v.GetId() .. " - Attraktivit�t: ".. v.GetAttractiveness() .. " - Preis: " .. v:GetPrice() .. " - Qualit�t: " .. v.GetQuality(0))
					debugMsg("Kaufe Film: " .. v.GetTitle() .. " (" .. v.GetId() .. ") - Preis: " .. v:GetPrice())
					TVT.md_doBuyProgrammeLicence(v.GetId())
					self.MovieDistributorTask.CurrentBudget = self.MovieDistributorTask.CurrentBudget - v:GetPrice()
					self.MovieDistributorTask.CurrentBargainBudget = self.MovieDistributorTask.CurrentBargainBudget - v:GetPrice()
				end
			end
		end
	end

	self.Status = JOB_STATUS_DONE
end
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<