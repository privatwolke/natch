app = angular.module "natchApp", ["ngAnimate", "ngTouch", "onsen"]

app.controller "AppController", [
	"$scope", "$http", "$db", ($scope, $http, $db) ->
		prefs = $db.collection("preferences")

		$scope.show_prefs = -> ons.createDialog("connect.html").then((dialog) -> dialog.show())

		run = ->
			$scope.preferences = {}
			pp = prefs.all()
			while p = pp.next()
				$scope.preferences[p.record.name] = p.record.value

		if prefs.all().length is 0

			name = window.prompt("Wie ist dein Name?")

			# register user
			$http.post(
				"http://www.breibox.at/natch/api/user",
				"fb_userid=0absab&fb_token=0sdfbsd",
				headers:
					"Content-Type": "application/x-www-form-urlencoded"
			).success((data, status, headers, config) ->
				prefs.add(
					name: "user_token"
					value: data.token
				)
				prefs.add(
					name: "user_fbuserid"
					value: data.fb_userid
				)
				prefs.add(
					name: "user_fbtoken"
					value: data.fb_token
				)

				prefs.add(
					name: "user_name"
					value: name
				)
				run()
			)
		else:
			run()
	]

app.controller "ConnectController", [
	"$scope", "$timeout", "$http", "$db", ($scope, $timeout, $http, $db) ->
		$scope.connection =
			active: false
			code: "..."

		$scope.inputCode = ""
		token = $scope.preferences.user_token

		$scope.prefs =
			male: true,
			female: true
			maxlength: 100

		$http.get("http://www.breibox.at/natch/api/connection",
			params:
				token: token
		).success((data, status, headers, config) ->
			$scope.connection.active = true
			$scope.connection.name = data.fb_userid
		).error((data, status, headers, config) ->
			$scope.connection.active = false

			$http.get("http://www.breibox.at/natch/api/code",
				params:
					token: token
			).success((data, status, headers, config) ->
				$scope.connection.code = data.code
				$scope.connection.codeValidUntil = data.validUntil
			)

		)

		$scope.doConnect = ->
			$http.post(
				"http://www.breibox.at/natch/api/connection",
				"code=#{$scope.inputCode}",
				headers:
					"Content-Type": "application/x-www-form-urlencoded"
				params:
					token: token
			).success((data, status, headers, config) ->
					$scope.connection.active = true
			)

		$scope.removeConnection = ->
			$scope.connection.active = false
			$http.delete(
				"http://www.breibox.at/natch/api/connection",
				params:
					token: token
			).success((data, status, headers, config) ->
					$scope.connection.active = false
			)

	]

app.directive "natchConnect", ->
	restrict:     "E"
	templateUrl:  "templates/connect.html"
	controller:   "ConnectController"
	controllerAs: "connectCtrl"


app.controller "VoterController", [
	"$scope", "$timeout", "$http", "$db", ($scope, $timeout, $http, $db) ->

		status =
			UNRATED:  "0"
			LIKED:    "1"
			DISLIKED: "2"
			REMOVED:  "3"

		$scope.name = record : name: "Loading…"
		$scope.gone =  left: false, down: false, right: false
		messages = left: "Disliked", down: "Removed", right: "Liked"

		window.namesCollection = $db.collection("names")

		run = ->
			names = namesCollection.query(
				"status",
				(key) -> key is status.UNRATED
			).shuffle()

			$scope.name = names.next()
			$scope.name.record.likes = Math.floor(Math.random()*150)

			$scope.tearOff = (direction, fromswipe = false) ->
				if $scope.name["id"]
					  if direction is "right"
					    newStatus = status.LIKED
							# report back to server
							$http.post(
								"http://www.breibox.at/natch/api/like",
								"nameid=#{$scope.name['id']}",
								params:
									token: $scope.preferences.user_token
								headers:
									"Content-Type": "application/x-www-form-urlencoded"
							).success((data, status, headers, config) -> console.log data)

						else if direction is "left"
					    newStatus = status.DISLIKED

						else if direction is "down"
							newStatus = status.REMOVED

					$scope.name["record"]["status"] = newStatus

					namesCollection.update($scope.name)
					$scope.message = messages[direction]

				if fromswipe
					$scope.$apply(($scope) -> $scope.gone[direction] = true)
					$timeout(->
						$scope.name = names.next()
						$scope.name.record.likes = Math.floor(Math.random()*150)
						$scope.$apply(($scope) -> $scope.gone[direction] = false)
					, 500)
				else
					$scope.name = names.next()
					$scope.name.record.likes = Math.floor(Math.random()*150)

		if namesCollection.all().length is 0
			# the collection is empty, create indices
			namesCollection.index("gender")
			namesCollection.index("status")
			namesCollection.index("gender,status")

			# fill the collection for the first time
			$http.get("namen.json").success((data, status, headers, config) ->
					for record in data.content
						record["status"] = "0"
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
		namesCollection = $db.collection("names")
		$scope.favourites = namesCollection.query(
			"status",
			(key) -> key is "1"
		).sort(DatabaseFunctions.sortAscending("name")).list()

		$scope.remove = (record) ->
			index = $scope.favourites.indexOf(record)
			record.record["status"] = "2"
			namesCollection.update(record)

			$scope.favourites.splice(index, 1)

		$scope.isGone = (record) ->
			return $scope.favourites.indexOf(record) != -1

	]

app.directive "natchFavourites", ->
	restrict:     "E",
	templateUrl:  "templates/favourites.html",
	controller:   "FavouritesController",
	controllerAs: "favouritesCtrl"


app.factory "$db", -> new Database(persist: true)
