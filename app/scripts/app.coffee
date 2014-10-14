app = angular.module "natchApp", ["ngAnimate", "ngTouch", "onsen"]

favourites = [{name: "Testname 1"}, {name: "Testname 2"}]

app.controller "VoterController", [
	"$scope", "$timeout", "$http", "$db", ($scope, $timeout, $http, $db) ->

		status =
			UNRATED:  "0"
			LIKED:    "1"
			DISLIKED: "2"

		$scope.name = "Loading…"
		$scope.gone =  left: false, down: false
		messages = left: "Liked", down: "Removed"

		window.namesCollection = $db.collection("names")

		run = ->
			names = namesCollection.query(
				"status",
				(key) -> key is status.UNRATED
			).shuffle()

			$scope.name = names.next()

			$scope.tearOff = (direction) ->
				if $scope.name["id"]
					$scope.name["record"]["status"] =
					  if direction is "left"
					    status.LIKED
					  else
					    status.DISLIKED

					namesCollection.update($scope.name["id"], $scope.name["record"])
					$scope.message = messages[direction]

				$scope.$apply(($scope) -> $scope.gone[direction] = true)
				$timeout(->
					$scope.name = names.next()
					$scope.$apply(($scope) -> $scope.gone[direction] = false)
				, 500)

		if namesCollection.all().length is 0
			# the collection is empty, create indices
			namesCollection.index("gender")
			namesCollection.index("status")
			namesCollection.index("gender,status")

			# fill the collection for the first time
			$http.get("namen.json").success((data, status, headers, config) ->
					for record in data.content
						record["status"] = 0
						namesCollection.add(record)

					run()
			).error((data, status, headers, config) ->
				console.log "Error during inital fill."
			)
		else
			run()
	]

app.directive "natchVoter", ->
	restrict:     "E"
	templateUrl:  "templates/voter.html"
	controller:   "VoterController"
	controllerAs: "voterCtrl"


app.directive "natchNotificationArea", ->
	restrict:    "E"
	templateUrl: "notification.html"
	scope:
		message: "="
		icon:    "="


app.controller "FavouritesController", [
	"$scope", "$timeout", "$db", ($scope, $timeout, $db) ->
		$scope.favourites = []
	]

app.directive "natchFavourites", ->
	restrict:     "E",
	templateUrl:  "templates/favourites.html",
	controller:   "FavouritesController",
	controllerAs: "favouritesCtrl"


app.factory "$db", -> new Database(persist: false)
