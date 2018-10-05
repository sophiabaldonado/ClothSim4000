function lovr.load()
	width, height = 3, 2
	density = 21
	vertexCount = (width * density) * (height * density)

	local validDensity = width % (1 / density) == 0 and height % (1 / density) == 0
	assert(validDensity, 'Width and height must be divisible by the inverse density.')

	--[=[
	prevPositionsBlock = lovr.graphics.newShaderBlock({
		prevPositions = { 'vec3', vertexCount }
	}, { writable = true, usage = 'stream' })

	newPositionsBlock = lovr.graphics.newShaderBlock({
		newPositions = { 'vec3', vertexCount }
	}, { writable = true, usage = 'stream' })

	conectionsBlock = lovr.graphics.newShaderBlock({
		connections = { 'ivec4', vertexCount }
	}, { writable = false, usage = 'static' })

	updateShader = lovr.graphics.newComputeShader(
		prevPositionsBlock:getShaderCode('PrevPositions') ..
		newPositionsBlock:getShaderCode('NewPositions') ..
		connectionsBlock:getShaderCode('ConnectionBlock') ..
		[[
			void compute() {

			}
		]]
	)
	]=]

	vertices = {}
	for y = 0, height * density do
		for x = 0, width * density do
			table.insert(vertices, { x / density - width / 2, y / density - height / 2, 0 })
		end
	end

	local function index(x, y) return x + (y - 1) * (width * density + 1)	end

	indices = {}
	for y = 1, height * density - 1 do
		for x = 1, width * density - 1 do
			table.insert(indices, index(x, y))
			table.insert(indices, index(x + 1, y))
			table.insert(indices, index(x + 1, y + 1))

			table.insert(indices, index(x, y))
			table.insert(indices, index(x + 1, y + 1))
			table.insert(indices, index(x, y + 1))
		end
	end

	mesh = lovr.graphics.newMesh(vertices, 'triangles')
	mesh:setVertexMap(indices)
end

function lovr.update()
	--
end

function lovr.draw()
	lovr.graphics.setWireframe(true)
	mesh:draw(0, 1.7, -3)
end
