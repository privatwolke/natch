app = angular.module "natchApp", ["ngAnimate", "ngTouch", "onsen"]

favourites = [{name: "Testname 1"}, {name: "Testname 2"}]

app.controller "VoterController", [
	"$scope", "$timeout", "$db", ($scope, $timeout, $db) ->
		names = []
		init = ->
			names = if names.length is 0 then $db.query().sort($db.shuffle) else names

		$scope.name =  name: "Drag to get started!"
		$scope.gone =  left: false, down: false

		messages = left: "Liked", down: "Removed"

		$scope.tearOff = (direction) ->
			init()
			if $scope.name["name"] is not "Drag to get started!"
				if direction is "left"
					favourites.push($scope.name)

				$scope.message = messages[direction]

			$scope.$apply(($scope) -> $scope.gone[direction] = true)
			$timeout(->
				$scope.name = names.pop()
				$scope.$apply(($scope) -> $scope.gone[direction] = false)
			, 500)
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
		$scope.favourites = favourites.sort($db.sortAscending("name"))
	]

app.directive "natchFavourites", ->
	restrict:     "E",
	templateUrl:  "templates/favourites.html",
	controller:   "FavouritesController",
	controllerAs: "favouritesCtrl"


app.factory "$db", ["$http", ($http) ->
	return Database
]
