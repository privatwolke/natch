'use strict';

/**
 * @ngdoc overview
 * @name natchApp
 * @description
 * # natchApp
 *
 * Main module of the application.
 */
var app = angular.module('natchApp', ['ngAnimate', 'ngTouch', 'onsen']);
var favourites = [{name: "Testname 1"}, {name: "Testname 2"}];

app.controller('VoterController', ["$scope", "$timeout", "$db", function($scope, $timeout, $db) {

  var names = [];
  var init = function() {
    names = (names.length === 0) ? $db.query().sort($db.sortDescending("name")) : names;
  };

  $scope.name = {"name":"Drag to get started!"};
  $scope.gone = {"left": false, "right": false, "down": false};

  var messages = {
    "left": "Liked",
    "right": "Maybe",
    "down": "Removed"
  };

  $scope.tearOff = function(direction) {
    init();
    if ($scope.name !== "Drag to get started!" && direction == "left") {
      favourites.push($scope.name);
    }
    $scope.message = messages[direction];
    $scope.$apply(function($scope) { $scope.gone[direction] = true; });
    $timeout(function() {
      $scope.name = names.pop();
      $scope.$apply(function($scope) { $scope.gone[direction] = false; });
    }, 500);
  };
}]);

app.directive("natchVoter", function() {
  return {
    restrict: "E",
    templateUrl: "templates/voter.html",
    controller: "VoterController",
    controllerAs: "voterCtrl"
  };
});

app.directive("natchNotificationArea", function() {
  return {
    restrict: "E",
    templateUrl: "notification.html",
    scope: {
      message: "=",
      icon: "="
    }
  };
});


app.controller('FavouritesController', ["$scope", "$timeout", "$db", function($scope, $timeout, $db) {
  $scope.favourites = favourites.sort($db.sortAscending("name"));
}]);

app.directive("natchFavourites", function() {
  return {
    restrict: "E",
    templateUrl: "templates/favourites.html",
    controller: "FavouritesController",
    controllerAs: "favouritesCtrl"
  };
});


app.factory("$db", ["$http", function($http) {
  var instance = new Object();
  var asyncLoading = false;
  var names, settings;

  if(!localStorage["settings"]) localStorage["settings"] = "{}";
  if(!localStorage["names"]) {
    asyncLoading = true;
    $http.get("namen.json").success(function(data, status, headers, config) {
      names = data;
      localStorage["names"] = JSON.stringify(data["content"]);
      asyncLoading = false;
    }).error(function(data, status, headers, config) {
      asyncLoading = false;
    });
  }

  settings = JSON.parse(localStorage["settings"]);
  names = asyncLoading ? [] : JSON.parse(localStorage["names"]);

  instance.getPreference = function(name) {
    return settings[name];
  };

  instance.setPreference = function(name, value) {
    settings[name] = value;
    localStorage["settings"] = JSON.stringify(settings);
  };

  instance.query = function(filter) {
    var result = [];
    for (var i = 0, j = names.length; i < j; i++) {
      var row = names[i];
      if (!filter || filter(row)) result.push(row);
    }

    return result;
  };

  instance.sortAscending = function(key) {
    return function(a, b) {
      return (a["name"] < b["name"]) ? -1 : 1;
    };
  };

  instance.sortDescending = function(key) {
    return function(a, b) {
      return (a["name"] < b["name"]) ? 1 : -1;
    };
  };

  return instance;
}]);
