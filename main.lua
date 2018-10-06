function lovr.load()
	width, height = 5, .8
	density = 10
	vertexCount = (width * density + 1) * (height * density + 1)

	local validDensity = width % (1 / density) == 0 and height % (1 / density) == 0
	assert(validDensity, 'Width and height must be divisible by the inverse density.')

	prevPositionsBlock = lovr.graphics.newShaderBlock({
		prevPositions = { 'vec4', vertexCount }
	}, { writable = true, usage = 'stream' })

	newPositionsBlock = lovr.graphics.newShaderBlock({
		newPositions = { 'vec4', vertexCount }
	}, { writable = true, usage = 'stream' })

	connectionsBlock = lovr.graphics.newShaderBlock({
		connections = { 'ivec4', vertexCount }
	}, { writable = true, usage = 'static' })

	updateShader = lovr.graphics.newComputeShader(
		prevPositionsBlock:getShaderCode('PrevPositions') ..
		newPositionsBlock:getShaderCode('NewPositions') ..
		connectionsBlock:getShaderCode('Connections') ..
		[[
      layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

      const vec3 gravity = vec3(0.0, -.98, 0.0);
      const float damping = .9;
      const float restLength = .09;
      const float mass = .01;
      const float spring = 5;

      uniform float dt;
      uniform vec3 controllerPosition;

			void compute() {
        uint width = gl_NumWorkGroups.x;
        uint height = gl_NumWorkGroups.y;

        uint id = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * width;

        vec3 position = newPositions[id].xyz;
        vec3 previousPosition = prevPositions[id].xyz;

        vec3 velocity = position - previousPosition;
        vec3 force = gravity * mass - velocity * damping;

        // Nodes in the top row always stay put
        if (id >= width * height - width) {
          prevPositions[id] = vec4(position, 1.);
          return;
        }

        if (id < width) {
          prevPositions[id] = vec4(controllerPosition, 1.);
          return;
        }

        for (int i = 0; i < 4; i++) {
          int neighbor = connections[id][i];
          if (neighbor == -1) { continue; }

          vec3 neighborPosition = newPositions[neighbor - 1].xyz;
          vec3 direction = neighborPosition - position;
          float distance = length(direction);
          force += -spring * (restLength - distance) * normalize(direction);
        }

        vec3 acceleration = force / mass;
        vec3 displacement = velocity + acceleration * dt * dt;

        // idk how to do outputs without running into concurrency
        prevPositions[id] = vec4(position + displacement, 1.);
			}
		]]
	)

  renderShader = lovr.graphics.newShader(
    newPositionsBlock:getShaderCode('Positions') .. [[
    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      return lovrProjection * lovrTransform * newPositions[gl_VertexID];
    }
  ]], nil)

	vertices = {}
	for y = 0, height * density do
		for x = 0, width * density do
			table.insert(vertices, { x / density - width / 2, y / density - height / 2 + 2, 0, 1 })
		end
	end

  prevPositionsBlock:send('prevPositions', vertices)
  newPositionsBlock:send('newPositions', vertices)
	
  local function index(x, y) return x + (y - 1) * (width * density + 1)	end

  connections = {}
  for y = 1, height * density + 1 do
    for x = 1, width * density + 1 do
      local left, top, right, bottom = -1, -1, -1, -1

      if x ~= 1 then left = index(x - 1, y) end
      if y ~= 1 then top = index(x, y - 1) end
      if x ~= width * density + 1 then right = index(x + 1, y) end
      if y ~= height * density + 1 then bottom = index(x, y + 1) end

      table.insert(connections, { left, top, right, bottom })
    end
  end

  connectionsBlock:send('connections', connections)

	indices = {}
	for y = 1, height * density do
		for x = 1, width * density do
			table.insert(indices, index(x, y))
			table.insert(indices, index(x + 1, y))
			table.insert(indices, index(x + 1, y + 1))

			table.insert(indices, index(x, y))
			table.insert(indices, index(x + 1, y + 1))
			table.insert(indices, index(x, y + 1))
		end
	end

  positions = {
    prev = prevPositionsBlock,
    new = newPositionsBlock
  }

  updateShader:sendBlock('PrevPositions', positions.prev)
  updateShader:sendBlock('NewPositions', positions.new)
  updateShader:sendBlock('Connections', connectionsBlock)

  renderShader:sendBlock('Positions', positions.new)

	mesh = lovr.graphics.newMesh(vertices, 'triangles')
	mesh:setVertexMap(indices)
  print(#vertices)
end

function lovr.update(dt)
  local controller = lovr.headset.getControllers()[1]

  updateShader:send('dt', dt * 2)
  updateShader:send('controllerPosition', controller and { controller:getPosition() } or { 0, 0, 0 })
  lovr.graphics.compute(updateShader, width * density + 1, height * density + 1)

  positions.prev, positions.new = positions.new, positions.prev

  updateShader:sendBlock('PrevPositions', positions.prev)
  updateShader:sendBlock('NewPositions', positions.new)
  renderShader:sendBlock('Positions', positions.new)
end

function lovr.draw()
	lovr.graphics.setWireframe(true)

  lovr.graphics.setShader(renderShader)
	mesh:draw(0, 0, 0)
  lovr.graphics.setShader()

	lovr.graphics.setWireframe(false)
end
