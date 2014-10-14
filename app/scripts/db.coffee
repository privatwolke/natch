class window.Database
	constructor: (@options = {}) ->
		# default options
		@options.prefix  = @options.prefix  ? "__COLLECTION__"
		@options.persist = @options.persist ? true

		@data = {}

		for key of localStorage
			if key[0 .. @options.prefix.length - 1] is @options.prefix
				collection = JSON.parse(localStorage[key])
				@data[key[@options.prefix.length .. key.length]] = collection


	collection: (name) ->
		new Collection(name, @)


	collections: ->
		result = {}
		for key of @data
			result[key] = new Collection(key, @)
		return result


	drop: (collectionName) ->
		delete @data[collectionName]
		localStorage.removeItem(@options.prefix + collectionName)


	commit: (collectionName) ->
		if @options.persist
			collection = JSON.stringify(@data[collectionName])
			localStorage[@options.prefix + collectionName] = collection

		return true



class window.Collection
	constructor: (@name, @database) ->
		# create the collection if it does not exist
		if not @database.data[@name]
			@database.data[@name] =
				id: 0
				indices: {}
				records: {}

		@indices = {}
		for i of @database.data[@name].indices
			@indices[i] = new Index(@database, @name, i)


	id: ->
		++@database.data[@name].id


	commit: ->
		@database.commit(@name)


	all: ->
		result = []
		for id, record of @database.data[@name].records
			result.push("id": id, "record": DBUtils.clone(@database.data[@name].records[id]))

		new RecordSet(result)


	index: (indexSpec) ->
		@indices[indexSpec] = new Index(@database, @name, indexSpec)


	# attention when writing funcFilter(key) -- argument is ALWAYS a string
	query: (indexSpec, funcFilter) ->
		index = @database.data[@name].indices[indexSpec]
		records = []
		for key of index
			if funcFilter(key)
				for id in index[key]
					records.push("id": id, "record": DBUtils.clone(@database.data[@name].records[id]))

		return new RecordSet(records)


	filter: (funcFilter) ->
		new RecordSet(@all()).filter(funcFilter)


	sort: (funcFilter) ->
		new RecordSet(@all()).sort(funcSort)


	add: (record) ->
		id = @id()
		@database.data[@name].records[id] = DBUtils.clone(record)

		# update all indices
		for indexSpec of @indices
			@indices[indexSpec].add(id, record)

		# commit the changes to localStorage
		@commit()

		return id


	update: (id, record) ->
		# update all indices
		for indexSpec of @indices
			@indices[indexSpec].remove(id)
			@indices[indexSpec].add(id, record)

		@database.data[@name].records[id] = DBUtils.clone(record)

		# commit the changes to localStorage
		@commit()

		return id


	remove: (id) ->
		# update indices
		for index of @indices
			@indices[index].remove(id)

		# remove from the datastore
		delete @database.data[@name].records[id]

		# commit the changes to localStorage
		@commit()

		return true



class window.Index
	constructor: (@database, @name, @indexSpec) ->
		if not @database.data[@name].indices[@indexSpec]
			@database.data[@name].indices[@indexSpec] = {}

			for id, record of @database.data[@name].records
				@add(id, record)


	value: (record) ->
		result = []
		for field in @indexSpec.split(",")
			if not field in record
				return null
			else
				result.push(record[field])

		return result.join(",")


	add: (id, record) ->
		value = @value(record)

		if value
			if @database.data[@name].indices[@indexSpec][value]
				@database.data[@name].indices[@indexSpec][value].push(id)
			else
				@database.data[@name].indices[@indexSpec][value] = [id]


	remove: (id) ->
		record = @database.data[@name].records[id]
		value = @value(record)
		index = @database.data[@name].indices[@indexSpec][value].indexOf(id)
		@database.data[@name].indices[@indexSpec][value].splice(index, 1)



class window.RecordSet
	constructor: (@records) ->

		@length = @records.length
		@cursor = 0


	next: ->
		@records[@cursor++]


	rewind: ->
		@cursor = 0


	seek: (pos) ->
		@cursor = pos


	limit: (num) ->
		new RecordSet(@records[0 .. num])


	# funcSort({"id": 0, "record": { ... }})
	sort: (funcSort) ->
		new RecordSet(@records.sort(funcSort))


	shuffle: ->
		# adapted from https://github.com/coolaj86/knuth-shuffle
		currentIndex = @records.length

		while currentIndex != 0
			randomIndex = Math.floor(Math.random() * currentIndex)
			currentIndex--

			temporaryValue = @records[currentIndex]
			@records[currentIndex] = @records[randomIndex]
			@records[randomIndex] = temporaryValue

		new RecordSet(@records)


	# funcFilter({"id": 0, "record": { ... }})
	filter: (funcFilter) ->
		filtered = []
		for record in @records
			if funcFilter(record)
				filtered.push(record)

		new RecordSet(filtered)



class window.DBUtils
	@clone: (record) ->
		target = {}
		for own key, value of record
			target[key] = value
		return target
