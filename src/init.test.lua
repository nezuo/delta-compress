local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeltaCompress = require(script.Parent)
local RemotePacketSizeCounter = require(ReplicatedStorage.DevPackages.RemotePacketSizeCounter)

local function deepCopy(original)
	if typeof(original) ~= "table" then
		return original
	end

	local copy = {}

	for key, value in original do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, value in a do
		if not deepEqual(b[key], value) then
			return false
		end
	end

	for key, value in b do
		if not deepEqual(a[key], value) then
			return false
		end
	end

	return true
end

local function assertDeepEqual(a, b, message)
	assert(deepEqual(a, b), message)
end

local function freezeIfTable(x)
	if typeof(x) == "table" then
		if not table.isfrozen(x) then
			table.freeze(x)
		end

		for _, value in x do
			freezeIfTable(value)
		end
	end
end

local function checkInner(old, new, immutable, debug)
	if immutable then
		-- The diff and apply functions should not modify their arguments.
		freezeIfTable(old)
		freezeIfTable(new)
	end

	local diff = DeltaCompress.diffImmutable(old, new)

	-- print(RemotePacketSizeCounter.GetDataByteSize(new), "->", buffer.len(diff))

	assert(diff ~= nil, "diff was nil")

	local applied = if immutable then DeltaCompress.applyImmutable(old, diff) else DeltaCompress.applyMutable(old, diff)

	if not immutable and typeof(old) == "table" and typeof(new) == "table" then
		assert(old == applied, "old is not equal to applied")
	end

	if debug then
		print("Applied =", applied)
	end

	if typeof(new) == "CFrame" then
		assert(new:FuzzyEq(applied))
		return
	end

	-- new is deep copied to make sure the test doesn't pass because applied and new are the same table.
	new = if typeof(new) == "table" then deepCopy(new) else new

	assertDeepEqual(applied, new, "applied not equal")
end

local function check(old, new, debug)
	checkInner(deepCopy(old), deepCopy(new), true, debug)
	checkInner(deepCopy(old), deepCopy(new), false, debug)
end

local function checkMutable(old, new, debug)
	local oldOld = deepCopy(old)

	freezeIfTable(new)

	local diff, newOld = DeltaCompress.diffMutable(old, new)

	assert(diff ~= nil, "diff was nil")

	local applied = DeltaCompress.applyImmutable(oldOld, diff)

	if debug then
		print("Applied =", applied)
	end

	assertDeepEqual(newOld, new, "newOld and new not equal")

	assertDeepEqual(applied, new, "applied not equal")

	if typeof(new) == "table" then
		assert(old ~= new, "old and new are the same table")

		local function checkForSameTable(nestedOld, nestedNew)
			for key, value in nestedNew do
				if type(value) == "table" then
					assert(nestedOld[key] ~= value, "old and new have a same table")
					checkForSameTable(nestedOld[key], value)
				end
			end
		end

		checkForSameTable(newOld, new)
	end
end

return function(x)
	local assertEqual = x.assertEqual

	x.test("number to bool", function()
		check(100, true)
	end)

	x.test("vector types", function()
		check(nil, Vector2.new(2.5, 30.1))
		check(nil, Vector3.new(2.5, 30.1, 204.3))
		check(nil, Vector2int16.new(3.4, 9.2))
		check(nil, Vector3int16.new(3.4, 9.2, 30.3))
	end)

	x.test("cframe", function()
		check(nil, CFrame.identity)
		check(nil, CFrame.lookAt(Vector3.new(20, 40, 3290), Vector3.new(1, 2, 3)))
	end)

	x.test("number to empty string", function()
		check(100, "")
	end)

	x.test("number to number", function()
		check(100, 120)
	end)

	x.test("bool to array", function()
		local new = { 1, 2, 3 }

		check(true, new)
	end)

	x.test("bool to dictionary", function()
		local new = { coins = 3 }

		check(true, new)
	end)

	x.test("dictionary to bool", function()
		check({ coins = 3 }, true)
	end)

	x.test("array to bool", function()
		check({ 1, 2, 3 }, false)
	end)

	x.test("bool to empty table", function()
		check(false, {})
	end)

	x.test("non-table to table with arrays/dictionaries", function()
		check(false, { "a", 2, {}, { "a", "b", "c" }, { a = "1", b = "2", c = "3" } })
		check(false, { one = "a", two = 2, three = {}, four = { "a", "b", "c" }, five = { a = "1", b = "2", c = "3" } })
	end)

	x.nested("dictionary", function()
		x.test("to empty", function()
			check({ a = "one", b = "two", c = "three" }, {})
		end)

		x.test("no changes", function()
			local diff = DeltaCompress.diffImmutable({ foo = true }, { foo = true })

			assertEqual(diff, nil)
		end)

		x.test("removal", function()
			check({ remove = "remove" }, {})
		end)

		x.test("addition", function()
			check({}, { addition = true })
		end)

		x.test("change", function()
			check({ change = 5 }, { change = 10 })
		end)

		x.test("removal + addition + change", function()
			local old = { remove = "remove", change = 5, noChange = true }
			local new = { change = 10, addition = true, noChange = true }

			check(old, new)
		end)

		x.test("nested dictionary", function()
			local old = { nested = { noChange = true, change = 5, remove = true } }
			local new = { nested = { noChange = true, change = 10 } }

			check(old, new)
		end)

		x.test("nested dictionary no removals", function()
			local old = {
				stats = {
					deaths = 5,
					kills = 0,
				},
			}
			local new = {
				stats = {
					deaths = 5,
					kills = 1,
				},
			}

			check(old, new)
		end)

		x.test("nested array", function()
			local old = { nested = { 1, 2, 3 } }
			local new = { nested = { 2, 1 } }

			check(old, new)
		end)
	end)

	x.nested("array", function()
		x.test("to empty", function()
			check({ "one", "two", "three" }, {})
		end)

		x.test("no changes", function()
			local diff = DeltaCompress.diffImmutable({ "one", "two", "three" }, { "one", "two", "three" })

			assertEqual(diff, nil)
		end)

		x.test("removal", function()
			check({ "one", "two", "three" }, { "one", "two" })
		end)

		x.test("addition", function()
			check({ "one", "two" }, { "one", "two", "three" })
		end)

		x.test("change", function()
			check({ "same", "change" }, { "same", "different" })
		end)

		x.test("addition + change", function()
			check({ "same", "change" }, { "same", "different", "addition" })
		end)

		x.test("removal + change", function()
			check({ "same", "change", "remove" }, { "same", "different" })
		end)

		x.test("array and dictionary inside array", function()
			local old = {
				{ "same", "change" },
				{ foo = true, noChange = true },
				{},
			}
			local new = {
				{ "same", "different", "addition" },
				{ foo = false, noChange = true },
			}

			check(old, new)
		end)
	end)

	x.nested("array to dictionary", function()
		x.test("normal", function()
			local old = { 1, 2, 3 }
			local new = { coins = 3 }

			check(old, new)
		end)

		x.test("nested in array", function()
			local old = { { 1, 2, 3 } }
			local new = { { coins = 3 } }

			check(old, new)
		end)

		x.test("nested in dictionary", function()
			local old = { foo = { 1, 2, 3 } }
			local new = { foo = { coins = 3 } }

			check(old, new)
		end)
	end)

	x.nested("dictionary to array", function()
		x.test("normal", function()
			local old = { coins = 3 }
			local new = { 1, 2, 3 }

			check(old, new)
		end)

		x.test("nested in array", function()
			local old = { { coins = 3 } }
			local new = { { 1, 2, 3 } }

			check(old, new)
		end)

		x.test("nested in dictionary", function()
			local old = { foo = { coins = 3 } }
			local new = { foo = { 1, 2, 3 } }

			check(old, new)
		end)
	end)

	x.test("array to nil", function()
		check({ 1 }, nil)
	end)

	x.test("dictionary to nil", function()
		check({ foo = true }, nil)
	end)

	x.test("bug case", function()
		local old = {
			stats = {
				globalStats = {
					secondsPlayed = 0,
				},
				mechStats = {},
			},
		}
		local new = {
			stats = {
				globalStats = {
					secondsPlayed = 299,
				},
				mechStats = {},
			},
		}

		check(old, new)
	end)

	x.test("shouldn't change unchanged table when applyImmutable", function()
		local old = {
			foo = {
				bar = true,
			},
			baz = {},
		}
		local new = {
			foo = {
				bar = false,
			},
			baz = {},
		}

		local diff = DeltaCompress.diffImmutable(old, new)

		local oldApplied = deepCopy(old)
		local newApplied = DeltaCompress.applyImmutable(oldApplied, diff)

		assertEqual(oldApplied ~= newApplied and oldApplied.foo ~= newApplied.foo, true)
		assertEqual(oldApplied.baz == newApplied.baz, true)
	end)

	x.test("diff size", function()
		local randomStrings = {
			"xvKqT",
			"LpUoN",
			"aRzYl",
			"cQwVo",
			"mJuTe",
			"gYbFi",
			"vCnLd",
			"tXoPm",
			"hBwGq",
			"dJkUl",
			"uRtYi",
			"zNwVp",
			"qAzLf",
			"eKcTr",
			"pMvJd",
			"oBwUk",
			"fXqLn",
			"iGyRp",
			"nZcVo",
			"lKjTm",
			"sQbFi",
			"jWvUd",
			"yRnLp",
			"kXoQt",
			"aMjYi",
			"vPzTl",
			"cBwUr",
			"hXjVn",
			"dQkPo",
			"gZyFm",
			"oKcTr",
			"mJvUp",
			"fQbLi",
			"iGwYt",
			"nXoPk",
			"lRzVm",
			"sYjTo",
			"kWbUr",
			"aQnXp",
			"vZjLf",
			"cKjTr",
			"hPzWm",
			"dXqBo",
			"gRkYn",
			"oJcUi",
			"mWvLp",
			"fTzYo",
			"iQnPk",
			"nKjVr",
			"lZgTm",
		}
		local old = {}
		for _, key in randomStrings do
			old[key] = math.random()
		end
		local new = table.clone(old)
		new[randomStrings[1]] = 4

		local diff = DeltaCompress.diffImmutable(old, new)

		local diffSize = RemotePacketSizeCounter.GetDataByteSize(diff)
		local newSize = RemotePacketSizeCounter.GetDataByteSize(new)

		assertEqual(diffSize == 20, true)
		assertEqual(newSize == 802, true)
	end)

	x.nested("diffMutable", function()
		x.test("no changes", function()
			local old = { foo = true }
			local copied = deepCopy(old)

			local diff, updatedOld = DeltaCompress.diffImmutable(old, { foo = true })

			assertEqual(diff, nil)
			assertEqual(updatedOld, nil)

			assertDeepEqual(old, copied)
		end)

		x.test("non-tables", function()
			checkMutable("hello", 520)
			checkMutable("hello", nil)
			checkMutable(nil, false)
		end)

		x.test("nil to table", function()
			checkMutable(nil, {
				a = "hello",
				b = { 5, 4, 3, 2, 1 },
				c = {
					foo = "bar",
				},
			})
		end)

		x.test("copies new tables in dictionary", function()
			checkMutable({
				a = true,
			}, {
				a = { 1, 2, 3 },
				b = { true, false },
			})
		end)

		x.test("copies new tables in array", function()
			checkMutable({
				array = { 1, 2, 3 },
			}, {
				array = { 1, { "hello" }, 3, { "abc" } },
			})
		end)

		x.test("handles nested diffs", function()
			checkMutable({
				array = { "a", "b", "c", 1, 2, 3 },
				dictionary = {
					foo = "bar",
				},
			}, {
				array = { "c", "b", "a" },
				dictionary = {
					foo = "baz",
				},
			})
		end)
	end)
end
